---
description: CLAUDE.md を新規作成
allowed-tools: Read, Write, Glob, Grep, Bash(ls:*, cat:*, head:*)
argument-hint: [path]
---

CLAUDE.md ファイルを作成する。

## 作成場所

- 引数が指定された場合: `$1/CLAUDE.md`
- 引数がない場合: 現在のディレクトリの `CLAUDE.md`

## 作成プロセス

1. **プロジェクト分析**
   - `package.json`, `Cargo.toml`, `go.mod`, `pyproject.toml` 等からスタックを検出
   - `Makefile`, `justfile`, `package.json scripts` からコマンドを抽出
   - ディレクトリ構造を把握

2. **既存 CLAUDE.md 確認**
   - 既存ファイルがある場合は確認後マージ

3. **テンプレート生成**
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

4. **最適化**
   - Claude が既知の一般的な内容は含めない
   - 目標: 500-1,500 words

5. **ユーザー確認**
   生成した内容を表示し、承認を得てから書き込む
