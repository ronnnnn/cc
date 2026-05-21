# Dev Plugin

開発ワークフローを支援する Claude Code plugin です。

## 機能

### Skills

| スキル           | 説明                                                                        |
| ---------------- | --------------------------------------------------------------------------- |
| `/dev:comment`   | 変更差分を分析し、実装意図 (Why) を説明するコメントを追加                   |
| `/dev:do`        | 複数タスクを並列実行 (subagent / Agent Teams 自動選択)                      |
| `/dev:plan`      | 資料を分析してフェーズ別行動計画を作成                                      |
| `/dev:docs-html` | 引数の内容を用途別カテゴリに分類し、dark/light + 日/英 切替付き HTML を生成 |

## インストール

### マーケットプレースから (推奨)

```bash
# 1. マーケットプレースを追加
/plugin marketplace add ronnnnn/cc

# 2. プラグインマネージャーを開く
/plugin

# 3. Discover タブで "dev" を選択してインストール
```

または CLI から直接インストール:

```bash
/plugin install dev@cc
```

**インストールスコープ:**

| スコープ  | 説明                                   |
| --------- | -------------------------------------- |
| `user`    | 全プロジェクトで使用可能 (デフォルト)  |
| `project` | このリポジトリの全コラボレーターで共有 |
| `local`   | このリポジトリで自分のみ使用           |

スコープを指定してインストール:

```bash
claude plugin install dev@cc --scope project
```

## 使い方

### コメント追加

```bash
/dev:comment  # ローカルの変更差分にコメントを追加
```

自然言語でも起動します:

```
コメントを追加して
変更にコメントを付けて
実装意図をコメントして
add why comments
```

**ワークフロー:**

1. `git diff HEAD` で staged + unstaged の変更差分を取得
2. 各変更ファイルを読み込み、既存コメントの言語・スタイルを確認
3. 「なぜそうしているのか (Why)」が必要な箇所を特定
4. 実装意図が不明な場合はユーザーに確認
5. Edit ツールでコメントを直接追加

**特徴:**

- **Why のみコメント** - コードを読めばわかる What コメントは追加しない
- **既存スタイル準拠** - ファイル内の既存コメントの言語と形式に合わせる
- **13 言語対応** - TypeScript, Python, Go, Rust, Dart, Swift, Kotlin/Java 等のコメント形式テーブルを内蔵
- **意図不明時は確認** - 推測でコメントを書かず、AskUserQuestion で実装者に確認

### 並列タスク実行

```bash
/dev:do タスク1、タスク2、タスク3
```

自然言語でも起動します:

```
並列でやって
同時に作業して
これとこれとこれをやって
```

**ワークフロー:**

1. 引数からタスクを抽出・分類
2. subagent / Agent Teams を自動選択
3. 並列実行
4. 結果を集約して報告

### 行動計画作成

```bash
/dev:plan <資料パス or URL>
```

自然言語でも起動します:

```
行動計画を作成して
アクションプランを作成
資料から計画を立てて
```

**ワークフロー:**

1. 資料 (ファイル、URL、PR、設計書等) を読み込み・分析
2. 不明点をインタビューで明確化
3. アトミックなタスクに分解
4. 依存関係を整理してフェーズ構成
5. フェーズごとにファイルを分割して出力

### HTML ドキュメント生成

```bash
/dev:docs-html <内容、資料パス、URL、PR など>
```

自然言語でも起動します:

```
HTML ドキュメントを作って
HTML 資料を生成して
リッチな資料を HTML で出力して
```

**特徴:**

- **カテゴリ自動分類** - 内容に応じて `plan` / `review` / `design` / `prototype` / `report` / `explainer` / `diagram` / `slide` / `editor` から最適なレイアウトを選択
- **dark/light モード切替** - すべての生成 HTML に組み込み、`prefers-color-scheme` を初期値に `localStorage` で永続化
- **日/英 言語切替** - 全テキストを両言語で保持し、ボタン操作で瞬時に切替 (ページ再ロード不要)
- **単一ファイル・外部依存なし** - CSS/JS/SVG をすべて 1 ファイルに内包しブラウザでそのまま開ける
- **モバイル対応** - レスポンシブ設計とアクセシビリティ (ARIA, focus) を確保

**ワークフロー:**

1. 引数 (ファイル/URL/PR/テキスト) を読み込み・分析
2. カテゴリを判定 (不明確な場合は AskUserQuestion で確認)
3. 出力先パスを確認
4. 日/英 両言語のコンテンツを準備
5. ベーステンプレートにカテゴリ別レイアウトを適用して HTML を生成
6. セルフチェック (テーマ/言語切替、レスポンシブ) を実行

## ファイル構造

```
dev/
├── .claude-plugin/
│   └── plugin.json          # Plugin マニフェスト
├── skills/
│   ├── comment/
│   │   └── SKILL.md         # コメント追加スキル
│   ├── do/
│   │   ├── SKILL.md         # 並列タスク実行スキル
│   │   └── references/
│   │       ├── agent-teams-pattern.md
│   │       └── report-format.md
│   ├── plan/
│   │   ├── SKILL.md         # 行動計画スキル
│   │   └── references/
│   │       └── plan-format.md
│   └── docs-html/
│       ├── SKILL.md         # HTML ドキュメント生成スキル
│       ├── references/
│       │   ├── categories.md
│       │   ├── html-templates.md
│       │   ├── theme-toggle.md
│       │   └── i18n-toggle.md
│       └── examples/
│           └── base-template.html
└── README.md
```

## 技術仕様

| 項目       | 内容                                                                                                                                        |
| ---------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| **ツール** | Bash, Read, Edit, Write, Glob, Grep, Task, WebFetch, AskUserQuestion, TaskCreate, TaskUpdate, TaskList, TeamCreate, TeamDelete, SendMessage |
| **言語**   | 日本語 (コメント追加は既存コードのコメント言語に準拠)                                                                                       |
