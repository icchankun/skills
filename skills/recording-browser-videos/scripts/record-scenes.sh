#!/usr/bin/env bash
# 場面ごとに動画を撮り、番号順につないで1本の mp4 にする。
#
# 使い方: record-scenes.sh [-j 同時に撮る数] <場面の置き場所> <URL> <出力.mp4> [番号...]
#   <場面の置き場所>/<番号>.sh を場面ごとに読む。番号を渡すと、その場面だけ撮り直す。
#   -j を付けると、場面ごとに別のブラウザで同時に撮る。場面どうしがサーバーのデータを取り合わないときだけ使う。
#   場面のファイルには TITLE・SUBTITLE と、setup（録画しない前準備）・steps（録画する操作）を書く。
#   撮った場面は <場面の置き場所>/<番号>.mp4 に残り、つなぐときはそれを使う。
#   ログインの状態を残したファイル（既定は worktree の git dir の browser-auth.json、AUTH で変えられる）があれば、
#   場面ごとのブラウザで読み込んでから撮る。
#   worktree の中から呼ぶ。ブラウザのセッション名は、その worktree の名前から決まる。
set -euo pipefail

jobs=1
if [[ "${1:-}" == -j ]]; then jobs="$2"; shift 2; fi
dir="$(cd "$1" && pwd)" url="$2" out="$3"; shift 3
case "$out" in /*) ;; *) out="$PWD/$out" ;; esac
# セッション名は、呼ばれた worktree の名前から決める（worktree ごとに分けるため）
base_session="${session:-capture-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")}"
# ログインの状態は、worktree の git dir に残したものを、どの場面のブラウザでも読み込む
gitdir="$(git rev-parse --absolute-git-dir 2>/dev/null || true)"
auth="${AUTH:-${gitdir:+$gitdir/browser-auth.json}}"
# playwright-cli は今いるディレクトリに .playwright-cli/ を作るので、worktree に残さないよう置き場所で動かす
cd "$dir"
media="$dir"
lib="$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=lib.sh
source "$lib"

items=("$@")
if ((${#items[@]} == 0)); then
  for f in "$dir"/*.sh; do items+=("$(basename "$f" .sh)"); done
fi

record_one() {
  local n="$1"
  session="$base_session-$n"
  trap 'playwright-cli -s="$session" close >/dev/null 2>&1' EXIT
  log="$dir/$n.log"; : >"$log"
  unset TITLE SUBTITLE; setup() { :; }; steps() { :; }
  # shellcheck source=/dev/null
  source "$dir/$n.sh"
  P open "$url" --idle-timeout=600000
  if [[ -n "$auth" && -f "$auth" ]]; then
    P state-load "$auth"
    P goto "$url"
  fi
  setup
  # 呼び出しは1回あたり約0.7秒かかるので、録画の外でできることは録画の前に済ませる
  show_actions
  card_show "$TITLE" "${SUBTITLE:-}"
  P video-start "$dir/$n.webm" --size 1280x720 --fps 24
  card_hide
  steps
  P video-stop
  P close
  # 録画を止める呼び出しのあいだも撮り続けるので、末尾の止まった0.6秒を切る
  local length
  length="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$dir/$n.webm")"
  ffmpeg -loglevel error -y -i "$dir/$n.webm" -t "$(echo "$length - 0.6" | bc)" -vf fps=24 \
    -c:v libx264 -crf 28 -preset slow -pix_fmt yuv420p -an "$dir/$n.mp4"
  echo "撮った: $n"
}

pids=()
for n in "${items[@]}"; do
  while (($(jobs -rp | wc -l) >= jobs)); do sleep 0.2; done
  record_one "$n" &
  pids+=("$!")
done
failed=0
for pid in "${pids[@]}"; do wait "$pid" || failed=1; done
((failed == 0)) || exit 1

# 番号の順につなぐ。どれも同じ設定で変換しているので、変換し直さずにつなげる
list="$dir/list.txt"
: >"$list"
for f in $(ls "$dir"/*.mp4 | sort -V); do printf "file '%s'\n" "$f" >>"$list"; done
ffmpeg -loglevel error -y -f concat -safe 0 -i "$list" -c copy -movflags +faststart "$out"
echo DONE
