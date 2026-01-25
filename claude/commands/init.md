---
name: init
description: CLAUDE.md を新規作成。プロジェクト分析、テンプレート生成、ユーザー承認後に書き込み。
allowed-tools:
  - Read
  - Write
  - Glob
  - Grep
  - Bash
  - TaskCreate
  - TaskUpdate
  - TaskList
  - AskUserQuestion
argument-hint: [path]
---

# CLAUDE.md 作成ワークフロー

プロジェクト構造を分析し、CLAUDE.md ファイルを新規作成する。

## 重要な原則

1. **プロジェクト固有の情報のみ記載** - Claude が既知の一般的なベストプラクティスは含めない
2. **簡潔さ優先** - コンテキストウィンドウを消費するため、必要最小限の情報のみ
3. **必須セクションを含める** - 日本語スタイリング、コード参照、技術調査優先順位
4. **ユーザー承認を得てから書き込む**

## 作業開始前の準備

**必須:** 作業開始前に TaskCreate ツールで以下のステップをタスクとして登録する:

```
TaskCreate({ subject: "プロジェクト構造の分析", description: "パッケージマネージャー/ビルドツールを検出", activeForm: "プロジェクト構造を分析中" })
TaskCreate({ subject: "技術スタックの検出", description: "設定ファイルからスタックを検出", activeForm: "技術スタックを検出中" })
TaskCreate({ subject: "既存 CLAUDE.md の確認", description: "既存ファイルの有無を確認", activeForm: "既存 CLAUDE.md を確認中" })
TaskCreate({ subject: "テンプレート生成", description: "必須セクションを含むテンプレートを生成", activeForm: "テンプレートを生成中" })
TaskCreate({ subject: "ユーザー承認", description: "生成内容の承認を求める", activeForm: "ユーザー承認を確認中" })
TaskCreate({ subject: "ファイル書き込み", description: "承認後に CLAUDE.md を作成", activeForm: "ファイルを書き込み中" })
TaskCreate({ subject: "完了報告", description: "作成結果を報告", activeForm: "完了報告を作成中" })
```

各ステップの開始時に TaskUpdate で `in_progress` に、完了時に `completed` に更新する。

## 実行手順

### 1. 作成場所の決定

- 引数が指定された場合: `$1/CLAUDE.md`
- 引数がない場合: 現在のディレクトリの `CLAUDE.md`

### 2. プロジェクト構造の分析

```bash
# パッケージマネージャー/ビルドツールを検出
ls -la package.json Cargo.toml go.mod pyproject.toml Makefile justfile 2>/dev/null
```

### 3. 技術スタックの検出

- `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml` 等からスタックを検出
- `Makefile`, `justfile`, `package.json scripts` からコマンドを抽出
- ディレクトリ構造を把握

### 4. 既存 CLAUDE.md の確認

```bash
# 既存ファイルを確認
ls -la CLAUDE.md 2>/dev/null
```

既存ファイルがある場合は確認後マージ。

### 5. テンプレート生成

以下のセクションを必須で含める:

```markdown
# [プロジェクト名]

[1-2 文のプロジェクト概要]

## コマンド

[検出したコマンド一覧]

## 日本語使用時のスタイリング

ドキュメントやコードコメントなど、特に指示がない限りは下記を厳守します。

- 技術用語や固有名詞は原文を維持
- スペース: 日本語と半角英数字記号間に半角スペース
- 文体: ですます調、句読点は「。」「、」
  - 箇条書きリストやチェックリストはこの限りではない
- 記号: 丸括弧は半角「()」、鉤括弧は全角「「」」

例:

- Terraform は、素晴らしい IaC (Infrastructure as Code) ツールです。
- Claude Code は、Anthropic 社が開発しているエージェント型 AI コーディングツールです。

## コード参照

参照元・参照先の調査は Grep ではなく LSP を使用 (goToDefinition, findReferences, incomingCalls, outgoingCalls)

## 技術調査

優先順位: LSP → deepwiki MCP → context7 MCP → WebSearch
```

### 6. 最適化

- Claude が既知の一般的な内容は含めない
- 目標: 500-1,500 words

### 7. ユーザー承認

生成した内容を表示し、AskUserQuestion で承認を得る。

### 8. ファイル書き込み

承認後、Write ツールで CLAUDE.md を作成。

### 9. 完了報告

```
## CLAUDE.md 作成完了

- **ファイル:** <path>
- **文字数:** X words
- **セクション数:** N
```

## エラーハンドリング

### 既存ファイルがある場合

1. 既存内容を読み込み
2. マージ方法をユーザーに確認
3. 承認後に上書き or マージ
