---
name: configure
description: hookify ルールの有効/無効をインタラクティブに切り替える。Use when hookify ルールの設定変更、ルールの有効化・無効化を求められた際に使用する。
allowed-tools:
  - Glob
  - Read
  - Edit
  - Write
  - AskUserQuestion
---

# ルール設定

hookify ルールの有効/無効をインタラクティブに切り替える。

ルール形式の詳細は `${CLAUDE_PLUGIN_ROOT}/skills/hookify/references/rule-syntax.md` を Read で参照する。

## 手順

1. 以下の 2 つのディレクトリからルールファイルを検索する:
   - グローバル: `~/.claude/hooks-rules/*.md`
   - プロジェクト: `.claude/hooks-rules/*.md`

2. 各ファイルを Read で読み取り、name, enabled, event, action, ソースを取得する。

3. AskUserQuestion (multiSelect) でルールのトグルをユーザーに提示する:
   - 各ルールの現在のステータスを表示
   - ソース (global / project) でグループ化

4. 変更ごとの処理:
   - **プロジェクトルールの切り替え**: Edit でフロントマターの `enabled:` フィールドを変更する。
   - **グローバルルールの無効化**: `.claude/hooks-rules/` に同名のプロジェクトルールファイルを `enabled: false` で作成する。グローバルファイルは変更しない。
   - **グローバルルールの再有効化** (プロジェクト上書きの解除): プロジェクト上書きファイルを削除するか、`enabled: true` に設定する。

5. 変更内容を報告する。
