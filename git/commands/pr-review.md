---
name: pr-review
description: PR をレビューし、指摘箇所にコメントを投稿する。複数 AI (Claude/Codex/Gemini) で並列レビューし、結果を統合。
argument-hint: '[<pr-url> | <pr-number>]'
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Task
  - TodoWrite
  - AskUserQuestion
  - ToolSearch
---

# PR レビューワークフロー

PR の変更を複数の AI でレビューし、指摘箇所に PR コメントを投稿する。

## 重要な原則

1. **複数 AI で並列レビューする** - Claude, Codex MCP, Gemini MCP を同時に使用
2. **結果を統合・重複排除する** - 同じ指摘は 1 つにマージ
3. **有用な指摘のみコメントする** - Claude が最終判断
4. **インラインコメントを優先する** - ファイル・行番号が明確な場合
5. **コメント投稿前に必ずユーザー承認を取る**
6. **コメントの言語は対象リポジトリに従う** - 既存の PR やコメント履歴を確認
7. **日本語でコメントを書く場合は `japanese-text-style` スキルに従う**

## 作業開始前の準備

**必須:** 作業開始前に TodoWrite ツールで以下のステップを TODO に登録する:

```
TodoWrite([
  { content: "PR の特定", status: "pending", activeForm: "PR を特定中" },
  { content: "PR 差分の取得", status: "pending", activeForm: "PR 差分を取得中" },
  { content: "MCP 利用可能性の確認", status: "pending", activeForm: "MCP を確認中" },
  { content: "並列レビューの実行", status: "pending", activeForm: "並列レビューを実行中" },
  { content: "レビュー結果の統合", status: "pending", activeForm: "結果を統合中" },
  { content: "コメント案の作成", status: "pending", activeForm: "コメント案を作成中" },
  { content: "ユーザー承認の取得", status: "pending", activeForm: "承認を取得中" },
  { content: "コメントの投稿", status: "pending", activeForm: "コメントを投稿中" },
  { content: "完了報告", status: "pending", activeForm: "完了報告を作成中" }
])
```

各ステップの開始時に `in_progress` に、完了時に `completed` に更新する。

## 実行手順

### 1. PR の特定

引数で PR 番号/URL が指定されていない場合、現在のブランチから PR を特定する:

```bash
# 引数が URL の場合、PR 番号を抽出
echo "$ARGUMENTS" | grep -oE '[0-9]+$' || gh pr view --json number --jq '.number'
```

```bash
# PR 情報を取得
gh pr view <number> --json number,title,url,baseRefName,headRefName
```

### 2. PR 差分の取得

```bash
# PR の差分を取得
gh pr diff <number>

# 変更ファイル一覧
gh pr diff <number> --name-only
```

### 3. MCP 利用可能性の確認

ToolSearch tool で各 MCP の利用可能性を確認:

```
ToolSearch: select:mcp__codex__codex
ToolSearch: select:mcp__gemini__ask-gemini
```

利用可能な MCP をリストアップする。

### 4. 並列レビューの実行

**`code-review` スキルを参照して、各 AI へのレビュー依頼方法を確認する。**

Task tool で 3 つの sub agent を**並列に**起動する。各 sub agent は自分で差分を取得する。

```markdown
# Task 1: Claude レビュー

Task tool:
subagent_type: general-purpose
prompt: |
PR #<number> の変更をレビューしてください。

    手順:
    1. `gh pr diff <number>` で PR の差分を取得
    2. 差分をレビューし、バグ、セキュリティ問題、パフォーマンス問題を確認

    出力フォーマット:
    ## Issues Found
    1. **[SEVERITY: HIGH/MEDIUM/LOW]** [file:line] - 説明
       - 問題: ...
       - 推奨: ...

# Task 2: Codex レビュー (MCP 利用可能時)

Task tool:
subagent_type: general-purpose
prompt: |
Codex MCP を使用して PR をレビューしてください。

    手順:
    1. ToolSearch で mcp__codex__codex を選択
    2. codex ツールを実行:
       prompt: "/review <PR の URL>"
    3. Codex の結果を以下のフォーマットに変換して返す

    出力フォーマット:
    ## Issues Found
    1. **[SEVERITY: HIGH/MEDIUM/LOW]** [file:line] - 説明
       - 問題: ...
       - 推奨: ...

# Task 3: Gemini レビュー (MCP 利用可能時)

Task tool:
subagent_type: general-purpose
prompt: |
Gemini MCP を使用して PR をレビューしてください。

    手順:
    1. ToolSearch で mcp__gemini__ask-gemini を選択
    2. ask-gemini ツールを実行:
       prompt: "/bug <PR の URL>"
    3. Gemini の結果を以下のフォーマットに変換して返す

    出力フォーマット:
    ## Issues Found
    1. **[SEVERITY: HIGH/MEDIUM/LOW]** [file:line] - 説明
       - 問題: ...
       - 推奨: ...
```

**重要:** 3 つの Task を単一のメッセージ内で並列に呼び出すこと。

### 5. レビュー結果の統合

各 AI からの結果を統合する:

1. **重複排除**: 同じファイル・行への指摘はマージ
2. **severity 統一**: CRITICAL > HIGH > MEDIUM > LOW
3. **有用性判断**: 以下の指摘のみ採用
   - バグや論理エラー
   - セキュリティ脆弱性
   - 明らかなパフォーマンス問題
   - 重要な設計上の問題

**除外する指摘:**

- スタイルのみの指摘 (linter で対応すべき)
- 好みの問題
- 曖昧な指摘

### 6. コメント案の作成

統合結果から PR コメント案を作成する:

**インラインコメント** (ファイル・行番号が明確な場合):

```markdown
### コメント 1

- **ファイル:** src/api/users.ts
- **行:** 42
- **内容:** `user.id` が null の場合の処理が欠けています。null チェックを追加することを推奨します。
```

**一般コメント** (特定の行に紐付かない場合):

```markdown
### 一般コメント

- **内容:** エラーハンドリングが全体的に不足しています。try-catch ブロックの追加を検討してください。
```

### 7. ユーザー承認の取得

**必須:** コメント案をユーザーに提示し、投稿の承認を求める:

```markdown
## PR レビュー結果

**PR:** #<number> - <title>
**レビュー AI:** Claude, Codex, Gemini

### 投稿予定のコメント (N 件)

#### インラインコメント (X 件)

1. **[src/api/users.ts:42]**

   > `user.id` が null の場合の処理が欠けています。

2. ...

#### 一般コメント (Y 件)

1. エラーハンドリングが全体的に不足しています。

---

これらのコメントを PR に投稿してよろしいですか？

- 特定のコメントを除外する場合は番号を指定してください
```

### 8. コメントの投稿

承認後、GitHub API でコメントを投稿する:

**インラインコメント:**

```bash
# レビューコメントを作成
gh api repos/{owner}/{repo}/pulls/<number>/comments \
  -f body="コメント内容" \
  -f commit_id="<最新コミットSHA>" \
  -f path="src/api/users.ts" \
  -F line=42 \
  -f side="RIGHT"
```

**一般コメント:**

```bash
# PR コメントを作成
gh pr comment <number> --body "コメント内容"
```

### 9. 完了報告

```markdown
## PR レビュー完了

- **PR:** #<number> - <title>
- **レビュー AI:** Claude, Codex, Gemini
- **投稿コメント数:** N 件
  - インラインコメント: X 件
  - 一般コメント: Y 件

PR URL: <url>
```

## エラーハンドリング

### MCP が利用できない場合

Claude 単独でレビューを実行し、結果を報告する。

### gh CLI が使用できない場合

GitHub MCP ツールにフォールバック:

- `mcp__github__get_pull_request` で PR 情報取得
- `mcp__github__create_pull_request_review` でレビュー作成

### 差分が大きすぎる場合

まずは必ずコードベース全体で実施。
各 AI が処理できない場合、主要なファイルに絞ってレビューを行う:

```markdown
PR の差分が大きいため、主要な変更ファイルに絞ってレビューします。

重点レビュー対象:

- src/core/\*.ts (コア機能)
- src/api/\*.ts (API エンドポイント)
```
