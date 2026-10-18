#!/bin/sh

# 作業ツリーの今の状態を tree オブジェクトとして保存し、その ID を標準出力する。
# 未追跡のファイルも含めるが、本物のインデックスは変えない（ステージの状態を崩さない）。
# 使い方: sh snapshot.sh
#
# 2つの ID を `git diff <前回> <今回>` に渡すと、前回のレビューから変わった部分だけが出る。

set -eu

tmp=$(mktemp)
trap 'rm -f "$tmp"' EXIT

# 今のインデックスを写してから足す。変わっていないファイルを読み直さずに済む
cp "$(git rev-parse --git-path index)" "$tmp" 2>/dev/null || :
GIT_INDEX_FILE=$tmp git add -A
GIT_INDEX_FILE=$tmp git write-tree
