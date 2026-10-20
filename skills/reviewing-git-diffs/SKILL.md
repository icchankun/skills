---
name: reviewing-git-diffs
description: 差分を /pr-review-toolkit:review-pr（バグ・エラー処理・テストなどの正しさ）、/ponytail:ponytail-review（消せるコード・要らない依存・先回りした抽象化）、/security-review（セキュリティ）、リポジトリの流儀に沿っているかの4つでレビューし、指摘を Critical / Important / Suggestions の1つの一覧にまとめて返す。ファイルは編集しない。「レビューして」「差分を見て」「コミット前・PRを出す前に見て」「作り込みすぎてないか見て」と言われた場合や、herdr-coding の reviewer としてレビューを頼まれた場合に使う。review-pr や ponytail-review を単独で呼ぶ場面でも、ユーザーが片方だけを指定していなければこちらを使う。PRに付いたレビューコメントへの対応は resolving-pr-reviews、GitHub の PR にレビューを投稿するのは code-review の役割で、このスキルは使わない。
---

# reviewing-git-diffs

2つのレビューは見るところが違う。review-pr はバグ・エラー処理・テスト・コメント・型を見て、ponytail-review は消せるもの（標準ライブラリの作り直し、要らない依存、先回りした抽象化）だけを見る。片方だけだと、正しいが大きすぎる差分か、小さいが壊れた差分を見逃す。

これに、セキュリティの穴を見る security-review と、名前空間・命名・粒度・テーブルの構成がリポジトリの流儀に沿っているかを見るサブエージェントを足す。流儀の基準は following-repo-conventions が実装の前に dev-flow.md に書いたメモで、実装とレビューで同じものを使う。

## 対象を決める

未コミットの差分があればそれを、なければベースブランチからの差分を対象にする。

```bash
git status --short
```

何か出れば未コミットの差分が対象。`??` の untracked ファイルは `git diff` に出ずレビューから漏れるので、結果の先頭にファイル名を挙げて対象外だと書く。`git add -N` で追跡に加えるのは呼び出し元の仕事で、ここではしない。

何も出なければ、`<base>..HEAD` が対象。`<base>` は引数で指定されたブランチ、`git config branch.<現在のブランチ>.gh-merge-base` の値、リポジトリのデフォルトブランチの順で決める。

```bash
git config --get "branch.$(git branch --show-current).gh-merge-base"
gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'
```

### 2回目以降は、前回から変わった部分だけ

依頼に「前回のスナップショット」が書かれていたら、その時点から変わった部分だけを対象にする。往復のたびに差分全体を見直すと、直した数行のために毎回同じ時間がかかるため。

レビューを始めるときに、今の作業ツリーのスナップショットを取る。

```bash
sh ~/.claude/skills/reviewing-git-diffs/scripts/snapshot.sh
```

出た ID を結果の先頭に書く。次の依頼で前回のスナップショットとして渡ってくる。前回の ID があれば、`git diff <前回> <今回>` が対象になる。

前回のスナップショットが書かれていなければ、上のとおり差分全体を対象にする。

## 観点を選ぶ

review-pr に渡す観点は、対象の差分を見て選ぶ。関係のない観点のエージェントを動かしても、指摘は出ずに時間だけかかるため。

| 観点 | 渡すとき |
|---|---|
| code / errors / tests | 1回目は必ず |
| comments | コメントやドキュメントの行が足されたか変わった |
| types | 型・クラス・インターフェース・スキーマの定義が足されたか変わった |

2回目以降は、code と、依頼に「前回指摘が出た観点」として書かれたものだけにする。

## 4つを呼ぶ

同じ対象を4つに渡す。1〜3 は順に呼び、4 はサブエージェントに並列で頼む。

1. `/pr-review-toolkit:review-pr <選んだ観点> parallel`
   - `parallel` を付けて、エージェントを並列で動かす。付けないと1つずつ順に動き、待ち時間が観点の数だけ積み上がる。
   - simplify は含めない。ファイルを書き換えるうえ、削る観点は ponytail-review が受け持つ。
   - review-pr は `git diff` で対象を決めるので、`<base>..HEAD` や `<前回>..<今回>` のときは引数の後ろに「対象は `git diff <base>..HEAD`」のように書き添える。
2. `/ponytail:ponytail-review`
   - 対象の範囲を書き添える。
3. `/security-review`
   - 対象の範囲を書き添える。認証や権限に触れない差分でも呼ぶ。見逃したときの影響が大きいため。
4. 流儀に沿っているか（Agent ツールのサブエージェント、`model: sonnet`）
   - dev-flow.md（`$(git rev-parse --git-dir)/dev-flow.md`）の「流儀のメモ」と、差分の近くの既存コードを渡し、名前空間・ファイル名・名前の付け方・粒度・テーブルの構成が外れている箇所を挙げさせる。
   - メモがなければ、差分の近くの既存コードだけを基準にさせる。

## まとめる

4つの結果を1つにして返す。

- review-pr の指摘は、その区分のまま Critical / Important / Suggestions に入れる。番号の後ろに、指摘を出した観点を `(errors)` のように書く。次の依頼で「前回指摘が出た観点」を決めるのに使う。
- security-review の指摘は、重さに応じて Critical か Important に入れ、観点を `(security)` と書く。
- 流儀の指摘は、メモや既存コードに明らかに反するものを Important、好みの範囲のものを Suggestions に入れ、観点を `(conventions)` と書く。
- ponytail-review の指摘は Suggestions に入れ、番号を `P` で振る。削る指摘は探せばいくらでも出るので、Important に入れると herdr-coding の往復が止まらなくなる。
- 同じ箇所を両方が指摘していたら、重いほうの区分に1つにまとめる。
- 結果の1行目は `Critical: <件数> / Important: <件数>` にする。呼び出し元は、文章を読まずにこの行で次にすることを決める。
- 該当なしの区分は「0件」と書く。ponytail-review が `Lean already. Ship.` を返したら、Suggestions に「ponytail: 削れる箇所なし」と書く。

```
Critical: 0 / Important: 2
対象: 未コミットの差分（3ファイル）
観点: code errors tests
スナップショット: 34a0e4ee928de39ce3b5a7269faaf78e12db3616
対象外（untracked）: lib/new_helper.rb

### Critical
0件

### Important
- [I1] (errors) app/models/order.rb:42 — 例外を握りつぶしていて、保存の失敗が呼び出し元に伝わらない
- [I2] (conventions) app/services/order_price.rb:1 — サービスは app/services/<ドメイン>/ に置く流儀（app/services/articles/publish.rb:1）。app/services/orders/price.rb にする

### Suggestions
- [S1] (code) app/models/order.rb:10 — 変数名が中身と合っていない
- [P1] app/services/price.rb:L12-38 — stdlib: 手書きの丸め処理。`BigDecimal#round(2)` で1行
- [P2] app/services/price.rb:L50 — yagni: 実装が1つだけの PriceStrategy。使う側に直接書く
net: -27 lines possible.
```

## 規律

- ファイルを編集しない。直すのは呼び出し元。
- 別のペインから `SendMessage` で頼まれたときは、結果を依頼元に `SendMessage` で送り返す。自分の画面に書くだけでは依頼元に届かず、herdr-coding の往復が止まる。
- どれかが失敗したり、コマンドが見つからなかったりしたら、動かなかったものを結果の先頭に書く。残りの結果だけを黙って返さない。
