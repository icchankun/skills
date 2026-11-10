---
name: capturing-screens
description: 画面に変更がある作業で、変更前（ベースブランチ）と変更後（作業ブランチ）の同じ画面を、同じ画面サイズ・同じデータでスクショに撮る。running-dev-flow から画面を変えたときに呼ばれるほか、「スクショを撮って」「変更前後を撮って」と言われた場合に使う。playwright-cli が必要。
---

# capturing-screens

変更前と変更後を、見比べられる形で撮る。撮り方が少しでも違うと、変えていない所まで違って見えるため、画面サイズ・データ・URL をそろえる。

依存: `playwright-cli`（mise で入れる）

撮るのは、サブエージェントに任せる。撮る画面・アプリの URL・置き場所を渡し、この skill に従わせる。決まった手順をなぞるだけで判断が軽く、重いモデルで動かしても出来は変わらないので、標準のモデルでよい。サブエージェントを使えないときは自分で撮る。

`playwright-cli` の書き方は `playwright-cli` skill に従う（読むのは SKILL.md と `references/storage-state.md` だけ）。食い違うときは `playwright-cli <コマンド> --help` を正とする。

## 1. 撮る画面を決める

dev-flow.md の「動作確認」にある「撮るもの」（planning-manual-checks が決める）が「動画だけ」か「なし」なら撮らない。その行がなく、running-dev-flow の外で呼ばれたときは、planning-manual-checks の「撮るものを決める」の基準で決める。

差分から、見た目や動きが変わる画面を挙げる。画面ごとに名前（英数字とハイフン）と URL を決める。

撮るのは1画面につき1枚にする。同じ画面の別の状態（エラーの表示・開いたモーダルなど）は、URL を開くだけでは出ないので撮らず、動画に回す。同じ部品の変更が複数の画面に出るときは、代表の1画面だけを撮り、ほかの画面は一覧の説明に書く。

新しく作った画面は、変更前を撮らない。

running-dev-flow から実装の前に変更前だけを撮るときは、まだ「撮るもの」の行がない（手順3の planning-manual-checks が書く）。要件から画面が変わると分かる場合だけ変更前を撮り、差分がまだないので画面も要件から決める。実装してみて増えた画面は、あとで変更前を撮り足す。あとで「撮るもの」が「動画だけ」か「なし」になったら、撮った画像は使わない。

## 2. 置き場所を作る

`<skill のディレクトリ>/../recording-browser-videos/references/browser.md` の「置き場所」のとおりに、`$media` と `$session` を決めてそこへ移る。以降の `playwright-cli` はここで動かす。ブラウザの立て方とログインの状態、撮るものの規律（本番を撮らない・個人情報を写さない）も、同じ資料に従う。

3 と 4 の `playwright-cli` は1つのスクリプト（`$media/capture.sh`）に書き、`hc run --bg --name capture bash "$media/capture.sh"` で動かして `hc wait capture` で待つ。別のシェルで動いて 2 の値は引き継がれないので、先頭で `media` と `session` を 2 と同じように決め、browser.md の「立て方と閉じ方」の形で `trap` を仕掛けてどう終わっても閉じる。

## 3. 変更前を撮る

ベースブランチは、creating-pull-requests のステップ1（`<skill のディレクトリ>/../creating-pull-requests/SKILL.md`）の決め方で決める。`git worktree list` でそのブランチの worktree を探し、そこでアプリを起動する。起動のしかたはリポジトリの README や `bin/dev` などに従う。

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

## 不具合を見つけたとき

変更前と変更後を見比べて、要件にない見た目の変化や崩れを見つけたら、その画像は PR に貼らない。running-dev-flow の「不具合を見つけたとき」に従って直してから、撮り直す。
