---
name: orchestrate
description: 大きいモデル (メインセッション) が計画・判断・統合を担い、トークン集約的な実行作業を小さいモデルの worker subagent にファンアウトする orchestrator-workers パターンでタスクを遂行する。Use when オーケストレーション、plan big execute small、worker への委譲、コスト効率の良い大規模タスク遂行、コンテキストを汚さない調査・実装を求められた際に使用する。
argument-hint: '<達成したいゴール>'
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - Task
  - TaskCreate
  - TaskUpdate
  - TaskList
  - SendMessage
  - AskUserQuestion
---

# Orchestrator-Workers ワークフロー

メインセッション (大きいモデル) が orchestrator として計画・判断・統合に専念し、実行作業を `dev:worker` subagent (sonnet) にファンアウトする。

## 重要な原則

1. **orchestrator はトークン集約的な作業をしない** - ファイル全文の読み込み、ログの精読、コード変更は worker に委譲する。orchestrator が直接行ってよいのは計画に必要な軽量の偵察 (ディレクトリ構成の確認、ファイル名の Glob 等) のみ
2. **worker には自己完結したブリーフを渡す** - worker はメインセッションの会話を見られない。ゴール・スコープ・完了条件・制約をブリーフに全て含める
3. **worker からは蒸留された結果のみを受け取る** - 生データが返ってきた場合も orchestrator は要点のみを利用する
4. **判断と統合は orchestrator が行う** - worker の報告を突き合わせ、矛盾の検出、失敗の再割り当て、最終統合はメインセッションの責務

## 作業開始前の準備

**必須:** 作業開始前に TaskList で残存タスクを確認し、存在する場合は全て TaskUpdate({ taskId: <taskId>, status: "deleted" }) で削除する。その後、TaskCreate ツールで以下のステップをタスクとして登録する:

```
TaskCreate({ subject: "ゴール分析と偵察", description: "ゴールの把握と軽量な現状調査", activeForm: "ゴールを分析中" })
TaskCreate({ subject: "サブタスク分解と計画", description: "独立したサブタスクへの分解と依存関係の整理", activeForm: "計画を作成中" })
TaskCreate({ subject: "worker へのファンアウト", description: "dev:worker を並列起動", activeForm: "worker を起動中" })
TaskCreate({ subject: "監視と再割り当て", description: "失敗タスクの分析と再投入", activeForm: "進捗を監視中" })
TaskCreate({ subject: "統合と報告", description: "worker の報告を統合して最終報告", activeForm: "結果を統合中" })
```

各ステップの開始時に TaskUpdate で `in_progress` に、完了時に `completed` に更新する。

## 実行手順

### 1. ゴール分析と偵察

引数からゴールを把握する。引数がない場合は AskUserQuestion で確認する。

計画に必要な最小限の偵察を行う:

- `Glob` / `ls` でディレクトリ構成を確認
- タスクランナー (package.json, Makefile 等) の存在確認
- **ファイルの中身の精読はしない** - 内容の把握が必要な場合はそれ自体を調査 worker に委譲する

### 2. サブタスク分解と計画

ゴールを worker に委譲可能なサブタスクに分解する:

- **独立性**: 各サブタスクは他の worker の結果を待たずに完遂できる
- **自己完結**: worker が追加の質問なしで実行できる情報を含む
- **蒸留可能な出力**: 「〜を調査して要約」「〜を実装してテスト」のように、報告が要点に圧縮できる形にする
- **競合回避**: 同一ファイルを変更するサブタスクは同じ worker にまとめるか、順次実行にする

依存関係がある場合はウェーブに分ける (ウェーブ 1 の結果を踏まえてウェーブ 2 のブリーフを作る)。

**計画を提示:**

```markdown
## 実行計画

### ウェーブ 1 (並列)

1. **<サブタスク名>** - <概要>
2. **<サブタスク名>** - <概要>

### ウェーブ 2 (ウェーブ 1 完了後)

3. **<サブタスク名>** - <概要> (1 の結果を利用)
```

### 3. worker へのファンアウト

各サブタスクを `Task` ツールで `dev:worker` として**単一メッセージ内で並列に起動**する。ブリーフのフォーマットは `references/worker-brief-format.md` を参照。

```
Task({
  subagent_type: "dev:worker",
  name: "worker-<連番>",
  description: "<サブタスクの要約>",
  prompt: <references/worker-brief-format.md に従ったブリーフ>
})
```

`name` は手順 4 の SendMessage による再開の宛先になるため必ず付与する。同一実行内で複数起動する場合は連番等で一意にする。

**モデルの上書き:** タスクの難易度が高い場合 (複雑な設計判断を含む等) は、Task の `model` パラメータで上位モデルを指定して委譲する (`model` パラメータは agent 定義の frontmatter より優先される)。

### 4. 監視と再割り当て

worker の報告を受け取り、以下を判断する:

- **成功**: 報告の要点を統合用に保持
- **部分成功・失敗**: 失敗原因を分析し、改善したブリーフ (前回の失敗内容と回避策を含む) で新しい worker に再投入する。同一タスクの再投入は 2 回まで
- **報告間の矛盾**: 矛盾する報告があれば、検証用のブリーフで確認 worker を起動するか、orchestrator が最小限の確認を行う
- **誤検知の判定**: worker はブリーフに書かれた情報しか持たない。orchestrator がセッションで検証済みの事実と矛盾する報告・指摘は鵜呑みにせず棄却し、判定理由を最終報告に含める

完了済み worker への軽微な追加指示・確認は、SendMessage で同じ worker に送るとコンテキストを保持したまま継続できる (v2.1.198+ の subagent 再開機能)。SendMessage が使えない環境では、改善したブリーフで新しい worker を起動する。

### 5. 統合と報告

全 worker の報告を統合してユーザーに報告する。**ゴールがファイルへの出力を伴う場合** (例: 「調査結果を 1 つのレポートファイルにまとめて」) は、orchestrator 自身に Edit/Write がないため、統合結果を書き出す worker を追加で起動する:

```markdown
## 実行結果

<ゴールに対する結論を冒頭 1〜2 文で>

### サブタスク結果

| #   | サブタスク | 結果         | 要点       |
| --- | ---------- | ------------ | ---------- |
| 1   | <名前>     | ✅ / ⚠️ / ❌ | <1 行要約> |

### 変更ファイル

- <path>: <変更概要>

### 未解決・次のステップ

- <worker から引き継いだ未解決事項、推奨する次の作業>
```

レビュー・調査系のゴールでは、worker の指摘に対する orchestrator の判定 (採用 / 棄却と理由) をサブタスク結果と未解決の間に含める。

## dev:do との使い分け

| 観点       | dev:do                                            | dev:orchestrate              |
| ---------- | ------------------------------------------------- | ---------------------------- |
| 入力       | ユーザーが列挙した複数タスク                      | 単一の大きなゴール           |
| 分解       | 列挙からタスクを抽出・依存判定 (計画立案はしない) | orchestrator が計画・分解    |
| モデル戦略 | セッションモデルを継承                            | 計画は大、実行は小 (sonnet)  |
| 主目的     | 並列化による時間短縮                              | コスト効率とコンテキスト保護 |

## エラーハンドリング

- **worker が 2 回の再投入でも失敗**: そのサブタスクは失敗として報告に含め、orchestrator は残りのタスクを続行する。最後に AskUserQuestion で失敗タスクの扱い (上位モデルを指定して再委譲 / スキップしてユーザーに引き継ぐ) を確認する
- **全 worker が失敗**: ブリーフの前提 (環境、権限、ゴールの実現性) に共通の問題がある可能性が高い。個別再投入はせず、失敗原因の共通点を分析してユーザーに報告し、方針を確認する
- **dev:worker が起動できない** (プラグイン未ロード等): `general-purpose` subagent + `model: sonnet` 指定にフォールバックし、ブリーフに worker の報告フォーマットを含める

## Additional Resources

### Reference Files

- **`references/worker-brief-format.md`** - worker に渡すタスクブリーフのフォーマットと記入例
