# 依存（deps）

当てはまるファイル: `Gemfile`、`Gemfile.lock`、`package.json`、ロックファイル、`go.mod`、`requirements*.txt`

- 新しく足した依存は、なぜ要るのかが書いてあるか。既にある依存や標準ライブラリで代わりにならないか
- ライセンスがリポジトリで使えるものか
- メンテされているか（最後のリリース、未対応の脆弱性）
- 更新なら、パッチ・マイナー・メジャーのどれか。変更履歴に破壊的な変更がないか。このリポジトリで使っている箇所に影響がないか

出典: OpenSSF「Concise Guide for Evaluating Open Source Software」
