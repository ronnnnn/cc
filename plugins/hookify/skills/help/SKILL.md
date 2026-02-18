---
allowed-tools:
  - Read
---

このスキルは、「hookify ヘルプ」「hookify の使い方」「hookify help」「フックの設定方法」「hookify とは」などのリクエストで使用する。

# Hookify ヘルプ

以下のヘルプテキストをユーザーに表示する。

## 概要

Hookify は Claude Code のアクションに対して警告またはブロックするルールを作成できるプラグイン。ルールは YAML フロントマター付きのマークダウンファイルとして `hooks-rules/` ディレクトリに格納する。

## ルール配置場所 (優先順位: 低 → 高)

1. **グローバル**: `~/.claude/hooks-rules/*.md`
2. **プロジェクト**: `.claude/hooks-rules/*.md`

同名ルールはプロジェクト側が優先 (上書き)。プロジェクトルールで `enabled: false` を設定するとグローバルルールを無効化できる。

## スキル

- `/hookify:hookify` — 新規ルール作成 (会話分析または明示的指示から)
- `/hookify:list` — 設定済みルールの一覧表示
- `/hookify:configure` — ルールの有効/無効をインタラクティブに切り替え
- `/hookify:help` — このヘルプを表示

## クイックスタート

`~/.claude/hooks-rules/block-rm-rf.md` にルールファイルを作成する:

```markdown
---
name: block-rm-rf
enabled: true
event: bash
pattern: "rm\\s+-rf"
action: block
---

危険な rm -rf コマンドを検出しました。安全な代替手段を使用してください。
```

## ルール形式

ルールの構文、イベント、条件、パターンの詳細は `/hookify:hookify` でルール作成時に参照されるリファレンスドキュメントを参照。

## 公式 hookify からの改善点

1. **regex tool_matcher**: `mcp__claude_ai_(?!Slack__).*` のようなパターンが使える
2. **tool_name condition フィールド**: `field: tool_name` でツール名に対する条件が書ける
3. **ディレクトリベースのルール管理**: `hookify.*.local.md` のフラット管理ではなく `hooks-rules/` ディレクトリに整理
4. **グローバル + プロジェクトの 2 階層**: CWD に依存しない確実なルール読み込み
