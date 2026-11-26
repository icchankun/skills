#!/bin/sh
# PR のマージ先（ベースブランチ）を出力する。
# 引数のブランチ、creating-git-branches が記録した gh-merge-base、リポジトリのデフォルトブランチの順に使う。
# どれで決めたかを標準エラーに出す。
# 使い方: base-branch.sh [ブランチ]
set -eu

if [ -n "${1:-}" ]; then
  echo "決め方: 引数" >&2
  printf '%s\n' "$1"
  exit 0
fi
base=$(git config --get "branch.$(git branch --show-current).gh-merge-base" || true)
if [ -n "$base" ]; then
  echo "決め方: gh-merge-base" >&2
else
  base=$(gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name')
  echo "決め方: デフォルトブランチ" >&2
fi
printf '%s\n' "$base"
