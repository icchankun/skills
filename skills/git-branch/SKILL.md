---
name: git-branch
description: gitブランチ名をConventional Branch規則に従って決め、worktreeとして作成する。会話の文脈・チケット・差分からブランチ名を自分で決め、最新のdevelop（なければデフォルトブランチ）から切る。作業ブランチの上にいるときだけ、最新から切るか積むか（stacked PR）を聞く。ユーザーが「ブランチを切りたい」「新しいブランチ」「作業を始めたい」「worktreeを作りたい」「この作業用のブランチ」「新しい機能を実装したい」「バグを直したい」と言った場合や、新しいタスクに取りかかろうとしている場合に使う。明示的にブランチ名を指定していなくても、新しい作業の開始を示唆していればこのスキルを使うこと。
---

# /git-branch スキル

gitの差分や会話の文脈をもとに、[Conventional Branch](https://conventional-branch.github.io) 命名規則に従ったブランチ名を決め、worktreeとして作成する

ブランチ名は自分で決め、候補を並べてユーザーに選ばせない。名前は後から変えられるので、選択肢を読ませる手間の方が高くつく

作成元は、作業ブランチの上にいるときだけ聞く。最新から切るか、今のブランチの上に積むかは、PR の出し方そのものが変わるので自分では決めない

## 手順

### ステップ1: 作業内容の把握

以下のコマンドを**並列**で実行:

- `git diff`
- `git diff --cached`
- `git status`（`-uall` は使わない）
- `git branch --show-current`
- `git fetch origin`
- `git branch -a --list 'develop' 'origin/develop'`
- `gh repo view --json defaultBranchRef --jq '.defaultBranchRef.name'`

何をする作業かを、次の順で読み取る:

1. 引数・会話の文脈（Issue や Notion チケットの内容を含む）
2. 差分

どちらからも読み取れないときだけ、ユーザーに作業内容を1回質問する

### ステップ2: チケット番号の特定

引数・会話・リンクからチケット番号を拾う

- GitHub Issue: `https://github.com/<owner>/<repo>/issues/42` → `42`
- Notion などで `PROJ-123` 形式のIDがある: `PROJ-123`

見つからなければチケット番号なしで命名する。番号の有無をユーザーに尋ねない

### ステップ3: ブランチ名を決める

後述の「Conventional Branch 命名規則」に従って1つに決める

同名のブランチが既にある場合は、説明部分を変えて別の名前にする

### ステップ4: 作成元を決める

以降、`develop` があれば `develop`、なければリポジトリのデフォルトブランチを「ベース」と呼ぶ

作成元は次の順で決める:

1. 引数や会話で指定があればそれ
2. 現在のブランチがベースなら、リモートの最新のベース（`origin/<ベース>`）
3. 現在のブランチが作業ブランチなら、ユーザーに聞く:

```
どこから切りますか？
1. 最新の <ベース> から切る
2. 今のブランチ（<現在のブランチ名>）の上に積む（stacked PR）
```

ローカルのベースは古いことがあるので、ベースから切るときは必ず `origin/<ベース>` を使う

### ステップ5: worktreeの作成

`git wt`（`git worktree` のラッパー）でworktreeを作成する:

```bash
git wt <ブランチ名> <作成元>
git branch --unset-upstream <ブランチ名>
git config branch.<ブランチ名>.gh-merge-base <PRのマージ先>
```

- `origin/<ベース>` から切ると、追跡先が `origin/<ベース>` になる。そのままだと `git pull` でベースを取り込み、状態表示もベースとの比較になるので、2行目で外す。今のブランチの上に積んだときは追跡先が付かないので、2行目は失敗してよい
- 3行目で PR のマージ先を記録する。ベースから切ったときはベースの名前（`origin/` を付けない）、今のブランチの上に積んだときはそのブランチの名前。`/github-pr` と `gh pr create` はこれを PR のマージ先に使う

### ステップ6: 報告

作成したブランチ名・作成元・worktreeのパスを1行ずつ伝える。名前を変えたいと返された場合は、`git wt -m <旧名> <新名>` でブランチと worktree のディレクトリをまとめて改名する

## Conventional Branch 命名規則

参考: [Conventional Branch](https://conventional-branch.github.io)

### フォーマット

```
<type>/<description>
<type>/<ticket-id>-<description>  （チケット番号がある場合）
```

### タイプ一覧

変更の主目的に最も合うタイプを選ぶ:

| type | 用途 | 例 |
|------|------|------|
| `feat` | 新機能の追加 | `feat/add-login-page` |
| `fix` | バグ修正 | `fix/header-alignment-bug` |
| `chore` | コード以外のタスク | `chore/update-dependencies` |
| `refactor` | リファクタリング | `refactor/extract-auth-service` |
| `docs` | ドキュメント | `docs/update-readme` |
| `test` | テスト | `test/add-user-model-specs` |
| `ci` | CI設定 | `ci/add-lint-workflow` |
| `perf` | パフォーマンス改善 | `perf/optimize-query` |

### 命名ルール

- 小文字（`a-z`）、数字（`0-9`）、ハイフン（`-`）のみ使用
- 単語の区切りはハイフン
- ハイフンやドットを連続・先頭・末尾に置かない
- 簡潔かつ目的が明確に伝わる英語の名前にする

**良い例:**
- `feat/add-user-profile` — 目的が明確で簡潔
- `fix/PROJ-42-null-name-in-performers` — チケット番号と問題の内容がわかる
- `refactor/extract-auth-middleware` — 何をリファクタするかが具体的

**悪い例:**
- `feat/update` — 何を追加するのか不明
- `fix/bug` — どのバグかわからない
- `feat/Add-User-Profile-Page` — 大文字が混在
- `feat/add_user_profile` — アンダースコアではなくハイフンを使う

## 禁止事項

- `git commit` はこのスキル内では実行しない
