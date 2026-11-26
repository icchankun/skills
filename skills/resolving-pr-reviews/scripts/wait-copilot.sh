#!/usr/bin/env bash
# Copilot の再レビューが届くまで、30秒ごとに10分まで待つ。
# 使い方: wait-copilot.sh <owner/repo> <PR番号> <since>
#   since は push の前に記録した UTC の時刻。それより後に届いた Copilot のレビューを待つ
# 終了コード: 0 届いた（fetch_pr_comments.rb の出力を出す） / 2 10分待っても届かなかった / それ以外 gh が失敗した
set -euo pipefail

repo="$1" number="$2" since="$3"
fetch="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/fetch_pr_comments.rb"

for _ in $(seq 20); do
  out=$(ruby "$fetch" "$repo" "$number")
  if jq -e --arg since "$since" 'any(.reviews[]; (.author | startswith("copilot-pull-request-reviewer")) and .submitted_at > $since)' <<<"$out" >/dev/null; then
    printf '%s\n' "$out"
    exit 0
  fi
  sleep 30
done
exit 2
