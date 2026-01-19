# CLAUDE.md

Claude Code プラグインのマーケットプレースおよびプラグイン群。現在は `git` プラグインを提供。

## 開発コマンド

```bash
bun i                           # 依存関係インストール (bun 必須)
bun fmt                         # フォーマット
claude plugin validate .        # マーケットプレース検証
claude plugin validate ./git    # git プラグイン検証
```

## コミット規約

Conventional Commits 形式 (`commitlint.config.mjs` 参照)

例: `feat(git): PR 作成コマンドを追加`

## ツールチェーン

- **パッケージマネージャー**: bun (npm/yarn 不可)
- **Git hooks**: lefthook (pre-commit: prettier, commit-msg: commitlint)
