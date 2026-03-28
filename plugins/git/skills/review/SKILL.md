---
name: review
description: ローカルの変更 (staged/unstaged) をレビューし、指摘箇所を自動修正する。指摘がなくなるまで最大 3 回繰り返す。Use when コミット前のコードレビュー、ローカル変更のセルフレビューを求められた際に使用する。
allowed-tools:
  - Bash
  - Read
  - Edit
  - Write
  - Glob
  - Grep
  - Task
  - TaskCreate
  - TaskUpdate
  - TaskList
  - TeamCreate
  - TeamDelete
  - SendMessage
---

# ローカルレビューワークフロー

ローカルの変更を複数の AI でレビューし、指摘箇所を自動修正する。

## 重要な原則

1. **複数 AI で並列レビューする** - Claude, Codex MCP, Gemini MCP を同時に使用
2. **結果を統合・重複排除する** - 同じ指摘は 1 つにマージ
3. **修正が必要なものは承認なしで自動修正する**
4. **レビュー・修正を繰り返す** - 修正がなくなるまで
5. **最終結果のサマリを報告する**
6. **自動修正は lead (メインセッション) のみが実行する** - Agent Teams 使用時も teammate はファイル編集しない

## 作業開始前の準備

**必須:** 作業開始前に TaskList で残存タスクを確認し、存在する場合は全て TaskUpdate({ status: "deleted" }) で削除する。その後、TaskCreate ツールで以下のステップをタスクとして登録する:

```
TaskCreate({ subject: "ローカル差分の取得", description: "git diff HEAD で全変更を取得", activeForm: "差分を取得中" })
TaskCreate({ subject: "アプローチ判定", description: "変更量・内容に基づいて subagent / agent teams を選択", activeForm: "アプローチを判定中" })
TaskCreate({ subject: "並列レビューの実行", description: "選択したアプローチで並列レビュー", activeForm: "並列レビューを実行中" })
TaskCreate({ subject: "自動修正の実行", description: "修正が必要な指摘を自動修正", activeForm: "自動修正を実行中" })
TaskCreate({ subject: "再レビュー", description: "修正後に再度レビュー (最大 3 回)", activeForm: "再レビューを実行中" })
TaskCreate({ subject: "完了報告", description: "修正サマリと残課題を報告", activeForm: "完了報告を作成中" })
```

各ステップの開始時に TaskUpdate で `in_progress` に、完了時に `completed` に更新する。

## 実行手順

### 1. ローカル差分の取得

staged と unstaged の両方の変更を取得する:

```bash
# staged 変更
git diff --cached

# unstaged 変更
git diff

# 全変更 (staged + unstaged)
git diff HEAD

# 変更ファイル一覧
git diff HEAD --name-only
```

変更がない場合は終了:

```markdown
レビュー対象の変更がありません。
```

### 2. アプローチ判定

差分の統計情報と環境変数に基づいて、レビューアプローチを選択する。

#### 2-1. 統計情報の取得

```bash
# 変更ファイル数
git diff HEAD --name-only | wc -l

# 変更行数
git diff HEAD --stat | tail -1
# "N files changed, X insertions(+), Y deletions(-)" から X + Y を算出
```

#### 2-2. Agent Teams の利用可能性確認

```bash
echo "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-0}"
```

- `0` または未設定 → **パターン A (単一 subagent)** で実行
- `1` → 次のステップで変更内容に基づいて判断

#### 2-3. アプローチの選択

Agent Teams が利用可能な場合、以下の基準で**メインセッションが総合判断**する:

| 基準                  | パターン A (単一 subagent) | パターン B (Agent Teams)                    |
| --------------------- | -------------------------- | ------------------------------------------- |
| **reviewer 間の議論** | 結果を集約するだけで十分   | 発見を共有・検証し合うことに価値がある      |
| **変更の複雑度**      | 単純な変更、少数ファイル   | 複数モジュール/レイヤーにまたがる複雑な変更 |
| **変更量**            | 小〜中規模                 | 大規模 (多数ファイル、大差分)               |
| **最適なケース**      | 結果だけが重要な集中タスク | 議論とコラボが必要な複雑タスク              |

**目安:**

- ファイル数 15 未満 かつ 変更行数 500 未満 かつ 単一モジュール → パターン A 推奨
- ファイル数 15 以上 または 変更行数 500 以上 → パターン B 推奨
- 複数モジュール/レイヤーにまたがる変更 → パターン B 推奨
- セキュリティ関連の変更 → パターン B 推奨 (複数視点が重要)

### 3. 並列レビューの実行

#### パターン A: 単一 subagent

**general-purpose subagent を Task ツールで呼び出す。**

<!-- WORKAROUND: プラグイン定義 agent では MCP ツールが利用不可のため、
     general-purpose subagent を使用して MCP ツールへのアクセスを確保している。
     バグ修正後は専用の code-reviewer agent を再作成し、subagent_type を切り替えること。
     See: https://github.com/anthropics/claude-code/issues/13605 -->

**重要:**

- `run_in_background: true` を指定しないこと。バックグラウンド実行では MCP ツールが利用できない。
- `subagent_type` は `"general-purpose"` を使用すること。`"git:code-reviewer"` では MCP ツールが利用不可。

```
Task({
  subagent_type: "general-purpose",
  description: "ローカル変更の並列レビュー",
  prompt: `あなたは code-reviewer です。ローカルの変更差分を複数 AI で並列レビューし、結果を統合してください。

## 手順

### 1. 差分の取得

\`\`\`bash
git diff HEAD
git diff HEAD --name-only
\`\`\`

### 2. MCP 利用可能性の確認

ToolSearch で各 MCP の利用可能性を確認:
- \`select:mcp__codex__codex\` - Codex MCP
- \`select:mcp__gemini__ask-gemini\` - Gemini MCP

### 3. 並列レビューの実行

利用可能な AI すべてに単一メッセージ内で並列にレビューを依頼する。

**Claude レビュー (常に実行):**

差分を直接分析し、以下の観点でレビューする:
- バグ: 論理エラー、off-by-one、null 参照
- セキュリティ: インジェクション、認証、機密情報
- パフォーマンス: N+1、不要なループ、メモリリーク
- 可読性: 命名、複雑度、コメント
- テスト: カバレッジ、エッジケース

**Codex MCP レビュー (利用可能時):**
- \`mcp__codex__codex\` を \`prompt: "/review"\`, \`profile: "review"\`, \`cwd: "<対象ディレクトリの絶対パス>"\` で呼び出す

**Gemini MCP レビュー (利用可能時):**
- \`mcp__gemini__ask-gemini\` を \`prompt: "/code-review <対象ディレクトリの絶対パス>"\` で呼び出す

### 4. 結果の統合

**重複排除:**
1. ファイルパスと行番号で指摘をグループ化
2. 同じ問題への指摘は最も詳細な説明を採用
3. severity は最も高いものを採用

**severity 統一:**
- CRITICAL: セキュリティ脆弱性、データ損失リスク (即時修正必須)
- HIGH: バグ、重大なロジックエラー (修正推奨)
- MEDIUM: パフォーマンス問題、可読性 (検討推奨)
- LOW: スタイル、軽微な改善 (任意)

**MCP 出力の severity マッピング:**
- critical, severe, security → CRITICAL
- bug, error, high → HIGH
- warning, medium → MEDIUM
- info, suggestion, nit → LOW

## 出力形式

\`\`\`markdown
## Aggregated Review Results

**Reviewed by:** Claude, Codex, Gemini (利用可能な AI のみ記載)
**Total Issues:** N

### Critical Issues (X)
1. **[CRITICAL]** [file:line] - 説明
   - 問題: ...
   - 推奨: ...
   - 検出元: Claude, Codex

### High Priority Issues (Y)
...
### Medium Priority Issues (Z)
...
### Low Priority Issues (W)
...
\`\`\`

## 注意事項
- MCP が全て利用不可の場合は Claude 単独でレビューを実行する
- スタイルのみの指摘 (linter で対応すべき)、好みの問題、曖昧な指摘は除外する
- 検出元 (Claude/Codex/Gemini) を各指摘に付記する`
})
```

subagent が以下を自動で実行する:

- MCP (Codex, Gemini) の利用可能性確認
- Claude 自身のレビュー + 利用可能な MCP に並列依頼
- 結果の統合・重複排除・severity 統一

→ ステップ 4 (自動修正) へ進む

#### パターン B: Agent Teams

各 reviewer に異なるレンズ (観点) を割り当て、独立したセッションで真に並列レビューを実行する。reviewer 間で発見を共有・検証し合うことで、単一 subagent よりも深い分析が可能。

**重要:** Agent Teams 使用時も**自動修正は lead (メインセッション) のみが実行**する。teammate はファイル編集しない (並行編集の競合回避)。

##### B-1. チームの作成

```
TeamCreate({ team_name: "review-<timestamp>" })
```

##### B-2. reviewer の起動

以下の reviewer を**単一メッセージ内で並列に起動**する。各 reviewer は Task ツールに `team_name` と `name` を指定して起動する。

**security-reviewer:**

```
Task({
  team_name: "review-<timestamp>",
  name: "security-reviewer",
  subagent_type: "general-purpose",
  description: "セキュリティレビュー",
  prompt: `あなたは security-reviewer です。ローカルの変更差分をセキュリティ観点でレビューしてください。

## 手順

### 1. 差分の取得
\`\`\`bash
git diff HEAD
\`\`\`

### 2. セキュリティ観点でのレビュー
以下に集中してレビューする:
- インジェクション (SQL, XSS, コマンド等)
- 認証・認可の欠陥
- 機密情報の漏洩 (ハードコードされたシークレット、ログへの出力)
- 入力バリデーションの不足
- 安全でないデシリアライゼーション
- アクセス制御の問題

### 3. 他の reviewer の発見を検証
他の reviewer から SendMessage で指摘が共有された場合、セキュリティの観点から反論・補強する。

### 4. 結果の送信
最終結果を lead に SendMessage で送信する。形式:

\`\`\`markdown
## Security Review Results

**Reviewer:** security-reviewer
**Issues Found:** N

1. **[SEVERITY]** [file:line] - 説明
   - 問題: ...
   - 推奨: ...
\`\`\`

### 5. タスク完了
TaskUpdate で自分のタスクを completed に更新する。`
})
```

**logic-reviewer:**

```
Task({
  team_name: "review-<timestamp>",
  name: "logic-reviewer",
  subagent_type: "general-purpose",
  description: "ロジックレビュー",
  prompt: `あなたは logic-reviewer です。ローカルの変更差分をバグ・ロジック観点でレビューしてください。

## 手順

### 1. 差分の取得
\`\`\`bash
git diff HEAD
\`\`\`

### 2. バグ・ロジック観点でのレビュー
以下に集中してレビューする:
- 論理エラー、off-by-one エラー
- null/undefined 参照
- 境界条件の処理漏れ
- 競合状態、デッドロック
- エラーハンドリングの不足
- パフォーマンス問題 (N+1 クエリ、不要なループ、メモリリーク)

### 3. 他の reviewer の発見を検証
他の reviewer から SendMessage で指摘が共有された場合、ロジックの観点から反論・補強する。

### 4. 結果の送信
最終結果を lead に SendMessage で送信する。形式:

\`\`\`markdown
## Logic Review Results

**Reviewer:** logic-reviewer
**Issues Found:** N

1. **[SEVERITY]** [file:line] - 説明
   - 問題: ...
   - 推奨: ...
\`\`\`

### 5. タスク完了
TaskUpdate で自分のタスクを completed に更新する。`
})
```

**bestpractice-reviewer:**

```
Task({
  team_name: "review-<timestamp>",
  name: "bestpractice-reviewer",
  subagent_type: "general-purpose",
  description: "ベストプラクティスレビュー",
  prompt: `あなたは bestpractice-reviewer です。ローカルの変更差分を使用ツール・FW・ライブラリ・言語のベストプラクティス観点でレビューしてください。

## 手順

### 1. 差分の取得
\`\`\`bash
git diff HEAD
\`\`\`

### 2. ベストプラクティス観点でのレビュー
以下に集中してレビューする:
- 使用言語のイディオムに従っているか
- フレームワーク・ライブラリの推奨パターンに従っているか
- API の正しい使用方法
- 非推奨 API・パターンの使用
- テストのベストプラクティス (カバレッジ、エッジケース)
- 可読性・命名規則

### 3. 他の reviewer の発見を検証
他の reviewer から SendMessage で指摘が共有された場合、ベストプラクティスの観点から反論・補強する。

### 4. 結果の送信
最終結果を lead に SendMessage で送信する。形式:

\`\`\`markdown
## Best Practice Review Results

**Reviewer:** bestpractice-reviewer
**Issues Found:** N

1. **[SEVERITY]** [file:line] - 説明
   - 問題: ...
   - 推奨: ...
\`\`\`

### 5. タスク完了
TaskUpdate で自分のタスクを completed に更新する。`
})
```

**codex-reviewer:**

```
Task({
  team_name: "review-<timestamp>",
  name: "codex-reviewer",
  subagent_type: "general-purpose",
  description: "Codex MCP レビュー",
  prompt: `あなたは codex-reviewer です。Codex MCP を使ってローカルの変更差分をレビューしてください。

## 手順

### 1. Codex MCP の利用可能性確認
ToolSearch で確認: \`select:mcp__codex__codex\`

利用不可の場合は、その旨を lead に SendMessage で報告し、タスクを完了する。

### 2. Codex MCP でレビュー
\`mcp__codex__codex\` を \`prompt: "/review"\`, \`profile: "review"\`, \`cwd: "<対象ディレクトリの絶対パス>"\` で呼び出す。

### 3. 結果の送信
Codex の出力を lead に SendMessage で送信する。severity マッピング:
- critical, severe, security → CRITICAL
- bug, error, high → HIGH
- warning, medium → MEDIUM
- info, suggestion, nit → LOW

### 4. タスク完了
TaskUpdate で自分のタスクを completed に更新する。`
})
```

**gemini-reviewer:**

```
Task({
  team_name: "review-<timestamp>",
  name: "gemini-reviewer",
  subagent_type: "general-purpose",
  description: "Gemini MCP レビュー",
  prompt: `あなたは gemini-reviewer です。Gemini MCP を使ってローカルの変更差分をレビューしてください。

## 手順

### 1. Gemini MCP の利用可能性確認
ToolSearch で確認: \`select:mcp__gemini__ask-gemini\`

利用不可の場合は、その旨を lead に SendMessage で報告し、タスクを完了する。

### 2. Gemini MCP でレビュー
\`mcp__gemini__ask-gemini\` を \`prompt: "/code-review <対象ディレクトリの絶対パス>"\` で呼び出す。

### 3. 結果の送信
Gemini の出力を lead に SendMessage で送信する。severity マッピング:
- critical, severe, security → CRITICAL
- bug, error, high → HIGH
- warning, medium → MEDIUM
- info, suggestion, nit → LOW

### 4. タスク完了
TaskUpdate で自分のタスクを completed に更新する。`
})
```

##### B-3. 結果の収集

TaskList で全 reviewer タスクの完了を待機する。各 reviewer からの SendMessage は自動的に配信される。

##### B-4. 結果の統合

全 reviewer の結果を統合・重複排除する:

1. ファイルパスと行番号で指摘をグループ化
2. 同じ問題への指摘は最も詳細な説明を採用
3. severity は最も高いものを採用
4. 検出元 (security-reviewer, logic-reviewer, bestpractice-reviewer, Codex, Gemini) を付記

**severity 統一:**

- CRITICAL: セキュリティ脆弱性、データ損失リスク (即時修正必須)
- HIGH: バグ、重大なロジックエラー (修正推奨)
- MEDIUM: パフォーマンス問題、可読性 (検討推奨)
- LOW: スタイル、軽微な改善 (任意)

##### B-5. チームの削除

```
# 全 teammate にシャットダウンを要求
SendMessage({ type: "shutdown_request", recipient: "security-reviewer" })
SendMessage({ type: "shutdown_request", recipient: "logic-reviewer" })
SendMessage({ type: "shutdown_request", recipient: "bestpractice-reviewer" })
SendMessage({ type: "shutdown_request", recipient: "codex-reviewer" })
SendMessage({ type: "shutdown_request", recipient: "gemini-reviewer" })

# 全 teammate のシャットダウン完了後
TeamDelete()
```

##### フォールバック

- TeamCreate が失敗した場合 → パターン A (単一 subagent) にフォールバック
- 一部の reviewer が失敗した場合 → 残りの reviewer の結果で続行
- 全 reviewer が失敗した場合 → パターン A にフォールバック

統合結果に基づき、修正可能性を判断する:

**自動修正対象:**

- 具体的な修正案がある
- ファイル・行番号が明確
- 機械的に修正可能

**自動修正しない指摘:**

- 設計レベルの変更が必要
- 複数ファイルにまたがる修正
- 判断が必要な修正

### 4. 自動修正の実行

修正が必要な指摘に対して、承認なしで自動修正を行う:

1. 対象ファイルを Read ツールで読み込む
2. Edit ツールで修正を適用
3. 修正内容をログ

```markdown
### 修正ログ

1. **src/api/users.ts:42** - null チェック追加
   - Before: `return user.id;`
   - After: `return user?.id ?? null;`

2. **src/utils/format.ts:15** - 型アノテーション追加
   ...
```

### 5. 再レビュー (必要な場合)

修正後、再度レビューを実行する。**再レビューは常にパターン A (単一 subagent) を使用する** (修正後の差分は小さいため agent teams は不要)。

```bash
# 修正後の差分を確認
git diff HEAD
```

**繰り返し条件:**

- 新たな指摘がある場合 → ステップ 3 (パターン A) に戻る
- 指摘がない場合 → 完了報告へ

**最大繰り返し回数:** 3 回

3 回繰り返しても指摘がある場合:

```markdown
## 自動修正の限界

以下の指摘は手動での対応が必要です:

1. **[src/core/engine.ts:100-150]**
   - 問題: アーキテクチャレベルの変更が必要
   - 推奨: ...
```

### 6. 完了報告

```markdown
## ローカルレビュー完了

**レビュー方式:** 単一 subagent / Agent Teams
**レビュー AI:** Claude, Codex, Gemini
**レビュー回数:** N 回

### 修正サマリ

| ファイル            | 修正数 | 内容                      |
| ------------------- | ------ | ------------------------- |
| src/api/users.ts    | 2      | null チェック追加、型修正 |
| src/utils/format.ts | 1      | 型アノテーション追加      |

**合計修正数:** X 件

### 残課題 (手動対応が必要)

なし / または以下:

- [file:line] - 説明
```

## エラーハンドリング

### 修正に失敗した場合

```markdown
## 修正失敗

以下のファイルの修正に失敗しました:

- **src/api/users.ts:42**
  - 理由: 該当行が見つかりません (ファイルが変更された可能性)
  - 対応: 手動での修正が必要
```
