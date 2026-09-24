---
name: herdr-coding
description: Herdrで隣のペインにreviewerを立て、自分が実装した差分を /pr-review-toolkit:review-pr でレビューさせ、CriticalとImportantの指摘がなくなるまで修正とレビューを自動で往復する。「実装とレビューを回して」「レビュー役を立てて」「reviewerに見せて」「レビューが通るまで直して」「実装とレビューを分けたい」と言われた場合に使う。HERDR_ENV=1 が必要。
---

# herdr-coding

このペインが実装役（coder）を兼ね、隣に reviewer を1人立てる。reviewer の指摘は `SendMessage` の返信として直接このペインに届くので、間に誰も挟まずに往復できる。

```
 ┌─ このペイン (driver = coder) ─┐        ┌─ reviewer ─────────────┐
 │ 実装                          │─依頼─►│ /pr-review-toolkit:     │
 │   ▲                           │        │   review-pr            │
 │   │ Critical / Important      │◄─指摘─│ ファイルは編集しない   │
 │   └ を直す                    │        └────────────────────────┘
 │ 0件になったら報告 → コミット  │
 └───────────────────────────────┘
```

## ペインを立てる

まず Herdr の中で動いていることを確認する。

```bash
test "${HERDR_ENV:-}" = 1
```

失敗したら Herdr の外にいる旨を伝えて止める。ペインを作る操作は一切しない。

このペインを `<ペインID>-driver` に改名してから、reviewer を立てる。

```bash
herdr agent rename "$HERDR_PANE_ID" "$(herdr-agent-name)"
herdr-coding
```

- 出力の `AGENT` 列が reviewer の宛先になる。`herdr-agent-name reviewer` でも同じ名前が出る。
- `STATUS` が `reused` なら前の作業の文脈が残っているので、依頼文で今回の対象を明示する。
- タブは自分と reviewer だけになる。それ以外のペインは閉じるが、作業中のものは `kept (working)` として残る。同じタブに別の driver がいるとエラーで止まる。
- reviewer は MCP と通知を切って起動する。ツール定義の再送で費用が膨らむのを避け、ユーザーとやりとりするのは driver だけにするため。

### reviewer のモデル

既定は Sonnet。レビューは毎ラウンド回るので、1回あたりの費用と待ち時間が積み上がる。review-pr の中でバグを探す code-reviewer は Opus に固定されているので、reviewer を Sonnet にしても見逃しの多い部分の精度は落ちない。

認証・決済・データ移行など、見逃したときの影響が大きい変更では Opus にする。

```bash
herdr-coding -m opus
```

reviewer が既に動いていると使い回すので、`-m` を変えても切り替わらない。変えるときは先に reviewer のペインを閉じる。

`ListAgents` には他の driver の reviewer も並ぶ。接頭辞のペイン ID が自分のものと一致するものだけが自分の担当。

## 回す

1. ユーザーと要件を詰めて実装する。
2. reviewer にレビューを依頼する。
3. 返ってきた Critical と Important を直す。直さないものは理由を決める。
4. 2 に戻る。Critical と Important が 0 件になったら 5 へ。
5. ユーザーに報告し、続けて `/git-commit` を呼ぶ。コミットの了解は `/git-commit` の確認で取り、二重に聞かない。

2〜4 はユーザーに確認を取らずに回す。止まるのは次のときだけ:

- 指摘を直すと要件や仕様が変わる
- 直し方が複数あって優劣がつかない
- 同じ指摘を「直さない」と返したのに、reviewer が2回続けて出してきた
- 5 ラウンド回っても 0 件にならない。細かい指摘が尽きないまま回し続けないため

Suggestions は直さなくてよい。5 の報告に一覧で添え、ユーザーに選んでもらう。

### 依頼文

依頼の前に、新しく作ったファイルを `git add -N <ファイル>` で追跡対象にする。review-pr は `git diff` で対象を決めるので、untracked のままだとレビューされない。

reviewer はこの会話の文脈を持たない。1通目に対象・要件・観点・返してほしい形式を書く。

```
SendMessage(to: "wk-p3-reviewer", message: "未コミットの差分をレビューしてほしい。
`/pr-review-toolkit:review-pr code errors tests comments types` を実行してほしい。simplify はファイルを書き換えるので含めない。
要件は〈…〉。
ファイルは編集せず、Critical / Important / Suggestions に分けて、それぞれ file:line 付きで返してほしい。
該当なしの区分は『0件』と書いてほしい。")
```

2回目以降は、前回の指摘に対して何をしたかを添える。reviewer が同じ指摘を出し直さずに済む。

```
SendMessage(to: "wk-p3-reviewer", message: "前回の指摘を反映したので、同じ観点でもう一度レビューしてほしい。
直した: [C1] foo.rb:42 の nil 分岐、[I2] bar.rb:10 の例外の握りつぶし
直さない: [I3] baz.rb:5 のメソッド分割。呼び出し元が1箇所で、分けると読む場所が増えるため
直さないと決めたものは、新しい根拠がなければ再度挙げなくてよい。")
```

### 指摘を管理する

採否を `TodoWrite` に積む。ラウンドをまたぐと、どれを直しどれを落としたかが会話の中にしか残らず、コンパクトが挟まると消える。

- 1指摘1項目。直さないものも理由付きで残す。
- completed にするのは、直した差分を自分で確認してから。

### 報告

```
## レビュー結果（3ラウンドで Critical / Important 0件）

### 直した
- [C1] foo.rb:42 — nil のときの分岐を追加
...

### 直さなかった
- [I3] baz.rb:5 — 理由

### Suggestions（未対応）
1. qux.rb:8 — 定数名を〈…〉に
```

## 規律

- **reviewer に書き込ませない。** 同じ作業ツリーで動いているので、両方が書くとファイルを取り合う。書き込むのはこのペインだけ。
- reviewer に差分を貼って渡さない。同じ作業ツリーなので、`git add -N` 済みなら `git diff` で同じものが見える。
- 指摘を全部飲まない。レビューは提案で、採否を決めるのはこのペイン。全部直すと要件から離れる。
- 返事は自動で届く。`ListAgents` を繰り返して待たない。
- reviewer は通知を切って起動しているので、権限の確認で止まっても知らせが来ない。返事がなかなか届かないときは、reviewer のペインで許可待ちになっていないか見てもらうようユーザーに伝える。
- `herdr agent prompt` は使わない。TTY への打ち込みになり、返事を画面から読み取ることになる。
- 自分の権限で拒否された操作を reviewer に代行させない。ユーザーの許可判断を迂回することになる。
- 手で閉じてよいのは自分が作ったペインだけ。仕事が終わったら reviewer を残すか閉じるかをユーザーに確認する。
