---
name: review
description: ローカルの変更 (staged/unstaged) をレビューし、指摘箇所を自動修正する。指摘がなくなるまで最大 3 回繰り返す。
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
version: 0.1.0
---

# ローカルレビューワークフロー

ローカルの変更を複数の AI でレビューし、指摘箇所を自動修正する。

## 重要な原則

1. **複数 AI で並列レビューする** - Claude, Codex MCP, Gemini MCP を同時に使用
2. **結果を統合・重複排除する** - 同じ指摘は 1 つにマージ
3. **修正が必要なものは承認なしで自動修正する**
4. **レビュー・修正を繰り返す** - 修正がなくなるまで
5. **最終結果のサマリを報告する**

## 作業開始前の準備

**必須:** 作業開始前に TaskCreate ツールで以下のステップをタスクとして登録する:

```
TaskCreate({ subject: "ローカル差分の取得", description: "git diff HEAD で全変更を取得", activeForm: "差分を取得中" })
TaskCreate({ subject: "並列レビューの実行", description: "code-reviewer subagent で並列レビュー", activeForm: "並列レビューを実行中" })
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

### 2. 並列レビューの実行

**code-reviewer subagent を Task ツールで呼び出す。**

**重要:** `run_in_background: true` を指定しないこと。バックグラウンド実行では MCP ツールが利用できないため、必ずフォアグラウンドで実行する。

```
Task({
  subagent_type: "git:code-reviewer",
  description: "ローカル変更の並列レビュー",
  prompt: "ローカルの変更差分をレビューしてください。`git diff HEAD` で差分を取得し、Claude/Codex MCP/Gemini MCP で並列レビューを実行して結果を統合してください。"
})
```

subagent が以下を自動で実行する:

- MCP (Codex, Gemini) の利用可能性確認
- Claude 自身のレビュー + 利用可能な MCP に並列依頼
- 結果の統合・重複排除・severity 統一

subagent から返却された統合結果に基づき、修正可能性を判断する:

**自動修正対象:**

- 具体的な修正案がある
- ファイル・行番号が明確
- 機械的に修正可能

**自動修正しない指摘:**

- 設計レベルの変更が必要
- 複数ファイルにまたがる修正
- 判断が必要な修正

### 3. 自動修正の実行

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

### 4. 再レビュー (必要な場合)

修正後、再度レビューを実行する:

```bash
# 修正後の差分を確認
git diff HEAD
```

**繰り返し条件:**

- 新たな指摘がある場合 → ステップ 2 に戻る
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

### 5. 完了報告

```markdown
## ローカルレビュー完了

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
