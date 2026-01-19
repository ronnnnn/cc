---
name: pr-create
description: 現在のブランチから Draft Pull Request を作成する。テンプレート準拠、ラベル自動選択、CODEOWNERS からの Reviewer 設定を行う。
argument-hint: '[--base <branch>]'
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - TodoWrite
---

# PR 作成ワークフロー

現在のブランチから Draft Pull Request を作成する。

## 重要な原則

1. **PR タイトル・description の言語は対象リポジトリに従う** - 既存の PR やコミット履歴を確認し、リポジトリで使用されている言語 (日本語/英語等) に合わせる
2. **日本語で PR タイトル・description を書く場合は `japanese-text-style` スキルに従う** - スペース、句読点、括弧のルールを適用する
3. **PR は常に Draft として作成する**
4. **PR タイトルは commitlint 設定 / Conventional Commits に準拠する**
5. **PR テンプレートがある場合は必ず準拠する**
6. **ラベルはリポジトリに存在するもののみ使用する**
7. **Reviewer は CODEOWNERS に記載されているユーザーのみ設定する**

## 作業開始前の準備

**必須:** 作業開始前に TodoWrite ツールで以下のステップを TODO に登録する:

```
TodoWrite([
  { content: "事前確認 (ブランチ状態、リモート差分)", status: "pending", activeForm: "事前確認を実行中" },
  { content: "PR テンプレートの確認", status: "pending", activeForm: "PR テンプレートを確認中" },
  { content: "commitlint 設定の確認", status: "pending", activeForm: "commitlint 設定を確認中" },
  { content: "変更内容の分析", status: "pending", activeForm: "変更内容を分析中" },
  { content: "ラベルの選択", status: "pending", activeForm: "ラベルを選択中" },
  { content: "CODEOWNERS の確認", status: "pending", activeForm: "CODEOWNERS を確認中" },
  { content: "Draft PR 作成", status: "pending", activeForm: "Draft PR を作成中" },
  { content: "完了報告 (ブラウザで開く)", status: "pending", activeForm: "完了報告を作成中" }
])
```

各ステップの開始時に `in_progress` に、完了時に `completed` に更新する。

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

### 3. commitlint 設定の確認

**`conventional-commit` スキルを参照して、PR タイトルの形式を決定する。**

```bash
# commitlint 設定ファイルを探す
ls -la commitlint.config.{js,cjs,mjs,ts,cts} 2>/dev/null || \
ls -la .commitlintrc{,.json,.yaml,.yml,.js,.cjs,.mjs,.ts,.cts} 2>/dev/null || \
grep -l '"commitlint"' package.json 2>/dev/null
```

設定ファイルが見つかった場合:

**1. 継承先 (子) ファイルの探索:**

```bash
# 見つけた設定ファイルを継承している別のファイルがないか確認
ls -la commitlint.config.*.{js,cjs,mjs,ts,cts} 2>/dev/null
```

継承先ファイルが見つかった場合は、そちらを最終的な設定ファイルとして使用。

**2. 設定ファイルの解析:**

Read ツールで内容を確認し、以下を抽出:

- `type-enum`: 許可される type 一覧
- `scope-enum`: 許可される scope 一覧
- `scope-empty`: scope の必須/任意
- `extends`: 継承元設定 (継承チェーンを再帰的に解決)

詳細な解析方法は `conventional-commit` スキルを参照。

### 4. 変更内容の分析

```bash
# 変更されたファイル一覧
git diff origin/main..HEAD --name-only

# 変更の統計
git diff origin/main..HEAD --stat

# コミットメッセージ一覧
git log origin/main..HEAD --pretty=format:"%s"
```

変更内容を分析し、以下を決定する:

- PR タイトル (commitlint 設定に準拠した形式)
- PR 説明 (テンプレートに準拠)
- 適切なラベル

**タイトル決定の優先順位:**

1. commitlint 設定の `type-enum`, `scope-enum` に準拠
2. 設定がない場合は Conventional Commits のデフォルト type を使用
3. scope は変更されたディレクトリ/モジュールから推測

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
