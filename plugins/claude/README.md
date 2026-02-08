# Claude Plugin

CLAUDE.md ファイルの作成・更新・品質管理、.claude/rules の作成を支援する Claude Code plugin です。

## 機能

### Skills

| スキル            | 説明                                                      |
| ----------------- | --------------------------------------------------------- |
| `/claude:init`    | CLAUDE.md を新規作成 (プロジェクト分析、テンプレート生成) |
| `/claude:update`  | CLAUDE.md を精査・最適化 (冗長削除、必須セクション確認)   |
| `create-rules`    | .claude/rules にプロジェクト固有の規約を抽出・保存        |
| `claude-md-style` | CLAUDE.md スタイルガイド・ベストプラクティス              |

### Agents

| エージェント         | 説明                                      |
| -------------------- | ----------------------------------------- |
| `claude-md-reviewer` | CLAUDE.md 品質レビュー (自動提案、改善案) |

## インストール

### マーケットプレースから (推奨)

```bash
# 1. マーケットプレースを追加
/plugin marketplace add ronnnnn/cc

# 2. プラグインマネージャーを開く
/plugin

# 3. Discover タブで "claude" を選択してインストール
```

または CLI から直接インストール:

```bash
/plugin install claude@cc
```

**インストールスコープ:**

| スコープ  | 説明                                   |
| --------- | -------------------------------------- |
| `user`    | 全プロジェクトで使用可能 (デフォルト)  |
| `project` | このリポジトリの全コラボレーターで共有 |
| `local`   | このリポジトリで自分のみ使用           |

スコープを指定してインストール:

```bash
claude plugin install claude@cc --scope project
```

## 使い方

### CLAUDE.md 新規作成

```bash
/claude:init          # 現在のディレクトリに作成
/claude:init ./path   # 指定パスに作成
```

**ワークフロー:**

1. プロジェクト構造を分析 (package.json, Makefile 等)
2. 技術スタックを検出
3. 必須セクションを含むテンプレート生成
4. **ユーザー承認を取得**
5. CLAUDE.md を作成

### CLAUDE.md 更新・最適化

```bash
/claude:update          # 現在のディレクトリの CLAUDE.md を更新
/claude:update ./path   # 指定パスの CLAUDE.md を更新
```

**ワークフロー:**

1. 既存 CLAUDE.md を読み込み
2. 必須セクションの準拠確認
3. 冗長コンテンツを検出
4. 最適化提案を提示
5. **ユーザー承認を取得**
6. 変更を適用

## 必須コンテンツ

このプラグインで作成・更新される CLAUDE.md には以下が含まれます:

### 日本語使用時のスタイリング

- 技術用語や固有名詞は原文を維持
- スペース: 日本語と半角英数字記号間に半角スペース
- 文体: ですます調、句読点は「。」「、」
- 記号: 丸括弧は半角「()」、鉤括弧は全角「「」」

### コード参照

参照元・参照先の調査は Grep ではなく LSP を使用 (goToDefinition, findReferences, incomingCalls, outgoingCalls)

### 技術調査

優先順位: LSP → deepwiki MCP → context7 MCP → WebSearch

## ファイル構造

```
claude/
├── .claude-plugin/
│   └── plugin.json          # Plugin マニフェスト
├── agents/
│   └── claude-md-reviewer.md # 品質レビューエージェント
├── skills/
│   ├── init/
│   │   └── SKILL.md         # 新規作成スキル
│   ├── update/
│   │   └── SKILL.md         # 更新・最適化スキル
│   ├── create-rules/
│   │   ├── SKILL.md         # ルール作成スキル
│   │   └── references/
│   │       └── rules-format.md
│   └── claude-md-style/
│       └── SKILL.md         # スタイルガイドスキル
└── README.md
```

## 技術仕様

| 項目           | 内容                          |
| -------------- | ----------------------------- |
| **ツール**     | Read, Write, Edit, Glob, Grep |
| **言語**       | 日本語                        |
| **目標文字数** | 500-1,500 words (最大 3,000)  |

## トラブルシューティング

### CLAUDE.md が見つからない

```bash
/claude:init  # 新規作成してください
```

### 必須セクションが不足している

```bash
/claude:update  # 自動で追加されます
```

### ファイルが肥大化している

```bash
/claude:update  # 冗長コンテンツを検出・削除提案します
```
