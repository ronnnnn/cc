# Session Context

## User Prompts

### Prompt 1

pr-watch や pr-ci で ci の status 確認してるけど、ページングにより全てのステータス確認できてない可能性ある？

### Prompt 2

y

### Prompt 3

Base directory for this skill: /Users/s01059/Documents/agent/cc/.claude/skills/bump-version

プラグインまたはマーケットプレースのバージョンを更新してください。

## 引数

- `` の形式: `<target> <version>` (省略可能)
  - `<target>`: プラグイン名 (git, claude, catch-up) または `marketplace`
  - `<version>`: 新しいバージョン (例: 1.6.0)

## 作業開始前の準備

**必須:** 作業開始前に TaskList で残存タスクを確認し、存在する場合は全て TaskUpdate({ status: "deleted" }) で削除する。その後、TaskCreate ツールで以下のステップをタスクとして登録する:

```
TaskCreate({ subject: "対象と変更内容の特定", description: "引数または git diff から対象プラグインとバージョ...

### Prompt 4

y

### Prompt 5

y

