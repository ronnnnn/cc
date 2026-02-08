# Agent Teams パターン詳細手順

各タスクに specialist teammate を割り当て、独立したセッションで真に並列実行する。teammate 間で SendMessage を使い発見を共有・検証可能。

## B-1. チームの作成

```
TeamCreate({ team_name: "do-<timestamp>" })
```

## B-2. タスクの作成と teammate の起動

各タスクに対して TaskCreate でタスクを登録し、Task で teammate を**単一メッセージ内で並列に起動**する。

**コーディングタスクの場合** (Codex 委譲):

ステップ 2 で作成した設計書と `references/codex-delegation.md` の実行手順を組み合わせて teammate のプロンプトを構築する。

```
Task({
  team_name: "do-<timestamp>",
  name: "task-1",
  subagent_type: "general-purpose",
  description: "<タスクの要約>",
  prompt: `あなたは task-1 です。以下のコーディングタスクを Codex MCP に委譲して実行する。

## 設計書

<ステップ 2 で作成した設計書を挿入>

## 実行手順

<codex-delegation.md の手順 1〜5 を挿入>

## 制約事項

<codex-delegation.md の制約事項を挿入>

## チーム連携

### 他の teammate との連携
他の teammate から SendMessage で発見が共有された場合、自分のタスクに関連があれば反応する。
自分の発見が他の teammate に有益な場合は、SendMessage で共有する。

### 結果の送信
最終結果を lead に SendMessage で送信する。結果には codex-delegation.md の手順 5 の報告項目を含める。

### タスク完了
TaskUpdate で自分のタスクを completed に更新する。`
})
```

**非コーディングタスクの場合** (従来どおり):

```
Task({
  team_name: "do-<timestamp>",
  name: "task-2",
  subagent_type: "general-purpose",
  description: "<タスクの要約>",
  prompt: `あなたは task-2 です。以下のタスクを実行してください:

<タスクの詳細な指示>

## チーム連携

### 他の teammate との連携
他の teammate から SendMessage で発見が共有された場合、自分のタスクに関連があれば反応する。
自分の発見が他の teammate に有益な場合は、SendMessage で共有する。

### 結果の送信
最終結果を lead に SendMessage で送信する。形式:

\`\`\`markdown
## Task Results

**タスク:** <タスク名>
**ステータス:** 完了 / 部分完了 / 失敗
**変更ファイル:** (あれば)
- path/to/file1
- path/to/file2

**結果:**
<詳細な結果>
\`\`\`

### タスク完了
TaskUpdate で自分のタスクを completed に更新する。`
})

// ... 残りのタスクも同様
```

## B-3. 結果の収集

TaskList で全 teammate タスクの完了を待機する。各 teammate からの SendMessage は自動的に配信される。

## B-4. チームの削除

```
// 全 teammate にシャットダウンを要求
SendMessage({ type: "shutdown_request", recipient: "task-1" })
SendMessage({ type: "shutdown_request", recipient: "task-2" })
// ... 残りの teammate も同様

// 全 teammate のシャットダウン完了後
TeamDelete()
```

## フォールバック

- TeamCreate が失敗した場合 → パターン A (並列 subagent) にフォールバック
- 一部の teammate が失敗した場合 → 残りの teammate の結果で続行
- 全 teammate が失敗した場合 → パターン A にフォールバック
