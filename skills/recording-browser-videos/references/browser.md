# ブラウザの扱い

スクショ（capturing-screens）と動画（recording-browser-videos・recording-manual-checks）で使うブラウザと、撮るものの決まり。撮ったものを PR に上げる uploading-pr-media も、最後の「規律」に従う。

## 立て方と閉じ方

ブラウザは worktree ごとに1つだけ立て、使い終わったら必ず閉じる。コマンドが終わっても `close` を呼ぶまで裏で動き続けるので、閉じ損ねたブラウザが worktree の数だけ残ると、録画を続けたまま CPU とメモリを使い切る。

- セッション名は `capture-<worktree の名前>` にする。worktree ごとに別のブラウザになり、ほかの worktree の撮影と取り合わない。
- headless で起動する（`--headed` を付けない）。headed のブラウザは放っておいても止まらないため。
- 画面サイズは headless の初期の 1280×720 のまま撮り、`resize` しない。変えると動画の下に灰色の帯が出る。
- `open` には `--idle-timeout=600000` を付け、閉じ損ねても10分で止まるようにする。
- 操作はシェルのスクリプトにまとめてシェルの1回の呼び出しで動かし、先頭で `trap '… close' EXIT` を仕掛けて、どう終わっても閉じる。1操作ずつ呼ぶと、呼び出しの数だけ待ち時間とトークンがかかるため。
- 押す場所は、先に1回だけ `snapshot` で調べ、`'text=保存'` や `'role=button[name="保存"s]'` のようなロケーターで書く。role の name は二重引用符で囲み、末尾に `s` を付けて完全一致にする。囲まないと空白を含む名前で失敗し、`s` がないと「完了」が「未完了」にも当たる。snapshot の `e12` のような参照は、開き直すと変わるので使わない。

```bash
set -e
trap 'playwright-cli -s="$session" close >/dev/null 2>&1' EXIT
playwright-cli -s="$session" open "<URL>" --idle-timeout=600000
```

## 置き場所

撮ったファイルは worktree の git dir に置く。commit されず、`git wt -D` で worktree と一緒に消える。

```bash
media="$(git rev-parse --absolute-git-dir)/dev-flow-media"
mkdir -p "$media"
cd "$media"
session="capture-$(basename "$(git rev-parse --show-toplevel)")"
```

`playwright-cli` は、置き場所のディレクトリで動かす。今いるディレクトリに `.playwright-cli/` を作るので、worktree で動かすと未追跡のファイルが残る。

## ログインの状態

ログインが要る画面は、1回ログインしたら `state-save` で状態を残し、次からは `open` のあとに `state-load` する。ファイルは worktree の git dir に置く。

```bash
auth="$(git rev-parse --absolute-git-dir)/browser-auth.json"
playwright-cli -s="$session" state-save "$auth"   # ログインしたあと、1回だけ
playwright-cli -s="$session" state-load "$auth"   # 次から
```

- 手元の開発用のアプリなら、seed や README にある開発用のユーザーで、ログインの画面をスクリプトで操作してログインする。人の手は要らない。
- SSO や2段階認証があってスクリプトでログインできないときだけ、`--headed` で開いてユーザーにログインしてもらい、`state-save` したらすぐ閉じる。パスワードやコードをエージェントが扱わない。
- 撮っている途中でログインの画面に飛ばされたら、状態の期限が切れている。もう一度ログインして保存し直す。

## 規律

- 本番や共有の環境を撮らない。手元で起動したアプリだけを撮る。
- 撮った画像と動画に、個人情報や秘密の値が写っていないかを見る。写っていたら、ダミーのデータで撮り直す。PR に添付した URL は PR を見られる人なら誰でも開けるので、上げる前にもう一度見る。
