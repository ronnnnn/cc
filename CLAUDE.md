# CLAUDE.md

Claude Code プラグインのマーケットプレースおよびプラグイン群。`plugins/` 配下に各プラグインを格納。

## 開発コマンド

```bash
bun i                                    # 依存関係インストール (bun 必須)
bun fmt                                  # フォーマット
claude plugin validate .                 # マーケットプレース検証
claude plugin validate ./plugins/<name>  # 個別プラグイン検証
```

## コミット規約

Conventional Commits 形式 (`commitlint.config.mjs` 参照)

例: `feat(git): PR 作成スキルを追加`

## ツールチェーン

- **パッケージマネージャー**: bun (npm/yarn 不可)
- **Git hooks**: lefthook (pre-commit: prettier, commit-msg: commitlint)
