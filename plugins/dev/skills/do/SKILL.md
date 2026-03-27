---
name: do
description: 複数の独立したタスクを並列で実行する。タスク内容に応じて subagent または Agent Teams を自動選択する。Use when 複数タスクの並列実行、同時作業、swarm 実行を求められた際に使用する。
argument-hint: '<タスクの列挙>'
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
  - AskUserQuestion
---

# 並列タスク実行ワークフロー

引数で渡された複数タスクを並列で実行し、結果を集約して報告する。

## 重要な原則

1. **タスク内容に応じてアプローチを自動選択** - 単一セッション内の並列 subagent または Agent Teams
2. **各タスクは独立して実行** - タスク間の依存関係がある場合は順序を考慮
3. **結果を集約して報告** - 全タスクの完了後にサマリを提示
4. **失敗したタスクは明示的に報告** - 成功・失敗を区別して報告

## 作業開始前の準備

**必須:** 作業開始前に TaskList で残存タスクを確認し、存在する場合は全て TaskUpdate({ status: "deleted" }) で削除する。その後、TaskCreate ツールで以下のステップをタスクとして登録する:

```
TaskCreate({ subject: "タスクの分析と分割", description: "引数からタスクを抽出・分類", activeForm: "タスクを分析中" })
TaskCreate({ subject: "アプローチ判定", description: "subagent / agent teams を選択", activeForm: "アプローチを判定中" })
TaskCreate({ subject: "タスクの並列実行", description: "選択したアプローチで並列実行", activeForm: "タスクを並列実行中" })
TaskCreate({ subject: "結果の集約と報告", description: "全タスクの結果をまとめて報告", activeForm: "結果を集約中" })
```

各ステップの開始時に TaskUpdate で `in_progress` に、完了時に `completed` に更新する。

## 実行手順

### 1. タスクの分析と分割

引数で渡されたテキストからタスクを抽出する:

- 番号付きリスト (1. 2. 3.)、箇条書き (- / \*)、「と」「、」区切り等のパターンを認識
- 各タスクを独立した作業単位に分割
- タスク間の依存関係を検出 (「A の結果を使って B」等)

**分割結果を提示:**

```markdown
## 検出されたタスク

1. **タスク名** - 概要
2. **タスク名** - 概要
3. **タスク名** - 概要

依存関係: なし / タスク 2 はタスク 1 の完了後に実行
```

### 2. アプローチ判定

#### 2-1. Agent Teams の利用可能性確認

```bash
echo "${CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS:-0}"
```

- `0` または未設定 → **パターン A (並列 subagent)** で実行
- `1` → 次のステップでタスク内容に基づいて判断

#### 2-2. アプローチの選択

Agent Teams が利用可能な場合、以下の基準で**メインセッションが総合判断**する:

| 基準               | パターン A (並列 subagent)         | パターン B (Agent Teams)             |
| ------------------ | ---------------------------------- | ------------------------------------ |
| **タスク間の連携** | 各タスクは独立、結果を集約するだけ | タスク間で発見を共有・相互検証が有益 |
| **タスク数**       | 2〜3 個                            | 4 個以上                             |
| **タスクの複雑度** | 単純・短時間で完了                 | 複雑・長時間・複数ファイル変更       |
| **コンテキスト**   | 単一モジュール内                   | 複数モジュール/レイヤーにまたがる    |
| **最適なケース**   | 結果だけが重要な集中タスク         | 議論とコラボが必要な複雑タスク       |

**目安:**

- タスク数 3 以下 かつ 各タスクが単純 → パターン A 推奨
- タスク数 4 以上 → パターン B 推奨
- タスク間で相互検証が有益 → パターン B 推奨
- 同一ファイルへの変更が複数タスクにまたがる → パターン A 推奨 (競合回避)

### 3. タスクの並列実行

#### パターン A: 並列 subagent

各タスクを `Task` ツールで `general-purpose` subagent として**単一メッセージ内で並列に起動**する。

```
Task({
  subagent_type: "general-purpose",
  description: "<タスクの要約>",
  prompt: `以下のタスクを実行してください:

<タスクの詳細な指示>

完了したら結果をマークダウン形式で報告してください。`
})
```

**重要:**

- 全 subagent を単一メッセージ内で呼び出すことで真の並列実行を実現
- 各 subagent の結果は自動的にメインセッションに返却される

→ ステップ 4 (結果の集約) へ進む

#### パターン B: Agent Teams

各タスクに specialist teammate を割り当て、独立したセッションで真に並列実行する。teammate 間で SendMessage を使い発見を共有・検証可能。

**詳細な手順は `references/agent-teams-pattern.md` を参照。** 概要:

1. **B-1.** `TeamCreate` でチームを作成
2. **B-2.** 各タスクに対して `Task` (team_name, name 指定) で teammate を**単一メッセージ内で並列起動**
3. **B-3.** `TaskList` で全 teammate の完了を待機 (SendMessage は自動配信)
4. **B-4.** 全 teammate に `shutdown_request` → `TeamDelete`

**フォールバック:** TeamCreate 失敗 → パターン A / 全 teammate 失敗 → パターン A / 一部失敗 → 残りの結果で続行

### 4. 結果の集約と報告

全タスクの結果を集約してユーザーに報告する。**報告テンプレートは `references/report-format.md` を参照。**

報告に含める情報:

- 実行方式 (並列 subagent / Agent Teams)
- タスク数と成功・失敗の内訳
- 各タスクの結果要約
- 変更ファイル一覧 (あれば)
- 失敗したタスクのエラー内容と推奨対応

## 依存関係のあるタスクの処理

タスク間に依存関係がある場合:

1. 依存関係のないタスクを先に並列実行
2. 依存先タスクの完了を待機
3. 依存タスクを実行 (必要なら再度並列)

## エラーハンドリング

### タスクの一部が失敗した場合

成功したタスクの結果は保持し、失敗したタスクのみを報告する。ユーザーに再実行するか確認:

```
AskUserQuestion({
  questions: [{
    question: "失敗したタスクを再実行しますか？",
    header: "Retry",
    options: [
      { label: "再実行する", description: "失敗したタスクのみを再実行します" },
      { label: "スキップ", description: "失敗したタスクをスキップして完了します" }
    ],
    multiSelect: false
  }]
})
```

### 全タスクが失敗した場合

- パターン B (Agent Teams) で全 teammate が失敗 → パターン A (並列 subagent) にフォールバックして再試行
- パターン A で全 subagent が失敗 → エラー内容を報告し、ユーザーに個別実行を提案
