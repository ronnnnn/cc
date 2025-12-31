---
name: pr-update
description: PR のタイトルと description を最新の状態に更新する。コミット履歴を確認し、古くなっていれば更新。テンプレートまたは既存フォーマットに準拠。
argument-hint: '[<pr-number>]'
allowed-tools:
  - Bash
  - Read
  - Glob
  - AskUserQuestion
  - TodoWrite
---

# PR Description 更新ワークフロー

PR の description をコミット履歴に基づいて最新の状態に更新する。

## 作業開始前の準備

**必須:** 作業開始前に TodoWrite ツールで以下のステップを TODO に登録する:

```
TodoWrite([
  { content: "PR の特定", status: "pending", activeForm: "PR を特定中" },
  { content: "現在の description を取得", status: "pending", activeForm: "description を取得中" },
  { content: "コミット履歴の確認", status: "pending", activeForm: "コミット履歴を確認中" },
  { content: "変更内容の分析", status: "pending", activeForm: "変更内容を分析中" },
  { content: "PR テンプレートの確認", status: "pending", activeForm: "テンプレートを確認中" },
  { content: "新しいタイトルと description の作成", status: "pending", activeForm: "タイトルと description を作成中" },
  { content: "更新内容の確認 (ユーザー承認)", status: "pending", activeForm: "更新内容を確認中" },
  { content: "PR の更新", status: "pending", activeForm: "PR を更新中" },
  { content: "完了報告", status: "pending", activeForm: "完了報告を作成中" }
])
```

各ステップの開始時に `in_progress` に、完了時に `completed` に更新する。

## 実行手順

### 1. PR の特定

引数で PR 番号が指定されていない場合、現在のブランチから PR を特定する:

```bash
# 現在のブランチに関連する PR を取得
gh pr view --json number,title,body,baseRefName,headRefName
```

### 2. 現在の description を取得

```bash
# PR の詳細を取得
gh pr view <number> --json title,body,commits,files,additions,deletions
```

### 3. コミット履歴の確認

```bash
# PR に含まれる全コミットを取得
gh pr view <number> --json commits --jq '.commits[] | "\(.oid[0:7]) \(.messageHeadline)"'

# または git log で詳細を確認
git log origin/<base>..HEAD --pretty=format:"%h %s%n%b" --reverse
```

### 4. 変更内容の分析

```bash
# 変更されたファイル一覧
gh pr view <number> --json files --jq '.files[].path'

# 変更の統計
gh pr diff <number> --stat
```

変更内容を分析し、以下を把握する:

- 追加された機能
- 修正されたバグ
- リファクタリング内容
- 破壊的変更の有無

### 5. PR テンプレートの確認

```bash
# テンプレートファイルを探す
ls -la .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null || \
ls -la .github/PULL_REQUEST_TEMPLATE/ 2>/dev/null
```

**フォーマット決定ルール:**

1. `.github/PULL_REQUEST_TEMPLATE.md` が存在する → テンプレートに準拠
2. テンプレートがない → 既存の description のフォーマットに準拠
3. description が空 → 標準フォーマットを使用

### 6. 新しいタイトルと description の作成

**タイトル:**

**`conventional-commit` スキルを参照して、タイトルの形式を決定する。**

```bash
# commitlint 設定ファイルを探す
ls -la commitlint.config.{js,cjs,mjs,ts,cts} 2>/dev/null || \
ls -la .commitlintrc{,.json,.yaml,.yml,.js,.cjs,.mjs,.ts,.cts} 2>/dev/null || \
grep -l '"commitlint"' package.json 2>/dev/null
```

設定ファイルが見つかった場合は Read ツールで内容を確認し、以下を抽出:

- `type-enum`: 許可される type 一覧
- `scope-enum`: 許可される scope 一覧
- `scope-empty`: scope の必須/任意

コミット履歴に基づいて、適切なタイトルを作成する:

- Conventional Commits 形式 (`feat:`, `fix:` 等)
- commitlint 設定があれば準拠

**description:**

**テンプレートに準拠する場合:**
テンプレートの各セクションをコミット履歴に基づいて埋める。

**既存フォーマットに準拠する場合:**
既存の description の構造を維持しながら、内容を更新する。

**標準フォーマット:**

```markdown
## 概要

[変更の簡潔な説明]

## 変更内容

- [変更点 1]
- [変更点 2]
- [変更点 3]

## 関連 Issue

- #[issue_number] (該当する場合)

## テスト

- [ ] 単体テスト
- [ ] 手動テスト

## スクリーンショット

(UI 変更がある場合)
```

### 7. 更新内容の確認

現在の内容と新しい内容の差分を提示し、ユーザー承認を求める:

```
## PR 更新内容

### タイトル

| 項目 | 内容 |
|------|------|
| 現在 | [現在のタイトル] |
| 更新後 | [新しいタイトル] |

### Description

**現在の description:**
```

[現在の内容]

```

**更新後の description:**
```

[新しい内容]

```

**変更点:**
- [追加された内容]
- [変更された内容]
- [削除された内容]

---

この内容で PR を更新しますか？
```

### 8. PR の更新

ユーザーの承認後、タイトルと description を更新:

```bash
# タイトルと description を同時に更新
gh pr edit <number> \
  --title "新しいタイトル" \
  --body "$(cat <<'EOF'
[新しい description の内容]
EOF
)"
```

### 9. 完了報告

```
## 更新完了

- PR: #<number>
- タイトル: [タイトル]
- description: 更新済み

PR URL: <url>
```

## 更新判断の基準

### 更新が必要なケース

- 初期説明から大幅に変更が加わった
- レビュー後に修正コミットが追加された
- 関連 Issue が追加/変更された
- テスト方法が変更された

### 更新が不要なケース

- description が既に最新のコミット内容を反映している
- 軽微な修正のみで説明に影響がない

## エラーハンドリング

### gh CLI が使用できない場合

GitHub MCP ツールにフォールバック:

- `mcp__github__get_pull_request` で PR 情報取得
- `mcp__github__update_pull_request` で PR 更新

### PR が見つからない場合

```
指定されたブランチに関連する PR が見つかりません。
PR 番号を指定して再実行してください: /github:pr-update <number>
```

## 注意事項

- 既存の description のフォーマットを尊重する
- ユーザーが手動で追加した情報は保持する
- 自動生成であることを示す記述は追加しない
- コミットメッセージをそのままコピーするのではなく、要約・整理する
