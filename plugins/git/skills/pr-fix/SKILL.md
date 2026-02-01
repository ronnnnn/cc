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
  - Task
  - TaskCreate
  - TaskUpdate
  - TaskList
---

# PR レビュー修正ワークフロー

PR のレビューコメントを確認し、必要な修正を行う。

## 重要な原則

1. **未解決 (unresolved) のコメントのみを対象とする**
2. **レビューの妥当性を判断し、修正が必要なもののみ修正する**
3. **コミット前に必ずユーザーの承認を取る** - 自動でコミットしない
4. **返信コメント前に必ずユーザーの承認を取る** - 自動で返信を投稿しない
5. **コミットメッセージは commit-proposer subagent で Conventional Commits / commitlint 設定に準拠して生成する**
6. **コミットメッセージ・返信コメントの言語は対象リポジトリに従う** - 既存の PR やコミット履歴を確認し、リポジトリで使用されている言語 (日本語/英語等) に合わせる
7. **日本語でコミットメッセージ・返信コメントを書く場合は `japanese-text-style` スキルに従う** - スペース、句読点、括弧のルールを適用する
8. **修正は最小限に留める** - レビュー指摘以外の変更は含めない
9. **返信は丁寧かつ簡潔に**

## 作業開始前の準備

**必須:** 作業開始前に TaskCreate ツールで以下のステップをタスクとして登録する:

```
TaskCreate({ subject: "PR の特定", description: "引数または現在のブランチから PR を特定", activeForm: "PR を特定中" })
TaskCreate({ subject: "未解決のレビューコメントを取得", description: "GraphQL で isResolved: false のスレッドを取得", activeForm: "レビューコメントを取得中" })
TaskCreate({ subject: "レビューコメントの分析", description: "各コメントの妥当性を判断", activeForm: "レビューコメントを分析中" })
TaskCreate({ subject: "修正計画の提示", description: "ユーザーに修正計画の承認を求める", activeForm: "修正計画を提示中" })
TaskCreate({ subject: "コード修正の実行", description: "承認された修正を適用", activeForm: "コードを修正中" })
TaskCreate({ subject: "変更のステージング", description: "修正したファイルを git add でステージング", activeForm: "変更をステージング中" })
TaskCreate({ subject: "コミットメッセージの生成", description: "commit-proposer subagent でメッセージ候補を生成", activeForm: "コミットメッセージを生成中" })
TaskCreate({ subject: "コミット前の承認確認", description: "ユーザーにコミットの承認を求める", activeForm: "コミット承認を確認中" })
TaskCreate({ subject: "コミットの実行", description: "承認されたメッセージでコミット", activeForm: "コミットを実行中" })
TaskCreate({ subject: "プッシュの実行", description: "git push でリモートに反映", activeForm: "プッシュを実行中" })
TaskCreate({ subject: "返信コメントの作成", description: "各レビューコメントへの返信を作成", activeForm: "返信コメントを作成中" })
TaskCreate({ subject: "返信・resolve の承認確認", description: "ユーザーに返信と resolve の承認を求める", activeForm: "返信・resolve の承認を確認中" })
TaskCreate({ subject: "返信の投稿・スレッド resolve", description: "返信投稿とスレッド resolve を実行", activeForm: "返信投稿・スレッド resolve 中" })
TaskCreate({ subject: "完了報告", description: "修正結果を報告", activeForm: "完了報告を作成中" })
```

各ステップの開始時に TaskUpdate で `in_progress` に、完了時に `completed` に更新する。

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
# 注意: id (スレッド resolve 用) と databaseId (リアクション API 用) の両方を取得する
gh api graphql -f query='
query($owner: String!, $repo: String!, $number: Int!) {
  repository(owner: $owner, name: $repo) {
    pullRequest(number: $number) {
      reviewThreads(first: 100) {
        nodes {
          id
          isResolved
          comments(first: 10) {
            nodes {
              databaseId
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

### 6. 変更のステージング

修正したファイルをステージングする:

```bash
git add -A
```

### 7. コミットメッセージの生成

**commit-proposer subagent を Task ツールで呼び出す。**

```
Task({
  subagent_type: "git:commit-proposer",
  description: "コミットメッセージ候補の生成",
  prompt: "ステージング済みの変更に対してコミットメッセージ候補を提案してください。コンテキスト: レビュー指摘に基づく修正です。"
})
```

subagent が変更差分の分析、commitlint 設定の確認、メッセージ候補の生成を実行する。

### 8. コミット前の承認確認

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

### 9. コミットの実行

承認後、コミットを実行:

```bash
git commit -m "<type>(<scope>): レビュー指摘に基づく修正

- [修正内容 1]
- [修正内容 2]"
```

### 10. プッシュの実行

コミット完了後、リモートにプッシュ:

```bash
git push
```

### 11. 返信コメントの作成

各レビューコメントへの返信を作成する。

**返信テンプレート:**

| 対応タイプ     | 返信例                                                                        |
| -------------- | ----------------------------------------------------------------------------- |
| 修正完了       | `修正しました。ご指摘ありがとうございます。`                                  |
| 議論結果で修正 | `ご指摘の通り修正しました。[補足説明]`                                        |
| 対応しない     | `[理由] のため、現状のままとさせてください。ご意見があればお知らせください。` |

### 12. 返信・resolve の承認確認

**必須:** 返信内容と resolve 対象をユーザーに提示し、承認を求める:

```
## 返信コメントと resolve の確認

以下の返信を投稿し、スレッドを resolve します:

### 1. [path/to/file.ts:42] への返信 ✅ resolve 予定
> 元のコメント: ...

**返信:** 修正しました。ご指摘ありがとうございます。

### 2. [path/to/file.ts:100] への返信 ✅ resolve 予定
> 元のコメント: ...

**返信:** [理由] のため、現状のままとさせてください。

---

**resolve 対象:** N 件 (修正: X 件、対応不要: Y 件)

これらの返信を投稿し、スレッドを resolve してよろしいですか？
- resolve しない場合は「返信のみ」と回答してください
```

**resolve 対象の判定基準:**

| 対応タイプ             | resolve 対象 |
| ---------------------- | ------------ |
| 修正が完了したコメント | ✅           |
| 対応不要と判断         | ✅           |
| 議論継続中             | ❌           |

### 13. 返信の投稿・スレッド resolve

承認後、リアクション追加・返信投稿・スレッド resolve を実行する。

**返信は GraphQL mutation を使用する** (REST API はエンドポイントの URL 構造が複雑でエラーを起こしやすいため):

```bash
# 元のコメントに 👍 リアクションを追加 (REST API)
# databaseId はステップ 2 の GraphQL クエリで取得した値を使用
gh api repos/{owner}/{repo}/pulls/comments/<databaseId>/reactions \
  -f content="+1"

# レビュースレッドへの返信 (GraphQL mutation)
# thread_id はステップ 2 で取得した reviewThreads の id を使用
gh api graphql -f query='
mutation($threadId: ID!, $body: String!) {
  addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: $threadId, body: $body}) {
    comment {
      id
      body
    }
  }
}' -f threadId="<thread_id>" -f body="返信内容"
```

**ユーザーが resolve を承認した場合:**

```bash
# スレッドを resolve (GraphQL mutation)
gh api graphql -f query='
mutation($threadId: ID!) {
  resolveReviewThread(input: {threadId: $threadId}) {
    thread {
      isResolved
    }
  }
}' -f threadId="<thread_id>"
```

**処理順序:**

1. 元のコメントに 👍 リアクションを追加 (`databaseId` を使用)
2. スレッドに返信を投稿 (`id` (GraphQL node ID) を使用)
3. resolve を実行 (承認された場合のみ、`id` を使用)
4. エラーが発生した場合は続行し、完了報告で失敗したスレッドを報告

### 14. 完了報告

```
## 修正完了

- 修正コミット: <commit_hash>
- 修正ファイル数: N
- 返信済みコメント数: M
- resolve 済みスレッド数: K

PR URL: <url>
```

**resolve に失敗したスレッドがある場合:**

```
## 修正完了 (一部エラーあり)

- 修正コミット: <commit_hash>
- 修正ファイル数: N
- 返信済みコメント数: M
- resolve 済みスレッド数: K

**resolve 失敗:**
- [path/to/file.ts:42]: エラー内容

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
