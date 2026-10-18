---
name: dispatching-tasks
description: チケットや実装方針を受け取ったセッション（指令役）が、作業用のブランチと worktree を作り、その worktree で起動した driver に作業を引き継いで手を離す。GitHub Issue や Notion チケットのリンク、PR を前提とした実装方針を渡されたとき、「この作業を始めて」「worktree に渡して」と言われた場合に使う。実装そのものは引き継いだ先の running-dev-flow が進める。
---

# dispatching-tasks

指令役は、作業を受け取って worktree に渡すところまでを受け持つ。実装はしない。

## 手順

1. **チケットを読む。** リンクがあれば中身を読み、要件・受け入れ条件・関連するリンクを拾う。曖昧な点があれば、ここでユーザーに聞く。渡した後に聞き直すより早い。
2. **ブランチと worktree を作る。** `creating-git-branches` を呼ぶ。
   - Herdr の中なら、`git wt` のフックが worktree を Herdr で開き、最初のペインで Claude を driver として起動する。フックの出力に `driver: <agent名>` が出る。
   - 出なければ、`herdr agent list` で cwd が worktree のパスと一致する agent を探す。
3. **引き継ぐ。** `handover <agent名>` を呼ぶ。引き継ぎには次を入れる。
   - チケットの URL と、1 で拾った要件・受け入れ条件
   - 決めたこと、聞いて答えをもらったこと
   - 最初にやること: `/running-dev-flow` を実行する
4. **手を離す。** 誰に何を渡したかをユーザーに伝えて終える。以降のやりとりは、引き継いだ先のペインで行う。

## Herdr の外にいるとき

`HERDR_ENV` が 1 でなければ、driver は立たない。worktree のパスを伝え、そこで新しいセッションを開いて `/running-dev-flow` を実行するよう伝えて終える。

## 規律

- 実装しない。指令役のセッションに実装の文脈を積むと、引き継ぐ量が増え、二重に作業が進む。
- 引き継ぎ先が見つからないまま `handover` しない。宛先のない引き継ぎは読まれない。
