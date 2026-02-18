---
allowed-tools:
  - Read
  - Write
  - AskUserQuestion
  - Task
  - Grep
---

このスキルは、「hookify ルールを作成」「フックルールを追加」「hookify」「ルールを作って」「この行動を防止して」「hook を設定」「hookify ルール構文」「ルールの形式を教えて」「条件の書き方」などのリクエスト、または会話内の問題行動を分析してルール化する際に使用する。

# ルール作成

hookify ルールを新規作成する。会話分析モードと明示的指示モードの 2 つがある。

ルール構文の詳細は `${CLAUDE_PLUGIN_ROOT}/skills/hookify/references/rule-syntax.md` を Read で参照する。

## 引数なし (会話分析モード)

1. conversation-analyzer エージェントを `Task` ツールで起動し、現在の会話から防止すべき行動パターンを分析する。

2. エージェントが構造化された結果を返す。

3. 提案されたルールごとに AskUserQuestion で確認する:
   - ルール内容 (name, event, pattern, action, message) を表示
   - 「このルールを作成しますか?」→ 選択肢: グローバルに作成 / プロジェクトに作成 / スキップ

## 引数あり (明示的指示モード)

1. `${CLAUDE_PLUGIN_ROOT}/skills/hookify/references/rule-syntax.md` を Read で読み込み、ルール形式を参照する。

2. ユーザーの説明から以下を特定する:
   - イベントタイプ (bash, file, stop, prompt, all)
   - パターンまたは conditions
   - アクション (warn または block)
   - 必要に応じて tool_matcher

3. YAML frontmatter 付きのマークダウンファイルとしてルールを下書きする。

4. AskUserQuestion でユーザーに確認する:
   - ルール名 (kebab-case を提案)
   - スコープ: グローバル (`~/.claude/hooks-rules/`) またはプロジェクト (`.claude/hooks-rules/`)
   - 下書きの確認

## ルールファイルの書き込み

1. 対象ディレクトリが存在しない場合は作成する。

2. 選択された場所にルールファイルを書き込む:
   - グローバル: `~/.claude/hooks-rules/{name}.md`
   - プロジェクト: `.claude/hooks-rules/{name}.md`

3. ルールの作成完了を報告し、テスト方法を説明する。

## ルールテンプレート

```markdown
---
name: {name}
enabled: true
event: {event}
action: {action}
{tool_matcher 行 (必要な場合)}
{pattern または conditions}
---

{メッセージ本文}
```
