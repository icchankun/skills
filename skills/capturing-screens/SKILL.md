---
name: capturing-screens
description: 画面に変更がある作業で、変更前（ベースブランチ）と変更後（作業ブランチ）の同じ画面を、同じ画面サイズ・同じデータでスクショに撮る。撮ったファイルの一覧を dev-flow.md に書き、uploading-pr-media が PR に貼る。ブラウザの扱いは recording-browser-videos の決まりに従う。running-dev-flow から画面を変えたときに呼ばれるほか、「スクショを撮って」「変更前後を撮って」と言われた場合に使う。playwright-cli が必要。
---

# capturing-screens

変更前と変更後を、見比べられる形で撮る。撮り方が少しでも違うと、変えていない所まで違って見えるため、画面サイズ・データ・URL をそろえる。

依存: `playwright-cli`（mise で入れる）

撮るのは、Agent ツールのサブエージェント（`model: sonnet`）に任せる。撮る画面・アプリの URL・置き場所を渡し、この skill に従わせる。決まった手順をなぞるだけで判断が軽く、Opus で動かしても出来は変わらないため。

`playwright-cli` の書き方は `playwright-cli` skill に従う（読むのは SKILL.md と `references/storage-state.md` だけ）。食い違うときは `playwright-cli <コマンド> --help` を正とする。

## 1. 撮る画面を決める

差分から、見た目や動きが変わる画面を挙げる。画面ごとに名前（英数字とハイフン）と URL を決める。

新しく作った画面は、変更前を撮らない。

running-dev-flow から実装の前に変更前だけを撮るときは、差分がまだないので要件から画面を決める。実装してみて増えた画面は、あとで変更前を撮り足す。

## 2. 置き場所を作る

ファイルは worktree の git dir に置く。commit されず、`git wt -D` で一緒に消える。

```bash
media="$(git rev-parse --absolute-git-dir)/dev-flow-media"
mkdir -p "$media"
cd "$media"
session="capture-$(basename "$(git rev-parse --show-toplevel)")"
```

以降の `playwright-cli` はここで動かす。worktree で動かすと、snapshot が作る `.playwright-cli/` が未追跡のファイルとして残るため。

## ブラウザの扱い

ブラウザの扱いは `recording-browser-videos` の「ブラウザの扱い」に従う。セッション名は 2 の `$session`、ログインの状態は worktree の git dir の `browser-auth.json` を使う。

3 と 4 の `playwright-cli` は1つのスクリプト（`$media/capture.sh`）に書き、`run_in_background: true` で動かす。別のシェルで動いて 2 の値は引き継がれないので、先頭で `media` と `session` を 2 と同じように決め、`trap` でどう終わっても閉じる。

```bash
set -e
trap 'playwright-cli -s="$session" close >/dev/null 2>&1' EXIT
playwright-cli -s="$session" open "<URL>" --idle-timeout=600000
```

## 3. 変更前を撮る

ベースブランチは `git config --get branch.<作業ブランチ>.gh-merge-base`。`git worktree list` でそのブランチの worktree を探し、そこでアプリを起動する。起動のしかたはリポジトリの README や `bin/dev` などに従う。

```bash
playwright-cli -s="$session" open "<URL>" --idle-timeout=600000
playwright-cli -s="$session" screenshot --filename="$media/<画面名>-before.png"
playwright-cli -s="$session" close
```

撮り終えたらアプリを止める。変更後と同じポートを使うため。

## 4. 変更後を撮る

作業ブランチの worktree でアプリを起動し、同じ URL・同じ画面サイズで撮る。

```bash
playwright-cli -s="$session" open "<URL>" --idle-timeout=600000
playwright-cli -s="$session" screenshot --filename="$media/<画面名>-after.png"
```

動作確認の動画は、続けて `recording-manual-checks` で撮る。

URL に `?` や `&` を含むときは引用符で囲む。zsh がファイル名の展開として扱い、失敗するため。

## 5. 一覧を書く

dev-flow.md の「画面」の節に、撮ったものを表で書く。dev-flow.md がなければ結果として返す。

```markdown
## 画面

| 画面 | 説明 | 変更前 | 変更後 |
|---|---|---|---|
| post-list | 記事一覧 | post-list-before.png | post-list-after.png |
| post-detail | 記事詳細（新規） | なし | post-detail-after.png |
```

## 規律

- 本番や共有の環境を撮らない。手元で起動したアプリだけを撮る。
- 撮った画像に、個人情報や秘密の値が写っていないかを見る。写っていたら、ダミーのデータで撮り直す。
