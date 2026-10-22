#!/usr/bin/env bash
# 動作確認の項目ごとに動画を撮り、番号順につないで checks.mp4 にする。
#
# 使い方: record-checks.sh [-j 同時に撮る数] <media> <URL> [番号...]
#   <media>/checks/<番号>.sh を項目ごとに読む。番号を渡すと、その項目だけ撮り直す。
#   -j を付けると、項目ごとに別のブラウザで同時に撮る。項目どうしがサーバーのデータを取り合わないときだけ使う。
#   項目のファイルには TITLE・EXPECT と、setup（録画しない前準備）・steps（録画する操作）を書く。
#   撮った項目は <media>/checks/<番号>.mp4 に残り、つなぐときはそれを使う。
#   ログインの状態を残したファイル（既定は worktree の git dir の dev-flow-auth.json、AUTH で変えられる）があれば、
#   項目ごとのブラウザで読み込んでから撮る。
set -euo pipefail

jobs=1
if [[ "${1:-}" == -j ]]; then jobs="$2"; shift 2; fi
media="$1" url="$2"; shift 2
# セッション名は、呼ばれた worktree の名前から決める（worktree ごとに分けるため）
base_session="${session:-capture-$(basename "$(git rev-parse --show-toplevel 2>/dev/null || pwd)")}"
# ログインの状態は、worktree の git dir に残したものを、どの項目のブラウザでも読み込む（capturing-screens の「撮り方」）
auth="${AUTH:-$(git rev-parse --absolute-git-dir 2>/dev/null)/dev-flow-auth.json}"
# playwright-cli は今いるディレクトリに .playwright-cli/ を作るので、worktree に残さないよう置き場所で動かす
cd "$media"
lib="$(dirname "${BASH_SOURCE[0]}")/lib.sh"
# shellcheck source=lib.sh
source "$lib"

items=("$@")
if ((${#items[@]} == 0)); then
  for f in "$media"/checks/*.sh; do items+=("$(basename "$f" .sh)"); done
fi

record_one() {
  local n="$1"
  session="$base_session-$n"
  trap 'playwright-cli -s="$session" close >/dev/null 2>&1' EXIT
  log="$media/checks/$n.log"; : >"$log"
  unset TITLE EXPECT; setup() { :; }; steps() { :; }
  # shellcheck source=/dev/null
  source "$media/checks/$n.sh"
  P open "$url" --idle-timeout=600000
  if [[ -f "$auth" ]]; then
    P state-load "$auth"
    P goto "$url"
  fi
  setup
  # 呼び出しは1回あたり約0.7秒かかるので、録画の外でできることは録画の前に済ませる
  P video-show-actions --highlight-style="outline: 3px solid #e5534b; border-radius: 4px" --title-style="display: none"
  card_show "$TITLE" "$EXPECT"
  P video-start "$media/checks/$n.webm" --size 1280x720 --fps 24
  card_hide
  steps
  P video-stop
  P close
  # 録画を止める呼び出しのあいだも撮り続けるので、末尾の止まった0.6秒を切る
  local length
  length="$(ffprobe -v error -show_entries format=duration -of csv=p=0 "$media/checks/$n.webm")"
  ffmpeg -loglevel error -y -i "$media/checks/$n.webm" -t "$(echo "$length - 0.6" | bc)" -vf fps=24 \
    -c:v libx264 -crf 28 -preset slow -pix_fmt yuv420p -an "$media/checks/$n.mp4"
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
list="$media/checks/list.txt"
: >"$list"
for f in $(ls "$media"/checks/*.mp4 | sort -V); do printf "file '%s'\n" "$f" >>"$list"; done
ffmpeg -loglevel error -y -f concat -safe 0 -i "$list" -c copy -movflags +faststart "$media/checks.mp4"
echo DONE
