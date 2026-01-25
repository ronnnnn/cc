---
name: review
description: ローカルの変更 (staged/unstaged) をレビューし、指摘箇所を自動修正する。修正がなくなるまで繰り返す。
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
  - ToolSearch
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
TaskCreate({ subject: "MCP 利用可能性の確認", description: "Codex/Gemini MCP の利用可能性を確認", activeForm: "MCP を確認中" })
TaskCreate({ subject: "並列レビューの実行", description: "Claude/Codex/Gemini で並列レビュー", activeForm: "並列レビューを実行中" })
TaskCreate({ subject: "レビュー結果の統合", description: "重複排除と severity 統一", activeForm: "結果を統合中" })
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

### 2. MCP 利用可能性の確認

ToolSearch tool で各 MCP の利用可能性を確認:

```
ToolSearch: select:mcp__codex__codex
ToolSearch: select:mcp__gemini__ask-gemini
```

利用可能な MCP をリストアップする。

### 3. 並列レビューの実行

**`code-review` スキルを参照して、各 AI へのレビュー依頼方法を確認する。**

Task tool で 3 つの sub agent を**並列に**起動する。各 sub agent は自分で差分を取得する。

```markdown
# Task 1: Claude レビュー

Task tool:
subagent_type: general-purpose
prompt: |
ローカルの変更をレビューしてください。

    手順:
    1. `git diff HEAD` でローカルの差分を取得
    2. 差分をレビューし、バグ、セキュリティ問題、パフォーマンス問題を確認

    出力フォーマット:
    ## Issues Found
    1. **[SEVERITY: CRITICAL/HIGH/MEDIUM/LOW]** [file:line] - 説明
       - 問題: ...
       - 修正案: 具体的なコード修正案

# Task 2: Codex レビュー (MCP 利用可能時)

Task tool:
subagent_type: general-purpose
prompt: |
Codex MCP を使用してローカル変更をレビューしてください。

    手順:
    1. ToolSearch で mcp__codex__codex を選択
    2. codex ツールを実行:
       prompt: "/review"
       cwd: "<カレントディレクトリの絶対パス>"
    3. Codex の結果を以下のフォーマットに変換して返す

    出力フォーマット:
    ## Issues Found
    1. **[SEVERITY: CRITICAL/HIGH/MEDIUM/LOW]** [file:line] - 説明
       - 問題: ...
       - 修正案: 具体的なコード修正案

# Task 3: Gemini レビュー (MCP 利用可能時)

Task tool:
subagent_type: general-purpose
prompt: |
Gemini MCP を使用してローカル変更をレビューしてください。

    手順:
    1. ToolSearch で mcp__gemini__ask-gemini を選択
    2. ask-gemini ツールを実行:
       prompt: "/bug <カレントディレクトリの絶対パス>"
    3. Gemini の結果を以下のフォーマットに変換して返す

    出力フォーマット:
    ## Issues Found
    1. **[SEVERITY: CRITICAL/HIGH/MEDIUM/LOW]** [file:line] - 説明
       - 問題: ...
       - 修正案: 具体的なコード修正案
```

**重要:** 3 つの Task を単一のメッセージ内で並列に呼び出すこと。

### 4. レビュー結果の統合

各 AI からの結果を統合する:

1. **重複排除**: 同じファイル・行への指摘はマージ
2. **severity 統一**: CRITICAL > HIGH > MEDIUM > LOW
3. **修正可能性判断**: 以下の指摘のみ自動修正対象
   - 具体的な修正案がある
   - ファイル・行番号が明確
   - 機械的に修正可能

**自動修正しない指摘:**

- 設計レベルの変更が必要
- 複数ファイルにまたがる修正
- 判断が必要な修正

### 5. 自動修正の実行

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

### 6. 再レビュー (必要な場合)

修正後、再度レビューを実行する:

```bash
# 修正後の差分を確認
git diff HEAD
```

**繰り返し条件:**

- 新たな指摘がある場合 → ステップ 3 に戻る
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

### 7. 完了報告

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

### MCP が利用できない場合

Claude 単独でレビューを実行し、修正を行う。

### 修正に失敗した場合

```markdown
## 修正失敗

以下のファイルの修正に失敗しました:

- **src/api/users.ts:42**
  - 理由: 該当行が見つかりません (ファイルが変更された可能性)
  - 対応: 手動での修正が必要
```

### 変更が大きすぎる場合

まずはコードベース全体を対象にレビューを試みる。
各 AI がトークン制限やサイズ制限で処理できない場合のみ、主要なファイルに絞ってレビューを行う:

```markdown
変更が大きいため、主要なファイルに絞ってレビューします。

重点レビュー対象:

- src/core/\*.ts (コア機能)
- src/api/\*.ts (API エンドポイント)

除外:

- \*.test.ts (テストファイル)
- \*.d.ts (型定義)
```
