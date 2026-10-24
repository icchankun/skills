---
name: recording-manual-checks
description: 動作確認の項目（planning-manual-checks が dev-flow.md に書いたもの）を、1項目＝1場面としてブラウザで操作し、つないだ1本の動画にする。撮り方と見た目の部品は recording-browser-videos のものを使い、この skill では、項目を場面に書き起こすこと、期待する結果が出たかを確かめること、不具合を見つけたときの扱いを決める。running-dev-flow からスクショのあとに呼ばれるほか、「動作確認の動画を撮って」と言われた場合に使う。スクショは capturing-screens の役割。
---

# recording-manual-checks

動作確認の項目を、書いてある通りに上から順に操作して、変更後だけを1本に撮る。レビュアーが項目と動画を照らし合わせて確かめられるため。動画の目的は、正しく動いているかを確かめることにある。

撮り方・部品・ブラウザの扱いは `recording-browser-videos` に従う。

```
planning-manual-checks   動作確認の項目を dev-flow.md に書く
        |
        v
recording-manual-checks  項目を場面に書き起こし、期待する結果を確かめる
        |
        |  撮り方・部品を使う
        v
recording-browser-videos record-scenes.sh で撮ってつなぎ、checks.mp4 にする
        ^
        |  ブラウザの決まりに従う
        |
capturing-screens        変更前後のスクショを撮る
```

撮るのは、Agent ツールのサブエージェント（`model: sonnet`）に任せる。項目・アプリの URL・置き場所を渡し、この skill と `recording-browser-videos` に従わせる。Opus と撮り比べて出来はほぼ変わらず、時間は3分の1で済んだため。

## 1. 項目を読む

dev-flow.md の「動作確認」の項目を読む。項目がなければ、先に `planning-manual-checks` で決める。「UI上の変更なし」なら撮らない。

## 2. 項目を場面に書き起こす

1項目を1場面にして、`$media/checks/<番号>.sh` に書く。`$media` は `"$(git rev-parse --absolute-git-dir)/dev-flow-media"`。番号は項目の順にする。

- `TITLE`: 項目の文。30字くらいに縮めてよい
- `SUBTITLE`: `期待: <期待する結果>`
- `steps`: 項目に書いてある通りに操作し、最後に `expect_text` で期待する結果が出たかを確かめる。出れば結果にスポットライトが当たってレビュアーの目が向き、出なければ止まるので、不具合のまま撮った動画ができない。文で確かめられない結果は `spot` で照らす
- `setup`: 前の項目の結果に頼る項目は、前提の操作を録画せずに書く。どの項目も単独で撮り直せるようにするため

```bash
# $media/checks/3.sh
TITLE="チェックを付けると、件数が「1 件」になる"
SUBTITLE="期待: 取り消し線が付き、ヘッダーが「1 件」"
setup() {
  fill_text "やること" "牛乳を買う"
  P click 'role=button[name="追加"s]'
}
steps() {
  zoom 'main'
  click_on 'role=checkbox[name="牛乳を買う を完了にする"s]'
  expect_text "1 件"
}
```

スクリプトは、アプリを起動する前に書ける。押す場所の名前（ボタンの文言や `aria-label`）は、差分と動作確認の項目から決まるため。running-dev-flow では reviewer の返事を待つあいだに書き、撮る前に `snapshot` で名前だけ確かめる。

場面を分けるのは、動作確認の項目そのものが分かれているときだけにする。

## 3. 撮ってつなぐ

作業ブランチの worktree でアプリを起動し、worktree の中から撮る。

```bash
~/.claude/skills/recording-browser-videos/scripts/record-scenes.sh -j 4 "$media/checks" "<URL>" "$media/checks.mp4"
~/.claude/skills/recording-browser-videos/scripts/record-scenes.sh -j 4 "$media/checks" "<URL>" "$media/checks.mp4" 3   # 3 だけ撮り直す
```


## 不具合を見つけたとき

`expect_text` で止まったときや、撮った動画を見て期待する結果と違う動きを見つけたときは、その項目の動画は PR に貼らない。不具合のまま撮った動画は、動いているように見せてしまうため。

1. 項目の書き方の間違い（押す場所の名前が違う、手順が抜けているなど）か、アプリの不具合かを分ける。項目を直してよいのは前者だけで、アプリの動きに合わせて期待する結果を書き換えない。
2. アプリの不具合なら撮影を止め、running-dev-flow の「不具合を見つけたとき」に従って返す。直してコミットしたら、その項目だけを撮り直してつなぎ直す。

## 4. 書く

dev-flow.md の「画面」の節の表の下に、動画のファイル名を書く。dev-flow.md がなければ結果として返す。

```markdown
動画: checks.mp4
```

撮るものの決まり（本番を撮らない・個人情報を写さない）は `recording-browser-videos` の「規律」に従う。
