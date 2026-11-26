#!/usr/bin/env bash
# PR が開いているあいだ、新しい指摘と人のレビューを1分ごとに見張る。
# 使い方: watch-reviews.sh <owner/repo> <PR番号> <since>
#   since は報告した UTC の時刻。それより後に届いた人のレビューと、未解決のスレッドで止まる
# 終了コード: 0 届いた（fetch_pr_comments.rb の出力を出す） / 3 PR が閉じたかマージされた / それ以外 gh が失敗した
set -euo pipefail

repo="$1" number="$2" since="$3"
fetch="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fetch_pr_comments.rb"

while :; do
  out=$(ruby "$fetch" "$repo" "$number")
  if jq -e --arg since "$since" '.unresolved_thread_count > 0 or any(.reviews[]; .author_type == "User" and .submitted_at > $since)' <<<"$out" >/dev/null; then
    printf '%s\n' "$out"
    exit 0
  fi
  [ "$(gh pr view "$number" -R "$repo" --json state -q .state)" = OPEN ] || exit 3
  sleep 60
done
