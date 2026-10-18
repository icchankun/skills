# migration

当てはまるファイル: `db/migrate/`、`migrations/`、`schema.rb`、`structure.sql`、`*.sql`

- 戻せるか（down / rollback が書いてあるか、戻すとデータが消えないか）
- 大きなテーブルをロックしないか（カラムの追加でのデフォルト値、インデックスの作成、型の変更）
- コードとどちらを先にデプロイするか。古いコードが新しいスキーマで、新しいコードが古いスキーマで動くか
- 既存のデータの移行が要るか。要るなら、その手順が PR にあるか

出典: strong_migrations の README、GitLab の Migration Style Guide
