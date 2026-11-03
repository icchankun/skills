# 入力のディレクトリを作る

reviewing-pull-requests・checking-review-findings・checking-library-updates は、呼び出し元のスクリプト（dotfiles の codex-pr-review・codex-dep-review）が作る入力のディレクトリを読む。人に頼まれて、依頼文に入力のディレクトリが書かれていないときは、ここの手順で同じ中身を作ってから始める。

作るのは一時的なディレクトリと worktree だけで、作業中のリポジトリのファイルは変えない。いつも1回目（ラウンド 1）として作る。

## 1. PR を読み、head を worktree に出す

リポジトリの中で動かす。`<PR>` は番号か URL。

```bash
input="$(mktemp -d)"
gh pr view <PR> --json number,title,body,author,baseRefName,headRefOid,url,isDraft \
  --jq '{number, title, body, author: .author.login, base: .baseRefName, head: .headRefOid, url, draft: .isDraft}' \
  > "$input/pr.json"
repo="$(gh repo view --json nameWithOwner --jq .nameWithOwner)"
number="$(jq -r .number "$input/pr.json")"
base="$(jq -r .base "$input/pr.json")"
head="$(jq -r .head "$input/pr.json")"
author="$(jq -r .author "$input/pr.json")"
git fetch --quiet origin "$base" "pull/$number/head"
merge_base="$(git merge-base "origin/$base" "$head")"
tree="$(mktemp -d)/tree"
git worktree add --quiet --detach "$tree" "$head"
# lockfile と生成物は差分から外し、名前だけ skipped-files に残す（スクリプトと同じ）
skip=(':(exclude,glob)**/*.lock' ':(exclude,glob)**/package-lock.json' ':(exclude,glob)**/npm-shrinkwrap.json'
  ':(exclude,glob)**/yarn.lock' ':(exclude,glob)**/pnpm-lock.yaml'
  ':(exclude,glob)**/*.min.js' ':(exclude,glob)**/*.min.css' ':(exclude,glob)**/*.map'
  ':(exclude,glob)**/*.snap' ':(exclude,glob)**/__snapshots__/**')
git diff --no-color --no-ext-diff "$merge_base" "$head" -- . "${skip[@]}" > "$input/diff.patch"
git diff --name-only "$merge_base" "$head" | head -n 15 > "$input/changed-files"
git diff --name-only "$merge_base" "$head" | grep -vxF -f <(git diff --name-only "$merge_base" "$head" -- . "${skip[@]}") > "$input/skipped-files" || true
```

以降は `$tree` に移って読む。終わったら `git worktree remove --force "$tree"` と `rm -rf "$input"` で片付ける。

## 2. 会話を写す

スクリプトと同じ形にする。`is_pr_author` で、作者の説明かどうかを見分けるため。CI やカバレッジの bot の長い報告でトークンが増えないよう、本文は2000字で切る。

```bash
{
  gh api --paginate --slurp "repos/$repo/issues/$number/comments"
  gh api --paginate --slurp "repos/$repo/pulls/$number/reviews"
  gh api --paginate --slurp "repos/$repo/pulls/$number/comments"
} | jq -s --arg author "$author" '
  def who: {author: .user.login, is_pr_author: (.user.login == $author), is_bot: (.user.type == "Bot")};
  def cut: if length > 2000 then .[:2000] + "…（以下略）" else . end;
  (.[0] | add // [] | map(who + {kind: "comment", body: (.body | cut), created_at})) +
  (.[1] | add // [] | map(select(.body != "") | who + {kind: "review", state, body: (.body | cut), created_at: .submitted_at})) +
  (.[2] | add // [] | map(who + {kind: "inline", id, in_reply_to: .in_reply_to_id, path, line, body: (.body | cut), created_at}))
  | sort_by(.created_at)' > "$input/conversation.json"
```

## 3. guidance・history・past reviews を写す（reviewing-pull-requests だけ）

ベースの CLAUDE.md と AGENTS.md を、ルートと、変えたディレクトリとその親から写す。ベースから取るので、PR が基準を書き換えられない。

```bash
{ echo .; while read -r f; do d="$(dirname "$f")"; while [ "$d" != . ]; do echo "$d"; d="$(dirname "$d")"; done; done < "$input/changed-files"; } |
  sort -u | while read -r d; do
    for name in CLAUDE.md AGENTS.md; do
      p="$name"; [ "$d" = . ] || p="$d/$name"
      git cat-file -e "$merge_base:$p" 2>/dev/null || continue
      mkdir -p "$input/guidance/$(dirname "$p")"
      git show "$merge_base:$p" > "$input/guidance/$p"
    done
  done
while read -r f; do
  printf '## %s\n\n' "$f"
  git log -n 3 --format='### %h %as %an%n%n%s%n%n%b' "$merge_base" -- "$f"
done < "$input/changed-files" > "$input/history.md"
```

`past_reviews.json` には、変えたファイルを以前触って merge された PR（新しい順に3つまで）と、そこでそのファイルに付いたインラインのコメントを入れる。コミットから PR を引くのに GraphQL を使う。

```bash
shas="$(while read -r f; do git log -n 3 --format=%H "$merge_base" -- "$f"; done < "$input/changed-files" | sort -u | head -n 100)"
printf '[]\n' > "$input/past_reviews.json"
if [ -n "$shas" ]; then
  query="$(printf '%s\n' "$shas" | jq -Rrs --arg owner "${repo%%/*}" --arg name "${repo#*/}" '
    split("\n") | map(select(. != "")) | to_entries
    | map("c\(.key): object(oid: \"\(.value)\") { ... on Commit { associatedPullRequests(first: 3) { nodes { number title url mergedAt } } } }")
    | "query { repository(owner: \"\($owner)\", name: \"\($name)\") { \(join(" ")) } }"')"
  files="$(jq -R . "$input/changed-files" | jq -s .)"
  gh api graphql -f query="$query" | jq -c --argjson self "$number" '
    [.data.repository[]? | .associatedPullRequests.nodes[]? | select(.mergedAt != null and .number != $self)]
    | unique_by(.number) | sort_by(.mergedAt) | reverse | .[:3] | .[]' |
    while read -r past; do
      gh api --paginate --slurp "repos/$repo/pulls/$(jq -r .number <<<"$past")/comments" |
        jq -c --argjson past "$past" --argjson files "$files" '
          def cut: if length > 2000 then .[:2000] + "…（以下略）" else . end;
          $past + {comments: [add // [] | .[] | select(.path as $p | $files | index($p)) | {author: .user.login, path, line, body: (.body | cut)}]}
          | select(.comments | length > 0)'
    done | jq -s . > "$input/past_reviews.json"
fi
```

## 4. ゲートを確かめる（checking-library-updates だけ）

`gates.json` は作らない。スクリプトのゲートは機械的に確かめるものなので、代わりに次を自分で確かめ、通らないものは `reasons` に書いて `needs_human` にする。

- 作者が `renovate[bot]` か `dependabot[bot]` か（`pr.json` の `author`）
- 変わったファイルが、依存のファイルと `FROM`・`image:`・`uses:` の行だけか（`diff.patch`）
- CI が通っているか（`gh pr checks "$number"`）
- major を上げていないか（本文の版の表か文）
- lockfile に新しいパッケージが増えていないか（`diff.patch`）

上がる版の `from` と `to` は、本文の版の表か文から読む。
