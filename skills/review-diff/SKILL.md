---
name: review-diff
description: 差分を /pr-review-toolkit:review-pr（バグ・エラー処理・テストなどの正しさ）と /ponytail:ponytail-review（消せるコード・要らない依存・先回りした抽象化）の両方でレビューし、指摘を Critical / Important / Suggestions の1つの一覧にまとめて返す。ファイルは編集しない。「レビューして」「差分を見て」「コミット前・PRを出す前に見て」「作り込みすぎてないか見て」と言われた場合や、herdr-coding の reviewer としてレビューを頼まれた場合に使う。review-pr や ponytail-review を単独で呼ぶ場面でも、ユーザーが片方だけを指定していなければこちらを使う。PRに付いたレビューコメントへの対応は resolving-pr-reviews、GitHub の PR にレビューを投稿するのは code-review の役割で、このスキルは使わない。
---

# review-diff

2つのレビューは見るところが違う。review-pr はバグ・エラー処理・テスト・コメント・型を見て、ponytail-review は消せるもの（標準ライブラリの作り直し、要らない依存、先回りした抽象化）だけを見る。片方だけだと、正しいが大きすぎる差分か、小さいが壊れた差分を見逃す。

## 対象を決める

未コミットの差分があればそれを、なければベースブランチからの差分を対象にする。

```bash
git status --short
```

何か出れば未コミットの差分が対象。`??` の untracked ファイルは `git diff` に出ずレビューから漏れるので、結果の先頭にファイル名を挙げて対象外だと書く。`git add -N` で追跡に加えるのは呼び出し元の仕事で、ここではしない。

何も出なければ、`<base>..HEAD` が対象。`<base>` は引数で指定されたブランチ、`git config branch.<現在のブランチ>.gh-merge-base` の値、リポジトリのデフォルトブランチの順で決める。

```bash
git config "branch.$(git branch --show-current).gh-merge-base"
gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'
```

## 2つを呼ぶ

同じ対象を2つに順に渡す。

1. `/pr-review-toolkit:review-pr code errors tests comments types`
   - simplify は含めない。ファイルを書き換えるうえ、削る観点は ponytail-review が受け持つ。
   - review-pr は `git diff` で対象を決めるので、`<base>..HEAD` のときは引数の後ろに「対象は `git diff <base>..HEAD`」と書き添える。
2. `/ponytail:ponytail-review`
   - 対象の範囲を書き添える。

## まとめる

2つの結果を1つにして返す。

- review-pr の指摘は、その区分のまま Critical / Important / Suggestions に入れる。
- ponytail-review の指摘は Suggestions に入れ、番号を `P` で振る。削る指摘は探せばいくらでも出るので、Important に入れると herdr-coding の往復が止まらなくなる。
- 同じ箇所を両方が指摘していたら、重いほうの区分に1つにまとめる。
- 該当なしの区分は「0件」と書く。ponytail-review が `Lean already. Ship.` を返したら、Suggestions に「ponytail: 削れる箇所なし」と書く。

```
対象: 未コミットの差分（3ファイル）
対象外（untracked）: lib/new_helper.rb

### Critical
0件

### Important
- [I1] app/models/order.rb:42 — 例外を握りつぶしていて、保存の失敗が呼び出し元に伝わらない

### Suggestions
- [S1] app/models/order.rb:10 — コメントがメソッド名の言い換えになっている
- [P1] app/services/price.rb:L12-38 — stdlib: 手書きの丸め処理。`BigDecimal#round(2)` で1行
- [P2] app/services/price.rb:L50 — yagni: 実装が1つだけの PriceStrategy。使う側に直接書く
net: -27 lines possible.
```

## 規律

- ファイルを編集しない。直すのは呼び出し元。
- 片方が失敗したり、コマンドが見つからなかったりしたら、動かなかったほうを結果の先頭に書く。もう片方の結果だけを黙って返さない。
