# Terraform で見ること

Terraform のコード（`*.tf`、`*.tfvars`、`.terraform.lock.hcl`）を変えた PR で読む。[common.md](common.md) と同じく、括弧の中は当てはまる観点と、ふつうの重さ。

## 作り直しとデータの消失

- 属性の変更で replace になり、DB やストレージのデータが消えないか（code、must）
- resource の名前や module の場所を変えたときに、`moved` ブロックがあるか。ないと作り直しになる（code、should）
- 消えると困るリソースに、`prevent_destroy` や `deletion_protection` があるか（code、should）
- 要素の増減があるリソースを `count` で作っていないか。途中の要素を消すと、後ろの要素が作り直しになる。`for_each` で済まないか（code、should）

## バージョンの固定

- `required_version` と `required_providers` で、バージョンの範囲を決めているか（conventions、should）
- provider を足すか上げたときに、`.terraform.lock.hcl` も更新しているか（conventions、should）
- 外部の module を、バージョンか commit で固定しているか（conventions、should）

## 変数と出力

- `variable` に `type` があるか（types、should）
- 入る値が限られる `variable` に、`validation` があるか（types、nit）
- 秘密の値を持つ `variable` と `output` に、`sensitive = true` があるか（security、should）

## セキュリティ

- 秘密の値を、`*.tf` や commit する `*.tfvars` に書いていないか（security、must）
- データベースや管理用のポートを、`0.0.0.0/0` に開けていないか（security、must）
- ストレージを、意図せず公開していないか（security、must）
- IAM の権限で、`*` を必要以上に使っていないか（security、should）
- 保存するデータの暗号化を切っていないか（security、should）

## 構成

- 環境ごとに変わる値を、`variable` か環境ごとのファイルへ出しているか（conventions、nit）
- module の切り方とディレクトリの置き方が、近くの既存のコードと揃っているか（conventions、nit）

置き方の決まりはリポジトリによって違う。CLAUDE.md・AGENTS.md と近くの既存のコードを基準にし、採っていない形を持ち込む指摘はしない。
