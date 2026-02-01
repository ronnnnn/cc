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
  - TaskCreate
  - TaskUpdate
  - TaskList
  - AskUserQuestion
version: 0.1.0
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

**必須:** 作業開始前に TaskCreate ツールで以下のステップをタスクとして登録する:

```
TaskCreate({ subject: "PR の特定", description: "引数または現在のブランチから PR を特定", activeForm: "PR を特定中" })
TaskCreate({ subject: "PR 差分の取得", description: "gh pr diff で差分を取得", activeForm: "PR 差分を取得中" })
TaskCreate({ subject: "並列レビューの実行", description: "code-reviewer subagent で並列レビュー", activeForm: "並列レビューを実行中" })
TaskCreate({ subject: "コメント案の作成", description: "インラインコメントと一般コメントを作成", activeForm: "コメント案を作成中" })
TaskCreate({ subject: "ユーザー承認の取得", description: "コメント案の承認を求める", activeForm: "承認を取得中" })
TaskCreate({ subject: "コメントの投稿", description: "GitHub API でコメントを投稿", activeForm: "コメントを投稿中" })
TaskCreate({ subject: "完了報告", description: "レビュー結果を報告", activeForm: "完了報告を作成中" })
```

各ステップの開始時に TaskUpdate で `in_progress` に、完了時に `completed` に更新する。

## 実行手順

### 1. PR の特定

引数で PR 番号/URL が指定されていない場合、現在のブランチから PR を特定する:

```bash
# 引数が URL の場合、PR 番号を抽出
echo "$ARGUMENTS" | grep -oE '[0-9]+$' || gh pr view --json number --jq '.number'
```

```bash
# PR 情報を取得 (headRefOid はコメント投稿時に必要)
gh pr view <number> --json number,title,url,baseRefName,headRefName,headRefOid
```

### 2. PR 差分の取得

```bash
# PR の差分を取得
gh pr diff <number>

# 変更ファイル一覧
gh pr diff <number> --name-only
```

### 3. 並列レビューの実行

**code-reviewer subagent を Task ツールで呼び出す。**

**重要:** `run_in_background: true` を指定しないこと。バックグラウンド実行では MCP ツールが利用できないため、必ずフォアグラウンドで実行する。

```
Task({
  subagent_type: "git:code-reviewer",
  description: "PR の並列レビュー",
  prompt: "PR #<number> の差分をレビューしてください。PR URL: <url>。`gh pr diff <number>` で差分を取得し、Claude/Codex MCP/Gemini MCP で並列レビューを実行して結果を統合してください。"
})
```

subagent が以下を自動で実行する:

- MCP (Codex, Gemini) の利用可能性確認
- Claude 自身のレビュー + 利用可能な MCP に並列依頼
- 結果の統合・重複排除・severity 統一

subagent から返却された統合結果から、有用な指摘のみ採用する:

- バグや論理エラー
- セキュリティ脆弱性
- 明らかなパフォーマンス問題
- 重要な設計上の問題

**除外する指摘:**

- スタイルのみの指摘 (linter で対応すべき)
- 好みの問題
- 曖昧な指摘

### 4. コメント案の作成

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

### 5. ユーザー承認の取得

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

### 6. コメントの投稿

承認後、GitHub API でコメントを投稿する:

**インラインコメント:**

```bash
# レビューコメントを作成
# commit_id にはステップ 1 で取得した headRefOid を使用
gh api repos/{owner}/{repo}/pulls/<number>/comments \
  -f body="コメント内容" \
  -f commit_id="<headRefOid>" \
  -f path="src/api/users.ts" \
  -F line=42 \
  -f side="RIGHT"
```

**一般コメント:**

```bash
# PR コメントを作成
gh pr comment <number> --body "コメント内容"
```

### 7. 完了報告

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

### gh CLI が使用できない場合

`gh api` コマンドで GitHub API に直接アクセスする:

```bash
gh api repos/{owner}/{repo}/pulls/<number>
```
