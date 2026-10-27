---
name: checking-pr-checklists
description: 他人の PR を確かめるときに、コードの正しさ以外の観点（チケットと合っているか、migration は戻せるか、API は後方互換か、依存は要るか、権限は変わったか、など）を、PR の種類ごとのチェックリストで1項目ずつ確かめ、pass / fail / 判断できない で返す。ユーザーに影響する種類（UI・API・権限・migration）に当てはまるかも返す。reviewing-pull-requests から呼ばれるほか、「この PR の観点を確認して」「チェックリストで見て」と言われた場合に使う。バグ探しは /code-review、セキュリティは /security-review の役割で、この skill では見ない。
---

# checking-pr-checklists

```
/checking-pr-checklists <PR番号 または URL>
```

「この種類の変更なら、ここを確かめる」という観点を、PR の種類ごとのチェックリストで確かめる。バグ探しとセキュリティは見ない。

## 1. PR を読む

```bash
gh pr view <PR> --json title,body,url,files,headRefOid
gh pr diff <PR>
```

PR 本文やチケットのリンクから、要件を拾う。

## 2. 種類を決める

変えたファイルの場所から、当てはまる種類を選ぶ。`common` はいつも使う。

| 種類 | チェックリスト | ユーザー影響 |
|---|---|---|
| 共通 | `checklists/common.md` | |
| migration | `checklists/migration.md` | あり |
| API・スキーマ | `checklists/api.md` | あり |
| 依存 | `checklists/deps.md` | |
| 設定・環境変数 | `checklists/config.md` | |
| 権限・認証 | `checklists/auth.md` | あり |
| フィーチャーフラグ | `checklists/feature-flag.md` | |
| UI | `checklists/ui.md` | あり |
| 削除 | `checklists/deletion.md` | |

各チェックリストの「当てはまるファイル」を目安にする。迷ったら当てはまる方に倒す。見ない観点を作らないため。

リポジトリに `.claude/review-checklist.md` があれば、それも読み込む。リポジトリ固有の観点はそこに書いてある。

## 3. 1項目ずつ確かめる

読み込んだチェックリストの項目を、サブエージェント（Agent ツール、`model: sonnet`）に並列で渡す。1つのサブエージェントに1つの種類を任せ、PR の差分と本文、要件を渡す。

各項目を次のどれかで返させる。

| 結果 | 意味 |
|---|---|
| pass | 満たしている。根拠のファイル・行か、PR 本文の箇所を添える |
| fail | 満たしていない。何が足りないかを1文で書く |
| 判断できない | 差分と本文だけでは決められない。何が分かれば決められるかを1文で書く |

「判断できない」を pass にしない。AI が自信のないものを素通りさせないため。

## 4. 返す

```
種類: common, migration, deps
ユーザー影響: あり（migration）
結果: fail 1 / 判断できない 1 / pass 9

### fail
- [migration] 戻せるか — down が書かれておらず、カラムの削除を戻せない（db/migrate/20261018_drop_x.rb:5）

### 判断できない
- [deps] 変更履歴に破壊的な変更がないか — 7.2 から 8.0 への更新で、変更履歴のリンクがない

### pass
- [common] 要件と差分が合っている — チケットの3項目すべてに対応（app/…:12）
...
```

## 観点を育てる

チェックリストは、過去のレビューで実際に止めた観点から育てる。「こう言って止めた」が一番そのチームの基準に近いため。

頼まれたときに、許可リストのリポジトリ（`~/.config/dev-flow/repos`）から、自分とチームの人が書いたレビューコメントを集める。ボットのコメントは除く。

```bash
gh api "repos/<owner>/<repo>/pulls/comments?per_page=100&sort=created&direction=desc"
```

コメントを観点ごとにまとめ、どのチェックリストのどの項目に足すかを、元のコメントへのリンク付きで提案する。足すのはユーザーが選んだものだけにする。

## 規律

- PR にコメントしない。approve もしない。確かめた結果を返すまで。
- チェックリストにない観点を、その場で足して fail にしない。足すときは「観点を育てる」の手順で、ユーザーに選んでもらう。
