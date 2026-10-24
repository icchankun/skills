---
name: stacking-pull-requests
description: まだマージされていない PR の上に積む作業を、gh stack で stacked PR にする。1層を1つのブランチと1つの worktree にし、ブランチを作ったら手元のスタックに足し、PR を出したら GitHub のスタックにつなぎ、下の層を直したら上の層を載せ直し、マージはスタックごとに下からする。creating-git-branches で今のブランチの上に積んだとき、creating-pull-requests・resolving-pr-reviews がスタックの中のブランチを扱うときに呼ばれるほか、「stacked PR にして」「この PR の上に積んで」「スタックにして」と言われた場合に使う。gh stack 拡張（`gh extension install github/gh-stack`）が必要。
---

# stacking-pull-requests

依存のある PR は、gh stack で stacked PR にする。レビュアーは層ごとに小さな差分を読め、マージは下から順にまとめてできる。

コマンドの書き方は `gh-stack` skill に従う。ここに書くのは、worktree で層を分けるこの流れで決めたことだけ。食い違ったときは `gh stack <コマンド> --help` を正とする。

- `gh stack view` などは、端末だと TUI が開いて止まる。`gh-stack` skill の「Non-interactive use」の表にある書き方（`view --json`・`submit --auto`・`merge <対象> --yes` など）だけを使う。
- remote が複数あるリポジトリでは、`push`・`rebase`・`link` に `--remote origin` を付ける。

## 層の分け方

1層 = 1ブランチ = 1 worktree にする。どの層も `creating-git-branches` で作り、下の層のブランチから切る。

```
main
 └─ feat/a ── worktree A ── PR #1   (1層目)
     └─ feat/b ── worktree B ── PR #2   (2層目)
         └─ feat/c ── worktree C ── PR #3   (3層目)
```

スタックは一直線にしかできないので、同じ層から2本に分かれる作業は別のスタックにする。

## 1. ブランチを作ったら、手元のスタックに足す

`creating-git-branches` が今のブランチの上に worktree を作ったあと、下の層の worktree で次を流す。下の層がすでにスタックにあるかで分かれる。

```bash
gh stack view --json | jq -e --arg b "<下の層>" '.branches[] | select(.name == $b)'
```

何も出なければ、下の層はまだスタックにない。`view` はスタックの外のブランチでも別のスタックを返すことがあるので、終了の状態ではなく、下の層の名前が入っているかで見る。

- まだない: `gh stack init --base <ベース> <下の層> <新しい層>`
- もうある: `gh stack add <新しい層>`。下の層がスタックのいちばん上のときだけ足せる

手元のスタックは worktree をまたいで共通なので、どの層の worktree からでも扱える。

## 2. PR を出したら、GitHub のスタックにつなぐ

`creating-pull-requests` が draft PR を出したあとに、下の層の PR と今の PR を下から順に渡す。

```bash
gh stack link --remote origin <下の層の PR 番号> <今の PR 番号>
```

すでにスタックになっている PR は外れず、今の PR が上に足される。

`gh stack link` や `gh stack submit` に PR を作らせない。題名と本文が自動で付き、`creating-pull-requests` の本文にならないため。ブランチ名を渡すと PR のない層の PR を作るので、PR 番号で渡す。

## 3. 下の層を直したら、上の層を載せ直す

下の層の worktree でコミットするか fixup したら、そこで上の層を載せ直してから push する。載せ直さないと、上の層の PR に下の層の古いコミットが残り、差分が崩れる。

```bash
gh stack rebase --upstack --no-trunk
gh stack push --remote origin
```

- 上の層の worktree は、変更がなければ一緒に更新される。変更が残っている worktree では止まるので、先にコミットしてもらう。
- push は上の層の分もまとめて送る。ready の PR が含まれるなら、`resolving-pr-reviews` のステップ4の承認に、上の層の push も含めて聞く。
- コンフリクトで止まったら、`gh-stack` skill の「Exit 3 recovery」に従う。勝手に解消しない。

## 4. マージはスタックごとに下から

スタックの PR は `gh pr merge` でマージできず、auto-merge も付けられない。マージは人が決め、下の層からまとめてする。

```bash
gh stack merge <マージしたい層の PR 番号> --yes
```

その PR と、それより下のまだマージされていない PR がまとめてマージされる。1つでも条件を満たさなければ、どれもマージされない。マージのあと、残った上の層は GitHub がベースブランチに向け直す。

マージしたら、`gh stack sync --remote origin` で手元のスタックを GitHub に合わせる。マージ済みの worktree は `prune-merged-worktrees` が消す。
