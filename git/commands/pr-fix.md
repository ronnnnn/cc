---
name: pr-fix
description: PR のレビューコメントに基づいて修正を行う。未解決のコメントのみを対象とし、妥当性を判断して修正。コミット・返信前に必ずユーザー承認を取る。
argument-hint: '[<pr-number>]'
allowed-tools:
  - Bash
  - Read
  - Edit
  - Glob
  - Grep
  - Write
  - AskUserQuestion
  - TodoWrite
---

# PR レビュー修正ワークフロー

PR のレビューコメントを確認し、必要な修正を行う。

## 重要な原則

1. **未解決 (unresolved) のコメントのみを対象とする**
2. **レビューの妥当性を判断し、修正が必要なもののみ修正する**
3. **コミット前に必ずユーザーの承認を取る** - 自動でコミットしない
4. **返信コメント前に必ずユーザーの承認を取る** - 自動で返信を投稿しない
5. **コミットメッセージは Conventional Commits / commitlint 設定に準拠する**
6. **コミットメッセージ・返信コメントの言語は対象リポジトリに従う** - 既存の PR やコミット履歴を確認し、リポジトリで使用されている言語 (日本語/英語等) に合わせる
7. **修正は最小限に留める** - レビュー指摘以外の変更は含めない
8. **返信は丁寧かつ簡潔に**

## 作業開始前の準備

**必須:** 作業開始前に TodoWrite ツールで以下のステップを TODO に登録する:

```
TodoWrite([
  { content: "PR の特定", status: "pending", activeForm: "PR を特定中" },
  { content: "未解決のレビューコメントを取得", status: "pending", activeForm: "レビューコメントを取得中" },
  { content: "レビューコメントの分析", status: "pending", activeForm: "レビューコメントを分析中" },
  { content: "修正計画の提示 (ユーザー承認)", status: "pending", activeForm: "修正計画を提示中" },
  { content: "コード修正の実行", status: "pending", activeForm: "コードを修正中" },
  { content: "commitlint 設定の確認", status: "pending", activeForm: "commitlint 設定を確認中" },
  { content: "コミット前の承認確認", status: "pending", activeForm: "コミット承認を確認中" },
  { content: "コミットの実行", status: "pending", activeForm: "コミットを実行中" },
  { content: "プッシュの実行", status: "pending", activeForm: "プッシュを実行中" },
  { content: "返信コメントの作成", status: "pending", activeForm: "返信コメントを作成中" },
  { content: "返信コメント前の承認確認", status: "pending", activeForm: "返信承認を確認中" },
  { content: "返信の投稿", status: "pending", activeForm: "返信を投稿中" },
  { content: "完了報告", status: "pending", activeForm: "完了報告を作成中" }
])
```

各ステップの開始時に `in_progress` に、完了時に `completed` に更新する。

## 実行手順

### 1. PR の特定

引数で PR 番号が指定されていない場合、現在のブランチから PR を特定する:

```bash
# 現在のブランチに関連する PR を取得
gh pr list --head $(git branch --show-current) --json number,title,state --jq '.[0]'

# または現在のブランチの PR 番号を取得
gh pr view --json number --jq '.number'
```

### 2. 未解決のレビューコメントを取得

```bash
# PR のレビューコメント一覧を取得
gh api repos/{owner}/{repo}/pulls/<number>/comments \
  --jq '.[] | select(.in_reply_to_id == null) | {id, path, line, body, user: .user.login, created_at}'

# レビュースレッドの状態を確認 (GraphQL)
gh api graphql -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        nodes {
          isResolved
          comments(first: 10) {
            nodes {
              body
              path
              line
              author { login }
            }
          }
        }
      }
    }
  }
}' -f owner=<owner> -f repo=<repo> -F number=<number>
```

**注意:** `isResolved: false` のスレッドのみを対象とする。

### 3. レビューコメントの分析

各未解決コメントについて、以下を判断する:

| 判断カテゴリ   | 対応                   |
| -------------- | ---------------------- |
| **修正が必要** | コードを修正する       |
| **議論が必要** | ユーザーに確認を求める |
| **対応不要**   | 理由を説明して resolve |

**妥当性判断の基準:**

- コードの正確性に関する指摘 → 修正が必要
- セキュリティに関する指摘 → 修正が必要
- パフォーマンスに関する指摘 → 検討が必要
- スタイルや好みの問題 (`nits:`) → 対応は任意
- 誤解に基づく指摘 → 説明で対応

### 4. 修正計画の提示

分析結果をユーザーに提示する:

```
## レビューコメント分析結果

### 修正が必要なコメント (N 件)

1. **[path/to/file.ts:42]** @reviewer
   > コメント内容

   **対応:** [修正内容の説明]

2. ...

### 議論が必要なコメント (M 件)

1. **[path/to/file.ts:100]** @reviewer
   > コメント内容

   **判断:** [なぜ議論が必要か]

### 対応不要と判断したコメント (K 件)

1. **[path/to/file.ts:200]** @reviewer
   > コメント内容

   **理由:** [対応不要の理由]

---

この計画で修正を進めますか？
```

### 5. コード修正の実行

ユーザーの承認後、修正を実行する:

1. 対象ファイルを Read ツールで読み込む
2. Edit ツールで修正を適用
3. 修正内容を確認

```bash
# 修正後の差分を確認
git diff
```

### 6. commitlint 設定の確認

**`conventional-commit` スキルを参照して、コミットメッセージの形式を決定する。**

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
- `extends`: 継承元設定 (`@commitlint/config-conventional` 等)

詳細な解析方法は `conventional-commit` スキルを参照。

### 7. コミット前の承認確認

**必須:** 修正内容をユーザーに提示し、コミットの承認を求める。

**コミットメッセージは commitlint 設定 (または Conventional Commits) に準拠する:**

```
## コミット内容の確認

以下の変更をコミットします:

**変更ファイル:**
- path/to/file1.ts (+5, -3)
- path/to/file2.ts (+2, -1)

**コミットメッセージ:** (commitlint 設定: <設定ファイル or デフォルト>)
```

fix(<scope>): レビュー指摘に基づく修正

- [修正内容 1]
- [修正内容 2]

```

この内容でコミットしてよろしいですか？
```

**type の選択基準:**

- レビュー指摘でバグを修正 → `fix`
- レビュー指摘でリファクタリング → `refactor`
- レビュー指摘でスタイル修正 → `style`
- レビュー指摘でドキュメント修正 → `docs`

### 8. コミットの実行

承認後、コミットを実行:

```bash
git add -A
git commit -m "<type>(<scope>): レビュー指摘に基づく修正

- [修正内容 1]
- [修正内容 2]"
```

### 9. プッシュの実行

コミット完了後、リモートにプッシュ:

```bash
git push
```

### 10. 返信コメントの作成

各レビューコメントへの返信を作成する。

**返信テンプレート:**

| 対応タイプ     | 返信例                                                                        |
| -------------- | ----------------------------------------------------------------------------- |
| 修正完了       | `修正しました。ご指摘ありがとうございます。`                                  |
| 議論結果で修正 | `ご指摘の通り修正しました。[補足説明]`                                        |
| 対応しない     | `[理由] のため、現状のままとさせてください。ご意見があればお知らせください。` |

### 11. 返信コメント前の承認確認

**必須:** 返信内容をユーザーに提示し、承認を求める:

```
## 返信コメントの確認

以下の返信を投稿します:

### 1. [path/to/file.ts:42] への返信
> 元のコメント: ...

**返信:** 修正しました。ご指摘ありがとうございます。

### 2. [path/to/file.ts:100] への返信
> 元のコメント: ...

**返信:** [理由] のため、現状のままとさせてください。

---

これらの返信を投稿してよろしいですか？
```

### 12. 返信の投稿

承認後、返信を投稿:

```bash
# レビューコメントへの返信
gh api repos/{owner}/{repo}/pulls/<pr_number>/comments/<comment_id>/replies \
  -f body="返信内容"
```

### 13. 完了報告

```
## 修正完了

- 修正コミット: <commit_hash>
- 修正ファイル数: N
- 返信済みコメント数: M

PR URL: <url>
```

## エラーハンドリング

### gh CLI が使用できない場合

GitHub MCP ツールにフォールバック:

- `mcp__github__get_pull_request` で PR 情報取得
- `mcp__github__list_pull_request_comments` でコメント取得

### 未解決コメントがない場合

```
未解決のレビューコメントはありません。
```

### コンフリクトがある場合

```bash
git fetch origin
git rebase origin/main
# コンフリクト解決後
git push --force-with-lease
```
