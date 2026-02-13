---
name: pr-create
description: 現在のブランチから Draft Pull Request を作成する。テンプレート準拠、ラベル自動選択、CODEOWNERS からの Reviewer 設定を行う。
argument-hint: '[--base <branch>]'
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Skill
  - Task
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# PR 作成ワークフロー

現在のブランチから Draft Pull Request を作成する。

## 重要な原則

1. **PR タイトル・description の言語は対象リポジトリに従う** - 既存の PR やコミット履歴を確認し、リポジトリで使用されている言語 (日本語/英語等) に合わせる
2. **日本語で PR タイトル・description を書く場合は `japanese-text-style` スキルに従う** - スペース、句読点、括弧のルールを適用する
3. **PR は常に Draft として作成する**
4. **PR タイトルは Conventional Commits に準拠する** - コミットが 1 つの場合はそのメッセージをそのまま使用し、2 つ以上の場合は commit-proposer subagent で生成する
5. **PR テンプレートがある場合は必ず準拠する**
6. **ラベルはリポジトリに存在するもののみ使用する**
7. **Reviewer は CODEOWNERS に記載されているユーザーのみ設定する**

## 作業開始前の準備

**必須:** 作業開始前に TaskList で残存タスクを確認し、存在する場合は全て TaskUpdate({ status: "deleted" }) で削除する。その後、TaskCreate ツールで以下のステップをタスクとして登録する:

```
TaskCreate({ subject: "事前確認", description: "ブランチ状態、リモート差分を確認", activeForm: "事前確認を実行中" })
TaskCreate({ subject: "未コミット変更のコミット", description: "unstaged/staged の変更がある場合のみ commit スキルを実行", activeForm: "未コミット変更をコミット中" })
TaskCreate({ subject: "PR テンプレートの確認", description: "PULL_REQUEST_TEMPLATE.md を探索・読み込み", activeForm: "PR テンプレートを確認中" })
TaskCreate({ subject: "PR タイトルの生成", description: "コミットが 1 つならそのメッセージを使用、2 つ以上なら commit-proposer subagent で生成", activeForm: "PR タイトルを生成中" })
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

# ベースブランチを確認 (引数で指定されていない場合は main または master)
git remote show origin | grep 'HEAD branch'

# リモートとの差分を確認 (<base> は確認したベースブランチに置き換える)
git log origin/<base>..HEAD --oneline
```

**確認事項:**

- 未コミットの変更があるか (次のステップで対応)
- リモートにプッシュ済みであること
- ベースブランチとの差分があること

未プッシュの場合は `git push -u origin <branch>` を実行する。

### 2. 未コミット変更のコミット

`git status` の結果から unstaged または staged の変更がある場合のみ実行する。変更がない場合はこのステップをスキップする。

**変更がある場合:** commit スキルを Skill ツールで呼び出す。

```
Skill({ skill: "commit" })
```

commit スキルがステージング、コミットメッセージ生成、ユーザー承認、コミット実行を行う。

コミット完了後、未プッシュであれば `git push -u origin <branch>` を実行する。

### 3. PR テンプレートの確認

```bash
# テンプレートファイルを探す
ls -la .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null || \
ls -la .github/PULL_REQUEST_TEMPLATE/ 2>/dev/null || \
ls -la docs/PULL_REQUEST_TEMPLATE.md 2>/dev/null
```

テンプレートが存在する場合は Read ツールで内容を確認し、そのフォーマットに準拠した description を作成する。

### 4. PR タイトルの生成

`git log origin/<base>..HEAD --oneline` を実行し、コミット数を確認する (ステップ 2 で新規コミットが追加された可能性があるため、必ずここで再取得する)。

**コミットが 1 つの場合:** `git log -1 --format='%s'` で subject のみ取得し、そのまま PR タイトルとして使用する。commit-proposer subagent の呼び出しはスキップする。

**コミットが 2 つ以上の場合:** commit-proposer subagent を Task ツールで呼び出す。

```
Task({
  subagent_type: "git:commit-proposer",
  description: "PR タイトル候補の生成",
  prompt: "PR のコミット履歴から PR タイトル候補を提案してください。ベースブランチ: <base>。PR タイトルとして Conventional Commits 形式で提案してください。"
})
```

subagent がコミット履歴の分析、commitlint 設定の確認、PR タイトル候補の生成を実行する。

### 5. ラベルの選択

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

### 6. CODEOWNERS の確認

```bash
# CODEOWNERS ファイルを探す
cat .github/CODEOWNERS 2>/dev/null || \
cat CODEOWNERS 2>/dev/null || \
cat docs/CODEOWNERS 2>/dev/null
```

CODEOWNERS が存在する場合:

1. 変更されたファイルのパスを確認
2. 該当するオーナーを Reviewer として設定

### 7. Draft PR 作成

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

### 8. 完了報告

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
