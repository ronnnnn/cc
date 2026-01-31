# Catch-up Plugin

技術・ツール・フレームワークの最新バージョン取得と技術調査を支援する Claude Code plugin です。

## 機能

### Skills

| スキル          | 説明                                               |
| --------------- | -------------------------------------------------- |
| `tech-research` | 技術調査を優先順位に基づく複数ソースから構造化実行 |

### Agents

| エージェント     | 説明                                                   |
| ---------------- | ------------------------------------------------------ |
| `latest-version` | 言語・ツール・フレームワークの最新安定バージョンを取得 |

## インストール

### マーケットプレースから (推奨)

```bash
# 1. マーケットプレースを追加
/plugin marketplace add ronnnnn/cc

# 2. プラグインマネージャーを開く
/plugin

# 3. Discover タブで "catch-up" を選択してインストール
```

または CLI から直接インストール:

```bash
/plugin install catch-up@cc
```

**インストールスコープ:**

| スコープ  | 説明                                   |
| --------- | -------------------------------------- |
| `user`    | 全プロジェクトで使用可能 (デフォルト)  |
| `project` | このリポジトリの全コラボレーターで共有 |
| `local`   | このリポジトリで自分のみ使用           |

スコープを指定してインストール:

```bash
claude plugin install catch-up@cc --scope project
```

## 使い方

### 技術調査

自然言語で技術調査を依頼すると `tech-research` スキルが自動起動します:

```
技術調査して: React Server Components の使い方
API の仕様を確認して: Stripe Checkout API
ライブラリの使い方を教えて: zod
```

**調査ソースの優先順位:**

1. LSP (ローカルコードベース)
2. deepwiki MCP (GitHub リポジトリのドキュメント)
3. context7 MCP (ライブラリドキュメント)
4. WebSearch (一般的な検索)

### 最新バージョン取得

最新バージョンを聞くと `latest-version` エージェントが起動します:

```
Node.js の最新 LTS バージョンを調べて
React と Next.js の最新安定バージョンを教えて
Terraform の最新バージョンは？
```

**取得ソースの優先順位:** GitHub Releases → 公式ソース

## ファイル構造

```
catch-up/
├── .claude-plugin/
│   └── plugin.json              # Plugin マニフェスト
├── agents/
│   └── latest-version.md        # 最新バージョン取得エージェント
├── skills/
│   └── tech-research/
│       ├── SKILL.md             # 技術調査スキル
│       └── references/
│           └── source-guide.md  # ソース選択の詳細ガイド
└── README.md
```

## 技術仕様

| 項目       | 内容                                                  |
| ---------- | ----------------------------------------------------- |
| **ツール** | Bash, WebFetch, WebSearch, deepwiki MCP, context7 MCP |
| **言語**   | 日本語                                                |
