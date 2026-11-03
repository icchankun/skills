# 新しい指摘を見張る

SKILL.md のステップ7で報告したあと、PR が開いているあいだ、新しい指摘と人のレビューを見張る。`--once` のときは見張らない。

`fetch_pr_comments.rb` を1分ごとに回すループを一時ファイルのスクリプトに書き、`hc run --bg --name review-wait bash <スクリプト>` で起動してからターンを終える。終わると、その知らせが次の入力として届くので、`hc read review-wait` で出力を読み、`hc rm review-wait` で消す。`since` は報告した時刻（`date -u +%Y-%m-%dT%H:%M:%SZ`）。

```bash
since=<報告した時刻>
while :; do
  out=$(ruby <skill のディレクトリ>/scripts/fetch_pr_comments.rb "$REPO" <PR番号>) || exit 1
  jq -e --arg since "$since" '.unresolved_thread_count > 0 or any(.reviews[]; .author_type == "User" and .submitted_at > $since)' <<<"$out" >/dev/null && { printf '%s\n' "$out"; exit 0; }
  state=$(gh pr view <PR番号> -R "$REPO" --json state -q .state) || exit 1
  [ "$state" = OPEN ] || exit 3
  sleep 60
done
```

待つあいだはトークンを使わない。直したスレッドは resolve し、直さないスレッドは最後が自分の返信になっているので、どちらも数えない。新しい行へのコメントか、人のレビュー（承認を含む）で止まる。PR 全体へのコメント（Conversation 欄）は見ない。

- exit 0: 届いた。SKILL.md のステップ1に戻る。人のレビューの本文は出力の `reviews` から読み、ステップ2で同じように仕分け、`gh pr comment` で返信する。承認だけなら、承認されたことを伝えて、もう一度見張りを起動する
- exit 3: PR が閉じたかマージされた。その旨を伝えて終える
- それ以外: `gh` が失敗した。エラー内容を伝えて終える

見張りはこのセッションが開いているあいだだけ動く。セッションを閉じたら、開き直したときに `resolving-pr-reviews <PR番号>` で拾い直す。
