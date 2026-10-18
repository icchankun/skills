---
name: capturing-screens
description: 画面に変更がある作業で、変更前（ベースブランチ）と変更後（作業ブランチ）の同じ画面を、同じ画面サイズ・同じデータで撮り、動作の動画も撮る。撮ったファイルの一覧を dev-flow.md に書き、uploading-pr-media が PR に貼る。running-dev-flow から画面を変えたときに呼ばれるほか、「スクショを撮って」「変更前後を撮って」「動作確認の動画を撮って」と言われた場合に使う。playwright-cli が必要。
---

# capturing-screens

変更前と変更後を、見比べられる形で撮る。撮り方が少しでも違うと、変えていない所まで違って見えるため、画面サイズ・データ・URL をそろえる。

依存: `playwright-cli`（mise で入れる）

## 1. 撮る画面を決める

差分から、見た目や動きが変わる画面を挙げる。画面ごとに名前（英数字とハイフン）と URL を決める。

新しく作った画面は、変更前を撮らない。

## 2. 置き場所を作る

ファイルは worktree の git dir に置く。commit されず、`git wt -D` で一緒に消える。

```bash
media="$(git rev-parse --absolute-git-dir)/dev-flow-media"
mkdir -p "$media"
```

## 3. 変更前を撮る

ベースブランチは `git config --get branch.<作業ブランチ>.gh-merge-base`。`git worktree list` でそのブランチの worktree を探し、そこでアプリを起動する。起動のしかたはリポジトリの README や `bin/dev` などに従う。

```bash
playwright-cli -s=capture open "<URL>"
playwright-cli -s=capture resize 1280 800
playwright-cli -s=capture screenshot --filename="$media/<画面名>-before.png"
playwright-cli -s=capture close
```

撮り終えたらアプリを止める。変更後と同じポートを使うため。

## 4. 変更後を撮る

作業ブランチの worktree でアプリを起動し、同じ URL・同じ画面サイズで撮る。

```bash
playwright-cli -s=capture open "<URL>"
playwright-cli -s=capture resize 1280 800
playwright-cli -s=capture screenshot --filename="$media/<画面名>-after.png"
```

操作して変わる画面は、続けて動画も撮る。動画は変更後だけでよい。

```bash
playwright-cli -s=capture video-start "$media/<画面名>.webm"
# 変更した操作を、普段の速さで行う
playwright-cli -s=capture video-stop
playwright-cli -s=capture close
```

URL に `?` や `&` を含むときは引用符で囲む。zsh がファイル名の展開として扱い、失敗するため。

## 5. 一覧を書く

dev-flow.md の「画面」の節に、撮ったものを表で書く。dev-flow.md がなければ結果として返す。

```markdown
## 画面

| 画面 | 説明 | 変更前 | 変更後 | 動画 |
|---|---|---|---|---|
| post-list | 記事一覧 | post-list-before.png | post-list-after.png | post-list.webm |
| post-detail | 記事詳細（新規） | なし | post-detail-after.png | |
```

## 規律

- 本番や共有の環境を撮らない。手元で起動したアプリだけを撮る。
- 撮った画像に、個人情報や秘密の値が写っていないかを見る。写っていたら、ダミーのデータで撮り直す。
