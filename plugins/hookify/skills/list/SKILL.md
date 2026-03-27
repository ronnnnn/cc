---
name: list
description: グローバルとプロジェクトの両ディレクトリから設定済みの hookify ルールを一覧表示する。Use when hookify ルールの一覧、設定済みルールの確認を求められた際に使用する。
allowed-tools:
  - Glob
  - Read
---

# ルール一覧表示

グローバルとプロジェクトの両ディレクトリから設定済みの hookify ルールを一覧表示する。

## 手順

1. 以下の 2 つのディレクトリからルールファイルを検索する:
   - グローバル: `~/.claude/hooks-rules/*.md`
   - プロジェクト: `.claude/hooks-rules/*.md`

2. Glob で各ディレクトリの `*.md` ファイルを検索する。

3. 各ファイルの YAML frontmatter を Read で読み取り、以下を抽出する: name, enabled, event, action, tool_matcher, ソース (global/project)。

4. テーブル形式で表示する:

```
| ソース  | 名前              | イベント | アクション | 有効 | Tool Matcher |
|---------|-------------------|----------|-----------|------|--------------|
| global  | block-rm-rf       | bash     | block     | true | —            |
| project | warn-console-log  | file     | warn      | true | —            |
| project | block-rm-rf       | bash     | block     | false| —            |
```

5. プロジェクトルールがグローバルルールと同名の場合、「グローバルを上書き」と注記する。

6. ルールが見つからない場合は、`/hookify:hookify` でのルール作成、または `~/.claude/hooks-rules/` や `.claude/hooks-rules/` への手動作成を提案する。
