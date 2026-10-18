---
name: uploading-pr-media
description: capturing-screens が撮った変更前後の画像と動画を GitHub に上げ、変更前と変更後を並べた表にして PR の本文に追記する。running-dev-flow から draft PR を出したあとに呼ばれるほか、「スクショを PR に貼って」「画像を PR に上げて」「変更前後を PR に載せて」と言われた場合に使う。playwright-cli と、GitHub にログインしたブラウザのプロファイルが必要。
---

# uploading-pr-media

GitHub には、PR に画像や動画を添付する公開 API がない。そこで、ブラウザで PR のコメント欄にファイルを入れ、GitHub が返す添付の URL（`https://github.com/user-attachments/assets/...`）を取り出す。コメントは投稿しない。

依存: `playwright-cli`（mise で入れる）、`gh`

## 0. 初回だけ: GitHub にログインする

ログインの状態を残すプロファイルを使う。初回だけ、ブラウザを表示してユーザーにログインしてもらう。

```bash
playwright-cli -s=github open --persistent --headed https://github.com/login
```

ログインはユーザーが行う。パスワードや 2 段階認証のコードを Claude が扱わない。終わったら `playwright-cli -s=github close`。

## 1. 上げるファイルを確かめる

dev-flow.md の「画面」の表と、`$(git rev-parse --absolute-git-dir)/dev-flow-media/` のファイルを突き合わせる。表にあってファイルがないものは、capturing-screens に戻る。

## 2. コメント欄に入れて URL を取る

```bash
playwright-cli -s=github open --persistent "<PR の URL>"
playwright-cli -s=github snapshot
```

- snapshot でページの下のコメント欄を探し、クリックする。
- コメント欄の下の、ファイルを添付するボタン（「Paste, drop, or click to add files」）をクリックしてファイル選択を開き、`playwright-cli -s=github upload <ファイル...>` で上げるファイルをまとめて渡す。
- コメント欄の中身が `https://github.com/user-attachments/assets/` を含む行に置き換わるまで待ち、中身を読み出す。アップロード中は「Uploading」の仮の行になっている。
- 読み出したら、コメント欄を空にする。コメントは投稿しない。
- `playwright-cli -s=github close`

ログインの画面に飛ばされたら、0 に戻ってユーザーにログインしてもらう。

## 3. 表にする

画像は `<img>` で幅をそろえる。Markdown の `![]()` だと画像ごとに大きさが変わり、見比べにくい。

```markdown
## 🖼️ 変更前後の画像

| 画面 | 変更前 | 変更後 |
|---|---|---|
| 記事一覧 | <img src="https://github.com/user-attachments/assets/..." width="360"> | <img src="https://github.com/user-attachments/assets/..." width="360"> |
| 記事詳細 | なし（新規） | <img src="https://github.com/user-attachments/assets/..." width="360"> |
```

動画は表に入れず、「動作確認」の見出しのすぐ下に、URL だけを1行で置く。折りたたまない。GitHub が再生できるのは、本文に URL だけを1行で置いた動画のため。確かめる人が、手順を読む前に動きを見られる。

```markdown
## 動作確認

https://github.com/user-attachments/assets/...

- [ ] 記事一覧で…
```

## 4. PR の本文に追記する

今の本文を取り、「動作確認」の見出しの前に表を、見出しのすぐ下に動画を入れて書き戻す。「動作確認」がなければ、表のあとに見出しを作って動画を置き、末尾に足す。

```bash
gh pr view <PR番号> --json body --jq '.body' > <一時ファイル>
# 表と動画を入れる
gh pr edit <PR番号> --body-file <一時ファイル>
```

すでに「変更前後の画像」の節や「動作確認」の下の動画があれば、置き換える。撮り直したときに表や動画が二重にならないため。

## 規律

- コメントを投稿しない。添付の URL を取るためにコメント欄を使うだけ。
- 上げる前に、画像に個人情報や秘密の値が写っていないかを見る。添付の URL は、PR を見られる人なら誰でも開ける。
