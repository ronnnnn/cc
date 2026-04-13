---
name: pr-watch
description: PR のレビューコメントと CI 失敗を Monitor ツールでイベント駆動監視し、ユーザー確認なしで自動で修正・コミット・プッシュ・返信を行う。pr-fix と pr-ci を統合し自律実行する。最大 30 分 (活動検出時は最大 60 分)。Use when PR の監視、自動修正、ウォッチを求められた際に使用する。
argument-hint: '[<pr-number>]'
allowed-tools:
  - Bash
  - Read
  - Edit
  - Glob
  - Grep
  - Write
  - Monitor
  - Task
  - TaskCreate
  - TaskUpdate
  - TaskList
  - TaskStop
---

# PR 監視・自動修正ワークフロー

PR のレビューコメントと CI 失敗を Monitor ツールでバックグラウンド監視し、イベント検出次第自動で修正・コミット・プッシュ・返信を実行する。

## 重要な原則

1. **ユーザー確認は一切行わない** - 全ステップを自律的に実行する。修正ファイル数や変更規模に関わらず確認をスキップする
2. **レビュー修正を CI 修正より優先する** - 同時に検出した場合はレビューを先に処理する。レビュー修正のプッシュ後、CI 結果が更新されるのを待ってから CI 修正に取りかかる
3. **修正は最小限に留める** - レビュー指摘・CI エラーの修正に必要な変更のみ
4. **コミットメッセージは commit-proposer subagent で生成する** - Conventional Commits / commitlint 設定に準拠
5. **コミットメッセージ・返信コメントの言語は対象リポジトリに従う** - 既存の PR やコミット履歴を確認し、使用されている言語に合わせる
6. **日本語でコミットメッセージ・返信コメントを書く場合は `japanese-text-style` スキルに従う**
7. **対応不要と判断したレビューコメントは理由を返信して resolve する**
8. **コンフリクトを検出したら自動で解消して監視を継続する**
9. **修正で PR の実態が変わった場合のみ、タイトル・description を自動更新する** - 軽微な修正 (typo、lint、フォーマット) では更新しない。テンプレートや既存フォーマットを維持する

## 監視パラメータ

| パラメータ     | 値                                                                              |
| -------------- | ------------------------------------------------------------------------------- |
| Monitor 方式   | バックグラウンドスクリプト (`persistent: true`)                                 |
| ポーリング間隔 | 60 秒                                                                           |
| アイドル上限   | 30 分 (レビュー/CI 失敗/コンフリクト等の活動が一度も検出されなかった場合に終了) |
| 絶対上限       | 60 分 (活動有無に関わらず強制終了)                                              |
| 即時終了条件   | PR クローズ/マージ済み                                                          |

## イベント一覧

Monitor スクリプトが stdout に出力するイベント。各行が 1 イベント。

| イベント                               | 意味                                                      | 対応                        |
| -------------------------------------- | --------------------------------------------------------- | --------------------------- |
| `NEW_REVIEWS\|thread_id1,thread_id2`   | 新しい未解決レビュースレッドを検出                        | レビュー修正を実行 (3a)     |
| `CI_FAIL\|run_id1:name1,run_id2:name2` | CI 失敗を検出 (全 run 完了後)                             | CI 修正を実行 (3b)          |
| `PR_MERGED`                            | PR がマージされた                                         | 監視終了 → 完了報告 (4)     |
| `PR_CLOSED`                            | PR がクローズされた                                       | 監視終了 → 完了報告 (4)     |
| `PR_CONFLICT`                          | コンフリクトが発生した                                    | コンフリクト解消を実行 (3d) |
| `TIMEOUT_IDLE\|Xmin`                   | アイドルタイムアウト (30 分)                              | 監視終了 → 完了報告 (4)     |
| `TIMEOUT_ABS\|Xmin`                    | 絶対タイムアウト (60 分) または API エラー 3 サイクル連続 | 監視終了 → 完了報告 (4)     |

## 状態管理

イベント対応全体で以下の状態を管理する:

- `PR_NUMBER`: PR 番号
- `OWNER`, `REPO`: リポジトリ情報
- `MY_LOGIN`: 自分の GitHub ユーザー名 (`gh api user --jq '.login'` で取得、自分のコメントを除外するため)
- `MONITOR_ID`: Monitor のタスク ID (TaskStop で終了するため)
- `UNFIXABLE_RUNS`: 修正不可能と判断した CI run ID のリスト (以降のイベントで同じ失敗の再処理をスキップする)
- `REVIEW_COMMITS`: レビュー修正コミット数
- `CI_COMMITS`: CI 修正コミット数
- `REPLIED_COMMENTS`: 返信済みコメント数
- `RESOLVED_THREADS`: resolve 済みスレッド数
- `PR_UPDATES`: PR タイトル・description の更新回数
- `CONFLICT_RESOLVES`: コンフリクト解消回数
- `RE_REQUESTED_REVIEWERS`: レビュー再リクエスト済みユーザーのリスト

## 作業開始前の準備

**必須:** 作業開始前に TaskList で残存タスクを確認し、存在する場合は全て TaskUpdate({ status: "deleted" }) で削除する。その後、TaskCreate ツールで以下のタスクを登録する:

```
TaskCreate({ subject: "PR の特定", description: "引数または現在のブランチから PR を特定", activeForm: "PR を特定中" })
TaskCreate({ subject: "Monitor セットアップ", description: "バックグラウンド監視スクリプトを起動", activeForm: "Monitor をセットアップ中" })
TaskCreate({ subject: "イベント対応", description: "Monitor からのイベントに応じて修正・返信を実行", activeForm: "PR を監視中" })
TaskCreate({ subject: "監視終了・完了報告", description: "監視結果を集計して報告", activeForm: "完了報告を作成中" })
```

各ステップの開始時に TaskUpdate で `in_progress` に、完了時に `completed` に更新する。

## 実行手順

### 1. PR の特定

引数で PR 番号が指定されていない場合、現在のブランチから PR を特定する:

```bash
gh pr view --json number,title,headRefName,state --jq '{number, title, headRefName, state}'
```

- PR が `MERGED` または `CLOSED` の場合は監視を開始せず終了する
- PR が見つからない場合は「現在のブランチに紐づく PR が見つかりません。PR 番号を指定して再実行してください。」と報告して終了する

状態変数を初期化する。初期化時に `MY_LOGIN=$(gh api user --jq '.login')` で自分の GitHub ユーザー名を取得する。

### 2. Monitor セットアップ

以下の要件でバックグラウンド監視スクリプトを作成し、Monitor ツールで起動する。

**スクリプトの要件:**

1. 60 秒間隔で PR 状態・レビュースレッド・CI ステータスをチェックする
2. 状態変化を検出した場合のみ stdout にイベントを出力する (変化がなければ何も出力しない)
3. 終了条件 (マージ/クローズ/タイムアウト) を満たしたら対応イベントを出力して exit する。コンフリクト検出時はイベントを出力するが exit しない (監視を継続する)
4. API エラー時はスキップして次のサイクルに進む (3 サイクル連続失敗で `TIMEOUT_ABS` を出力して exit)

**スクリプトテンプレート:**

`<OWNER>`, `<REPO>`, `<PR_NUMBER>`, `<MY_LOGIN>` はステップ 1 で取得した値で置き換える。

```bash
#!/bin/bash
set -uo pipefail

OWNER="<OWNER>"; REPO="<REPO>"; PR_NUMBER=<PR_NUMBER>; MY_LOGIN="<MY_LOGIN>"
START=$(date +%s)
IDLE_LIMIT=1800; ABS_LIMIT=3600
PREV_THREADS=""; PREV_FAILS=""; PREV_SHA=""
HAD_ACT=false; API_ERRORS=0; PREV_CONFLICT=false

while true; do
  NOW=$(date +%s); ELAPSED=$(( (NOW - START) / 60 ))

  # タイムアウト判定
  [ $((NOW - START)) -ge $ABS_LIMIT ] && echo "TIMEOUT_ABS|${ELAPSED}min" && exit 0
  [ "$HAD_ACT" = false ] && [ $((NOW - START)) -ge $IDLE_LIMIT ] && echo "TIMEOUT_IDLE|${ELAPSED}min" && exit 0

  API_FAIL=false

  # PR 状態チェック
  PRI=$(gh pr view "$PR_NUMBER" -R "$OWNER/$REPO" --json state,mergeable,headRefOid 2>/dev/null) || API_FAIL=true

  if [ "$API_FAIL" = false ]; then
    ST=$(echo "$PRI" | jq -r '.state')
    MG=$(echo "$PRI" | jq -r '.mergeable')
    SHA=$(echo "$PRI" | jq -r '.headRefOid')

    [ "$ST" = "MERGED" ] && echo "PR_MERGED" && exit 0
    [ "$ST" = "CLOSED" ] && echo "PR_CLOSED" && exit 0
    if [ "$MG" = "CONFLICTING" ]; then
      [ "$PREV_CONFLICT" = false ] && echo "PR_CONFLICT" && HAD_ACT=true
      PREV_CONFLICT=true
    else
      PREV_CONFLICT=false
    fi

    # 新コミット検出時: CI 失敗トラッキングをリセット
    if [ "$SHA" != "$PREV_SHA" ]; then
      PREV_SHA="$SHA"
      PREV_FAILS=""
    fi

    # 未解決レビュースレッド取得
    TJ=$(gh api graphql -f query='
      query {
        repository(owner: "'"$OWNER"'", name: "'"$REPO"'") {
          pullRequest(number: '"$PR_NUMBER"') {
            reviewThreads(first: 100) {
              nodes {
                id
                isResolved
                comments(first: 100) {
                  totalCount
                  nodes { author { login } }
                }
              }
            }
          }
        }
      }' 2>/dev/null) || API_FAIL=true

    if [ "$API_FAIL" = false ]; then
      # フィルタ: 未解決 かつ 自分以外のコメント (スレッド ID + コメント数で変化を検出)
      CT=$(echo "$TJ" | jq -r --arg m "$MY_LOGIN" \
        '[.data.repository.pullRequest.reviewThreads.nodes[]
          | select(.isResolved == false)
          | select(.comments.nodes[0].author.login != $m)
          | .id + ":" + (.comments.totalCount | tostring)] | sort | join(",")')

      # 新規または変化のあるスレッドを抽出 (PREV_THREADS に含まれないエントリ)
      # エントリは "thread_id:comment_count" 形式。コメント追加時も変化を検出する
      if [ -n "$CT" ]; then
        NEW_T=""
        IFS=',' read -ra CUR_ARR <<< "$CT"
        for entry in "${CUR_ARR[@]}"; do
          case ",$PREV_THREADS," in
            *",$entry,"*) ;; # 既知 (ID もコメント数も同一)
            *) tid="${entry%%:*}"; NEW_T="${NEW_T:+$NEW_T,}$tid" ;;
          esac
        done
        [ -n "$NEW_T" ] && echo "NEW_REVIEWS|$NEW_T" && HAD_ACT=true
      fi
      PREV_THREADS="$CT"
    fi

    # CI ステータスチェック
    if [ -n "$SHA" ]; then
      CI_API_OK=true
      RJ=$(gh run list --commit "$SHA" -R "$OWNER/$REPO" --json databaseId,status,conclusion,name -L 50 2>/dev/null) || CI_API_OK=false

      if [ "$CI_API_OK" = true ]; then
        # in_progress / queued があれば CI 確定待ち → スキップ
        IP=$(echo "$RJ" | jq '[.[] | select(.status == "in_progress" or .status == "queued")] | length')

        if [ "$IP" -eq 0 ] && [ "$(echo "$RJ" | jq 'length')" -gt 0 ]; then
          CF=$(echo "$RJ" | jq -r '[.[] | select(.conclusion == "failure") | "\(.databaseId):\(.name)"] | sort | join(",")')

          # 新しい失敗のみ検出 (PREV_FAILS に含まれない run のみ抽出)
          if [ -n "$CF" ]; then
            NEW_F=""
            IFS=',' read -ra CUR_FAIL_ARR <<< "$CF"
            IFS=',' read -ra PRV_FAIL_ARR <<< "$PREV_FAILS"
            for fid in "${CUR_FAIL_ARR[@]}"; do
              IS_KNOWN=false
              for pfid in "${PRV_FAIL_ARR[@]}"; do
                [ "$fid" = "$pfid" ] && IS_KNOWN=true && break
              done
              [ "$IS_KNOWN" = false ] && NEW_F="${NEW_F:+$NEW_F,}$fid"
            done
            [ -n "$NEW_F" ] && echo "CI_FAIL|$NEW_F" && HAD_ACT=true
          fi
          PREV_FAILS="$CF"
        fi
      else
        API_FAIL=true
      fi
    fi
  fi

  # サイクル単位の API エラー判定
  if [ "$API_FAIL" = true ]; then
    API_ERRORS=$((API_ERRORS + 1))
    [ $API_ERRORS -ge 3 ] && echo "TIMEOUT_ABS|${ELAPSED}min" && exit 0
  else
    API_ERRORS=0
  fi

  sleep 60
done
```

**Monitor 起動:**

```
Monitor({
  description: "PR #<PR_NUMBER> 監視",
  persistent: true,
  command: "bash /tmp/pr-monitor-<PR_NUMBER>.sh"
})
```

起動前にスクリプトを `/tmp/pr-monitor-<PR_NUMBER>.sh` に書き出す。Monitor が返すタスク ID を `MONITOR_ID` として保持する。

起動後、ユーザーに監視開始を報告する:

```
PR #<number> (<title>) の監視を開始しました。
60 秒間隔でレビューコメントと CI 失敗を監視します。
検出次第自動で修正・コミット・プッシュ・返信を行います。
```

### 3. イベント対応

Monitor からの通知を受信したら、以下のルールに従って対応する。

**優先順位:** 同一通知内に `NEW_REVIEWS` と `CI_FAIL` が含まれる場合、レビュー修正を先に処理する。

#### 3a. NEW_REVIEWS イベント

通知に含まれるスレッド ID を処理対象とする。重複排除は Monitor スクリプトの `PREV_THREADS` で行われるため、イベントハンドラ側での追加フィルタは不要。

**詳細取得:**

処理対象のスレッドについて、完全なコメント情報を取得する:

```bash
# <owner>, <repo>, <number> は実際の値に置き換える
gh api graphql -F query='
query {
  repository(owner: "<owner>", name: "<repo>") {
    pullRequest(number: <number>) {
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
}'
```

取得したスレッドのうち、処理対象の ID に一致するもののみ使用する。

**妥当性判断の基準:**

| 指摘の種類                       | 判断       | 対応                                       |
| -------------------------------- | ---------- | ------------------------------------------ |
| コードの正確性に関する指摘       | 修正が必要 | コードを修正                               |
| セキュリティに関する指摘         | 修正が必要 | コードを修正                               |
| パフォーマンスに関する指摘       | 修正が必要 | コードを修正                               |
| スタイルや好みの問題 (`nits:`)   | 内容次第   | コードを修正または、理由を返信して resolve |
| 誤解に基づく指摘                 | 対応不要   | 説明を返信して resolve                     |
| 既に別のコミットで対応済みの指摘 | 対応不要   | 対応済みの旨を返信して resolve             |

**ファクトチェック (必須):**

レビューの指摘を鵜呑みにせず、技術的な主張や根拠が正しいか検証する。特に以下のケースでは必ずファクトチェックを行う:

- 言語仕様・ランタイムの挙動に関する指摘
- フレームワーク・ライブラリの API や推奨パターンに関する指摘
- セキュリティに関する指摘
- パフォーマンスに関する指摘
- 「〜すべき」「〜は非推奨」など規範的な主張

**ファクトチェックのソース優先順位:**

| 優先度 | ソース       | 用途                                     |
| ------ | ------------ | ---------------------------------------- |
| 1      | LSP          | コードベース内の定義・参照・型情報の確認 |
| 2      | deepwiki MCP | OSS リポジトリの Wiki・ドキュメント      |
| 3      | Gemini MCP   | Google 検索による最新情報の取得          |
| 4      | context7 MCP | ライブラリの公式ドキュメントとコード例   |
| 5      | WebFetch     | 公式サイト・GitHub・特定 URL の確認      |
| 6      | WebSearch    | 最新情報・ブログ・リリースノートの検索   |

**例外 (上記の優先順位より優先):**

- terraform に関する内容は terraform MCP (`mcp__terraform__*`) が最優先
- Google Cloud に関する内容は google-developer-knowledge MCP (`mcp__google-developer-knowledge__*`) が最優先
- Claude Code に関する内容は claude-code-guide agent (`subagent_type: "claude-code-guide"`) が最優先

ファクトチェックの結果、指摘が誤りだった場合はその根拠をソース付きで返信コメントに記載する。

**処理フロー:**

1. 各未解決コメントの妥当性を上記基準で判断し、ファクトチェックで検証する
2. 修正が必要なコメントに対してコードを修正する
3. 修正したファイルをステージングする: `git add <修正ファイル>`
4. commit-proposer subagent でコミットメッセージを生成する:

   ```
   Task({
     subagent_type: "git:commit-proposer",
     description: "コミットメッセージ候補の生成",
     prompt: "ステージング済みの変更に対してコミットメッセージ候補を提案してください。コンテキスト: レビュー指摘に基づく修正です。subject には「レビュー指摘に基づく修正」のような汎用的な表現ではなく、実際に何を変更したかを具体的に記述してください。"
   })
   ```

   subagent がエラーを返した場合は、変更差分から Conventional Commits 形式のメッセージを自前で生成する。その際も subject には実際の変更内容を具体的に記述し、「レビュー指摘に基づく修正」のような汎用表現は使わない。

5. 推奨メッセージ (候補 1) でコミットする

   ```bash
   # <type>, <scope>, <subject>, <body> は commit-proposer の出力で置き換える
   git commit -m "$(cat <<'EOF'
   <type>(<scope>): <subject>

   <body>
   EOF
   )"
   ```

6. `git push` でリモートに反映する
7. 各コメントに返信・リアクション・resolve を実行する:

   ```bash
   # 元のコメントに +1 リアクション (databaseId 使用)
   gh api repos/{owner}/{repo}/pulls/comments/<databaseId>/reactions -f content="+1"

   # スレッドに返信 (GraphQL mutation、thread id 使用)
   # <thread_id>, <body> は実際の値に置き換える
   gh api graphql -F query='
   mutation {
     addPullRequestReviewThreadReply(input: {pullRequestReviewThreadId: "<thread_id>", body: "<body>"}) {
       comment { id body }
     }
   }'

   # スレッドを resolve
   # <thread_id> は実際の値に置き換える
   gh api graphql -F query='
   mutation {
     resolveReviewThread(input: {threadId: "<thread_id>"}) {
       thread { isResolved }
     }
   }'
   ```

**処理順序:** リアクション追加 → 返信投稿 → resolve。エラーが発生しても続行し、失敗を記録する。

**返信テンプレート:**

| 対応タイプ | 返信例                                        |
| ---------- | --------------------------------------------- |
| 修正完了   | `修正しました。ご指摘ありがとうございます。`  |
| 対応しない | `[理由] のため、現状のままとさせてください。` |
| 対応済み   | `[コミット hash] で対応済みです。`            |

**ソース参照ルール:**

理由を添えて返信する場合 (対応しない、内容次第で対応不要と判断した場合など)、信頼できるソースの情報を参照できるときはコメントにも記載する。

- 公式ドキュメント (言語仕様、フレームワーク公式ドキュメント等) の URL
- プロジェクト内の既存コード・設定ファイルのパスと行番号
- lint ルールやコーディング規約の該当セクション
- RFC やセキュリティアドバイザリ等の公的な技術文書

**例:**

```
Go の仕様上、nil map への読み取りはゼロ値を返すためパニックしません。
ref: https://go.dev/ref/spec#Index_expressions

現状のままとさせてください。
```

カウンタを更新: `REVIEW_COMMITS`, `REPLIED_COMMENTS`, `RESOLVED_THREADS`。

**レビュー再リクエスト:**

返信・resolve の完了後、対応したスレッドの投稿者に対してレビューの再リクエストを送信する。

1. 返信・resolve したスレッドの投稿者 (最初のコメントの `author.login`) を重複なしで収集する
2. PR のレビュー一覧を取得し、再リクエスト対象の判定に必要な情報 (ユーザー種別・レビュー状態) を収集する:

   ```bash
   gh api repos/{owner}/{repo}/pulls/<number>/reviews \
     --jq '[.[] | {login: .user.login, type: .user.type, state: .state}]'
   ```

3. 取得したレビュー情報をもとに、以下の条件で再リクエスト対象を判定する:

   | 条件                                                               | 再リクエスト |
   | ------------------------------------------------------------------ | ------------ |
   | `user.type` が `Bot` (bot アカウント)                              | スキップ     |
   | 同一ユーザーの最新レビューが `APPROVED`                            | スキップ     |
   | `RE_REQUESTED_REVIEWERS` に含まれる (同一監視内で再リクエスト済み) | スキップ     |
   | 上記に該当しない (人間のレビュワーで未 approve)                    | **送信**     |

   **approve 判定:** 同一ユーザーが複数回レビューしている場合、最新のレビュー状態で判断する。

4. 対象ユーザーがいる場合、再リクエストを送信する:

   ```bash
   gh api repos/{owner}/{repo}/pulls/<number>/requested_reviewers \
     -f "reviewers[]=<login1>" -f "reviewers[]=<login2>"
   ```

5. 送信成功したユーザーを `RE_REQUESTED_REVIEWERS` に追加する。エラーが発生しても続行し、失敗を記録する

#### 3b. CI_FAIL イベント

通知に含まれる `run_id:name` ペアから run ID (`:` の前) を抽出し、`UNFIXABLE_RUNS` に含まれないものを処理対象とする。

**処理フロー:**

1. ci-analyzer subagent で失敗原因を調査する:

   ```
   Task({
     subagent_type: "git:ci-analyzer",
     description: "CI 失敗原因の調査",
     prompt: "PR #<number> (ブランチ: <branch>) の CI 失敗を調査してください。"
   })
   ```

   subagent がエラーを返した場合は、直接 `gh run view <run-id> --log-failed` でログを取得して分析する。

2. 自動修正可能なエラーのみ修正する

   | エラー種別             | 自動修正 |
   | ---------------------- | -------- |
   | Lint/フォーマット      | 可能     |
   | 型エラー・ビルドエラー | 可能     |
   | テスト失敗             | 可能     |
   | 依存関係               | 可能     |
   | 環境変数・secret       | **不可** |
   | 権限・認証             | **不可** |

3. 修正不可能なエラーの run ID を `UNFIXABLE_RUNS` に追加し、以降のイベントで再処理をスキップする。完了報告で通知する
4. 修正したファイルをステージング: `git add <修正ファイル>`
5. commit-proposer subagent でコミットメッセージを生成する (エラー時は自前生成にフォールバック)
6. 推奨メッセージでコミットする
7. `git push` でリモートに反映する

カウンタを更新: `CI_COMMITS`。

#### 3c. 修正後の PR タイトル・description 更新判断

レビュー修正 (3a) または CI 修正 (3b) でコミットをプッシュした場合のみ実行する。コミットがなかった場合はスキップする。

**判断手順:**

1. PR の全 diff と現在のタイトル・description を取得する:

   ```bash
   gh pr view <number> --json title,body,commits,files,additions,deletions
   gh pr diff <number> --stat
   ```

2. 以下の基準で更新の要否を判断する:

   | 条件                                                       | 判断 |
   | ---------------------------------------------------------- | ---- |
   | 修正で PR の type/scope が変わった (例: `feat` → `fix`)    | 更新 |
   | description に記載の変更内容が実態と矛盾している           | 更新 |
   | 修正で新しい機能追加や破壊的変更が加わった                 | 更新 |
   | 軽微な修正のみ (typo、lint、フォーマット、変数名変更)      | 不要 |
   | description が元々空、または情報量が少なく更新の意味がない | 不要 |
   | 既に同じサイクルの修正内容を反映済み                       | 不要 |

3. 更新不要と判断した場合はスキップする

**更新処理:**

1. PR テンプレートを確認する:

   ```bash
   ls -la .github/PULL_REQUEST_TEMPLATE.md 2>/dev/null || \
   ls -la .github/PULL_REQUEST_TEMPLATE/ 2>/dev/null
   ```

   - テンプレートが存在する → テンプレートに準拠
   - テンプレートがない → 既存の description のフォーマットに準拠

2. コミット履歴に基づいてタイトルと description を作成する:

   ```bash
   git log origin/<base>..HEAD --pretty=format:"%h %s%n%b" --reverse
   ```

   - タイトルは Conventional Commits 形式。commitlint 設定があれば準拠する
   - description はコミットメッセージのコピーではなく、変更内容を要約・整理する
   - ユーザーが手動で追加した情報 (関連 Issue、スクリーンショット等) は保持する

3. 更新を実行する:

   ```bash
   gh pr edit <number> \
     --title "新しいタイトル" \
     --body "$(cat <<'EOF'
   [新しい description の内容]
   EOF
   )"
   ```

カウンタを更新: `PR_UPDATES`。

#### 3d. PR_CONFLICT イベント

コンフリクトを検出した場合、自動で解消して監視を継続する。

**処理フロー:**

1. ベースブランチ名を取得し、最新を取得してリベースする:

   ```bash
   BASE=$(gh pr view "$PR_NUMBER" -R "$OWNER/$REPO" --json baseRefName --jq '.baseRefName')
   git fetch origin "$BASE"
   git rebase "origin/$BASE"
   ```

2. コンフリクトが発生した場合、各ファイルのコンフリクトを解消する:
   - コンフリクトマーカー (`<<<<<<<`, `=======`, `>>>>>>>`) を含むファイルを特定する
   - 各ファイルの変更内容と PR の意図を考慮して適切に解消する
   - `git add <解消したファイル>` でステージングする
   - `git rebase --continue` でリベースを継続する

3. リベース完了後、フォースプッシュする:

   ```bash
   git push --force-with-lease
   ```

4. 解消できないコンフリクト (バイナリファイル、大規模な構造変更等) がある場合:
   - `git rebase --abort` でリベースを中断する
   - ユーザーに通知して監視を継続する (手動解消を待つ)

カウンタを更新: `CONFLICT_RESOLVES` (解消成功時)。

#### 3e. 終了イベント

`PR_MERGED`, `PR_CLOSED`, `TIMEOUT_IDLE`, `TIMEOUT_ABS` を受信した場合:

1. Monitor を TaskStop で停止する (既に exit 済みの場合もあるが、念のため実行する)
2. 完了報告 (ステップ 4) に進む

### 4. 監視終了・完了報告

```
## PR 監視完了

- PR: #<number> (<title>)
- 監視時間: <elapsed> 分

### レビュー修正
- 修正コミット数: X
- 返信済みコメント数: Y
- resolve 済みスレッド数: Z
- レビュー再リクエスト: L 人 (該当がない場合は省略)

### CI 修正
- 修正コミット数: A
- 修正不可能だったエラー: (該当する場合のみ記載)

### PR タイトル・description 更新
- 更新回数: B (0 の場合はこのセクションを省略)

### コンフリクト解消
- 解消回数: C (0 の場合はこのセクションを省略)

### 終了理由
<アイドルタイムアウト (30 分) / 絶対上限到達 (60 分) / PR マージ済み / PR クローズ済み>

PR URL: <url>
```

**初回チェックでレビュー/CI 失敗がなく、全 CI が成功している場合:**

Monitor がイベントを出力せずに動作し続けている状態。ユーザーへの報告は不要 (Monitor の起動報告で十分)。新しいレビューや CI 失敗が発生次第、自動修正する。

## エラーハンドリング

### Monitor 停止時

Monitor が予期せず停止した場合 (スクリプトエラー等)、状態を確認して再起動するか、完了報告して終了する。

### gh CLI エラー時

Monitor スクリプト内で 3 サイクル連続の API エラーが発生した場合、ネットワーク障害と判断して `TIMEOUT_ABS` イベントを出力して終了する。

### プッシュ失敗時

```bash
git pull --rebase origin <branch>
git push
```

rebase が失敗した場合はコンフリクト解消フロー (3d) と同様に処理する。

### subagent エラー時

- **commit-proposer エラー:** 変更差分から Conventional Commits 形式のメッセージを自前で生成する。`git diff --cached --stat` と `git log --oneline -5` を参考にする。subject には実際の変更内容を具体的に記述し、汎用的な表現は使わない
- **ci-analyzer エラー:** 直接 `gh run view <run-id> --log-failed` でログを取得し、エラーメッセージを分析して修正を試みる
