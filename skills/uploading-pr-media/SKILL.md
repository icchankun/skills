---
name: uploading-pr-media
description: capturing-screens が撮った変更前後の画像と動画を `gh pr edit --attach` で GitHub に上げ、変更前と変更後を並べた表にして PR の本文に追記する。動画は「動作確認」の見出しのすぐ下に置く。running-dev-flow から draft PR を出したあとに呼ばれるほか、「スクショを PR に貼って」「画像を PR に上げて」「変更前後を PR に載せて」と言われた場合に使う。gh 2.99 以上が必要。
---

# uploading-pr-media

`gh pr edit --attach` で画像と動画を PR に上げる。本文に `![](./<ファイル>)` と書いたところは、上げた先の URL（`https://github.com/user-attachments/assets/...`）に書き換わる。

依存: `gh` 2.99 以上（mise で入れる）

## 1. 上げるファイルを確かめる

dev-flow.md の「画面」の表と動画（mp4）を、`$(git rev-parse --absolute-git-dir)/dev-flow-media/` のファイルと突き合わせる。表にあってファイルがないものは、capturing-screens に戻る。

添付の URL は PR を見られる人なら誰でも開けるので、上げる前に、画像と動画に個人情報や秘密の値が写っていないかを見る。

## 2. 本文を書いて上げる

今の本文を、置き場所のディレクトリに取り出す。本文の中のパスは、body.md のあるディレクトリを基準に探されるため。

```bash
cd "$(git rev-parse --absolute-git-dir)/dev-flow-media"
gh pr view <PR番号> --json body --jq '.body' > body.md
```

body.md の「動作確認」の見出しの前に表を、見出しのすぐ下に動画を入れる。画像と動画は、どちらも `![](./<ファイル>)` で書く。動画は表に入れず、折りたたまない。確かめる人が、手順を読む前に動きを見られるため。

```markdown
## 🖼️ 変更前後の画像

| 画面 | 変更前 | 変更後 |
|---|---|---|
| 記事一覧 | ![](./post-list-before.png) | ![](./post-list-after.png) |
| 記事詳細 | なし（新規） | ![](./post-detail-after.png) |

## 動作確認

![](./checks.mp4)

- [ ] 記事一覧で…
```

「動作確認」がなければ、表のあとに見出しを作って動画を置く。すでに「変更前後の画像」の節や「動作確認」の下の動画があれば、置き換える。撮り直したときに表や動画が二重にならないため。

本文で使ったファイルを、すべて `--attach` に渡す。

```bash
gh pr edit <PR番号> --body-file ./body.md \
  --attach ./post-list-before.png --attach ./post-list-after.png \
  --attach ./post-detail-after.png --attach ./checks.mp4
```

本文に書いていないファイルを渡すと、本文の末尾に足される。

## 3. 画像の幅をそろえる

`![]()` のままだと、画像ごとに大きさが変わって見比べにくい。書き換わった URL を `<img>` に直し、もう一度本文だけを書き戻す。`<img src="./...">` と書いて上げると URL に書き換わらないので、この順にする。

```bash
gh pr view <PR番号> --json body --jq '.body' \
  | sed -E 's#!\[[^]]*\]\((https://github.com/user-attachments/assets/[^)]+)\)#<img src="\1" width="360">#g' > body.md
gh pr edit <PR番号> --body-file ./body.md
```

動画の行は、上げたときに URL だけの1行になっているので、この置き換えにはかからない。GitHub が再生できるのは、本文に URL だけを1行で置いた動画のため。
