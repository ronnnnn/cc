---
name: pr-create
description: 現在のブランチから Draft Pull Request を作成する。テンプレート準拠、ラベル自動選択、CODEOWNERS からの Reviewer 設定を行う。
argument-hint: '[--base <branch>]'
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Task
  - TaskCreate
  - TaskUpdate
  - TaskList
version: 0.1.0
---

# PR 作成ワークフロー

現在のブランチから Draft Pull Request を作成する。

## 重要な原則

1. **PR タイトル・description の言語は対象リポジトリに従う** - 既存の PR やコミット履歴を確認し、リポジトリで使用されている言語 (日本語/英語等) に合わせる
2. **日本語で PR タイトル・description を書く場合は `japanese-text-style` スキルに従う** - スペース、句読点、括弧のルールを適用する
3. **PR は常に Draft として作成する**
4. **PR タイトルは commit-proposer subagent で commitlint 設定 / Conventional Commits に準拠して生成する**
5. **PR テンプレートがある場合は必ず準拠する**
6. **ラベルはリポジトリに存在するもののみ使用する**
7. **Reviewer は CODEOWNERS に記載されているユーザーのみ設定する**

## 作業開始前の準備

**必須:** 作業開始前に TaskCreate ツールで以下のステップをタスクとして登録する:

```
TaskCreate({ subject: "事前確認", description: "ブランチ状態、リモート差分を確認", activeForm: "事前確認を実行中" })
TaskCreate({ subject: "PR テンプレートの確認", description: "PULL_REQUEST_TEMPLATE.md を探索・読み込み", activeForm: "PR テンプレートを確認中" })
TaskCreate({ subject: "PR タイトルの生成", description: "commit-proposer subagent で commitlint 設定を確認し PR タイトル候補を生成", activeForm: "PR タイトルを生成中" })
TaskCreate({ subject: "ラベルの選択", description: "リポジトリのラベル一覧から適切なものを選択", activeForm: "ラベルを選択中" })
TaskCreate({ subject: "CODEOWNERS の確認", description: "CODEOWNERS から Reviewer を特定", activeForm: "CODEOWNERS を確認中" })
TaskCreate({ subject: "Draft PR 作成", description: "gh pr create --draft で PR を作成", activeForm: "Draft PR を作成中" })
TaskCreate({ subject: "完了報告", description: "PR URL を報告し、ブラウザで開く", activeForm: "完了報告を作成中" })
```

各ステップの開始時に TaskUpdate で `in_progress` に、完了時に `completed` に更新する。

## 実行手順

### 1. 事前確認

以下を並列で確認する:

```bash
# 現在のブランチと状態を確認
git status
git branch --show-current

# リモートとの差分を確認
git log origin/main..HEAD --oneline

# ベースブランチを確認 (引数で指定されていない場合は main または master)
git remote show origin | grep 'HEAD branch'
```

**確認事項:**

- 未コミットの変更がないこと
- リモートにプッシュ済みであること
- ベースブランチとの差分があること

未プッシュの場合は `git push -u origin <branch>` を実行する。

### 2. PR テンプレートの確認

```bash
# テンプレートファイルを探す
ls -la .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null || \
ls -la .github/PULL_REQUEST_TEMPLATE/ 2>/dev/null || \
ls -la docs/PULL_REQUEST_TEMPLATE.md 2>/dev/null
```

テンプレートが存在する場合は Read ツールで内容を確認し、そのフォーマットに準拠した description を作成する。

### 3. PR タイトルの生成

**commit-proposer subagent を Task ツールで呼び出す。**

```
Task({
  subagent_type: "git:commit-proposer",
  description: "PR タイトル候補の生成",
  prompt: "PR のコミット履歴から PR タイトル候補を提案してください。ベースブランチ: <base>。PR タイトルとして Conventional Commits 形式で提案してください。"
})
```

subagent がコミット履歴の分析、commitlint 設定の確認、PR タイトル候補の生成を実行する。

### 4. ラベルの選択

```bash
# リポジトリのラベル一覧を取得
gh label list --json name,description
```

変更内容に基づいて適切なラベルを選択する:

| 変更タイプ       | 推奨ラベル               |
| ---------------- | ------------------------ |
| 新機能追加       | `enhancement`, `feature` |
| バグ修正         | `bug`, `fix`             |
| ドキュメント     | `documentation`, `docs`  |
| リファクタリング | `refactor`, `tech-debt`  |
| テスト追加       | `test`, `testing`        |
| 依存関係更新     | `dependencies`           |
| 破壊的変更       | `breaking-change`        |

存在しないラベルは使用しない。

### 5. CODEOWNERS の確認

```bash
# CODEOWNERS ファイルを探す
cat .github/CODEOWNERS 2>/dev/null || \
cat CODEOWNERS 2>/dev/null || \
cat docs/CODEOWNERS 2>/dev/null
```

CODEOWNERS が存在する場合:

1. 変更されたファイルのパスを確認
2. 該当するオーナーを Reviewer として設定

### 6. Draft PR 作成

Draft PR を作成する:

```bash
gh pr create \
  --draft \
  --title "<タイトル>" \
  --body "<説明>" \
  --base <ベースブランチ> \
  --label "<ラベル1>,<ラベル2>" \
  --assignee @me \
  --reviewer "<reviewer1>,<reviewer2>"
```

### 7. 完了報告

作成された PR の URL を報告し、ブラウザで開く:

```bash
# PR の URL を取得
gh pr view --json url --jq '.url'

# ブラウザで PR を開く
gh pr view --web
```

**報告フォーマット:**

```
## Draft PR 作成完了

- **PR:** #<number>
- **タイトル:** <タイトル>
- **URL:** <url>
- **状態:** Draft

ブラウザで PR を開きました。
```

## エラーハンドリング

### gh CLI が使用できない場合

GitHub MCP ツールにフォールバックする:

- `mcp__github__create_pull_request` で PR 作成 (draft: true)
- `mcp__github__list_labels` でラベル取得

### 認証エラー

```bash
gh auth status
gh auth login
```

### ブランチが存在しない

```bash
git push -u origin $(git branch --show-current)
```
