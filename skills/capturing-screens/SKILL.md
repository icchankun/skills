---
name: capturing-screens
description: 画面に変更がある作業で、変更前（ベースブランチ）と変更後（作業ブランチ）の同じ画面を、同じ画面サイズ・同じデータでスクショに撮る。撮ったファイルの一覧を dev-flow.md に書き、uploading-pr-media が PR に貼る。ブラウザの立て方と閉じ方の決まりも書いてあり、動画を撮る recording-manual-checks もそれに従う。running-dev-flow から画面を変えたときに呼ばれるほか、「スクショを撮って」「変更前後を撮って」と言われた場合に使う。playwright-cli が必要。
---

# capturing-screens

変更前と変更後を、見比べられる形で撮る。撮り方が少しでも違うと、変えていない所まで違って見えるため、画面サイズ・データ・URL をそろえる。

依存: `playwright-cli`（mise で入れる）

撮るのは、Agent ツールのサブエージェント（`model: sonnet`）に任せる。撮る画面・アプリの URL・置き場所を渡し、この skill に従わせる。決まった手順をなぞるだけで判断が軽く、Opus で動かしても出来は変わらないため。

`playwright-cli` の書き方は `playwright-cli` skill に従う。読むのは SKILL.md と、使う資料（`references/storage-state.md`）だけにする。全部読むとトークンが多くかかるため。skill と CLI の版がずれて書き方が食い違うときは、`playwright-cli <コマンド> --help` の方を正とする。この skill に書くのは、この作業で決めたこと（画面サイズ・スクリプトにまとめること・ブラウザを残さないこと）だけ。

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

## 撮り方: スクリプトにまとめて1回で動かす

この節と次の「ブラウザを残さない」には、`recording-manual-checks` も従う。

3 と 4 の `playwright-cli` は、1つずつ呼ばずにシェルのスクリプト（`$media/capture.sh`）に書き、Bash の1回の呼び出しで動かす。1操作ずつ呼ぶと、呼び出しの数だけ待ち時間とトークンがかかるため。動かしているあいだに別の作業を進められるよう、`run_in_background: true` で起動する。

- 押す場所は、先に1回だけ `snapshot` で調べ、`'text=保存'` や `'role=button[name="保存"]'` のようなロケーターで書く。role の name は二重引用符で囲む。囲まないと、空白を含む名前で失敗する。snapshot の `e12` のような参照は、開き直すと変わるので使わない。
- ログインが要る画面は、1回ログインしたら `state-save` で状態を残し、次からは `open` のあとに `state-load` する。ファイルは worktree の git dir に置く。`git wt -D` で worktree と一緒に消え、ログインの状態が worktree より長く残らない。
  - 手元の開発用のアプリなら、seed や README にある開発用のユーザーで、ログインの画面をスクリプトで操作してログインする。人の手は要らない。
  - SSO や2段階認証があってスクリプトでログインできないときだけ、`--headed` で開いてユーザーにログインしてもらい、`state-save` したらすぐ閉じる。パスワードやコードを Claude が扱わない。
  - 撮っている途中でログインの画面に飛ばされたら、状態の期限が切れている。もう一度ログインして保存し直す。

```bash
auth="$(git rev-parse --absolute-git-dir)/dev-flow-auth.json"
playwright-cli -s="$session" state-save "$auth"   # ログインしたあと、1回だけ
playwright-cli -s="$session" state-load "$auth"   # 次から
```

- スクリプトが途中で失敗したら、失敗した行から先だけを直して流し直す。

### ブラウザを残さない

ブラウザは worktree ごとに1つだけ立て、使い終わったら必ず閉じる。`playwright-cli` のブラウザは、コマンドが終わっても `close` を呼ぶまで裏で動き続ける。途中で失敗して閉じ損ねたブラウザが worktree の数だけ残ると、録画を続けたまま CPU とメモリを使い切る。

- セッション名は 2 の `$session` にする。worktree ごとに別のブラウザになり、ほかの worktree の撮影と取り合わない。
- headless で起動する（`--headed` を付けない）。headed のブラウザは放っておいても止まらないため。
- 画面サイズは headless の初期の 1280×720 のまま撮り、`resize` しない。変えると動画の下に灰色の帯が出る。
- `open` には `--idle-timeout=600000` を付け、閉じ損ねても10分で止まるようにする。
- スクリプトの先頭で `media` と `session` を 2 と同じように決め、どう終わっても閉じるようにする。スクリプトは別のシェルで動くので、2 で決めた値は引き継がれない。

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
