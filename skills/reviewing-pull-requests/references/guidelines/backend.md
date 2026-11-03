# サーバー側で見ること

サーバー側のコード（Ruby のファイル、`Gemfile`、`db/migrate`、`config/` など）を変えた PR で読む。[common.md](common.md) と同じく、括弧の中は当てはまる観点と、ふつうの重さ。例は Rails で書いているが、ほかのフレームワークでも同じことを見る。

## DB とクエリ

- N+1 のクエリになっていないか。関連を読むなら `includes`・`preload`・`eager_load` で先に読んでいるか（code、件数が増えると遅くなるなら should）
- 件数の多いテーブルを、一度に全部メモリに読んでいないか。`find_each`・`find_in_batches` で分けているか（code、should）
- `update_all`・`delete_all` などが、一度に何件を処理するか。件数が多いとタイムアウトやロックにならないか（code、should）
- 検索や並べ替えに使うカラムに、インデックスがあるか。新しく足す検索条件なら、マイグレーションでインデックスも足しているか（code、should）
- `joins` で、思ったより多くの行にならないか（code、nit）
- 使わないカラムまで読んでいないか（code、nit）
- あるかどうかだけを知りたいときに、`count` ではなく `exists?` を使っているか（code、nit）
- `where` に配列を渡すとき、空の配列が来たら何が起きるか（code、should）
- 一覧を返すときに、`order` で順番を決めているか。決めないと、DB によって順番が変わる（code、should）

## 層の分け方

- Controller に、業務のロジック（状態の判定・計算・複数のモデルの更新）が書かれていないか（conventions、nit。同じロジックが別の Controller にもあるなら should）
- 画面や API の都合のロジックと、業務のロジックが混ざっていないか（conventions、nit）
- ロジックが大きくなったときの置き場所（Service Object・Form Object・Concern など）が、リポジトリの採っている形と揃っているか（conventions、nit）
- ルーティングと Controller のアクションが、REST の形になっているか（conventions、nit）

置き場所の決まりはリポジトリによって違う。CLAUDE.md・AGENTS.md と近くの既存のコードを基準にし、採っていない形を持ち込む指摘はしない。

## セキュリティ

- SQL を文字列の連結や式展開で組み立てていないか（security、must）
- Strong Parameters で、受け取ってよい項目だけを許しているか（security、must）
- 他の人のリソースを読んだり変えたりできないか。`current_user` などで絞ってから探しているか（security、must）
- `html_safe`・`raw` などで、エスケープを外していないか（security、must）

## データの整合

- モデルの validation だけでなく、DB の制約（NOT NULL・一意・外部キー）もあるか（types、should）
- 関連する行を消したとき、残った行がどうなるか（`dependent` など）（types、should）
- enum の値を変えたり並べ替えたりして、既にある行の意味が変わらないか（types、must）

## トランザクションと例外

- まとめて成功するか失敗するかにしたい複数の更新が、1つのトランザクションに入っているか（errors、must）
- 途中で失敗したとき、どこまで戻るか。rollback させたい例外が、中で握りつぶされていないか（errors、must）
- トランザクションの中で、メールの送信や外部の API の呼び出しをしていないか。rollback しても取り消せない（errors、should）

## マイグレーション

- 戻せるか（`change` で戻せる書き方か、`down` があるか）（types、should）
- 本番の大きなテーブルで、長いロックや時間のかかる処理にならないか（インデックスの作成、カラムの追加・型の変更、既にある行の書き換え）（types、should）

## コールバック

- 新しく足すコールバックが、明示的な呼び出しで済まないか（conventions、nit）
- メールの送信・外部の API・ほかのモデルの更新のような、保存のほかに影響が出る処理をコールバックに入れていないか（conventions、should）

## テスト

- 変えた振る舞いに RSpec があるか（tests、should）
- FactoryBot の trait で、準備の重複を減らせないか（tests、nit）
- 準備・実行・確認の順に書かれていて、何を確かめているかが読めるか（tests、nit）

## ビュー

- ビューに、ヘルパーや Decorator に出せる複雑なロジックがないか（conventions、nit）
