# ルール構文リファレンス

ルールは YAML フロントマター付きのマークダウンファイルで、`hooks-rules/` ディレクトリに格納する。

## ルール配置場所

| 優先度 | パス                         | スコープ                    |
| ------ | ---------------------------- | --------------------------- |
| 低     | `~/.claude/hooks-rules/*.md` | グローバル (全プロジェクト) |
| 高     | `.claude/hooks-rules/*.md`   | プロジェクト固有            |

同名ルールはプロジェクト側が上書きする。プロジェクトルールで `enabled: false` にするとグローバルルールを無効化できる。

## ファイル形式

```markdown
---
name: rule-name
enabled: true
event: bash|file|stop|prompt|all
action: warn|block
pattern: 'regex-pattern'
tool_matcher: 'regex-pattern'
conditions:
  - field: command|file_path|new_text|content|tool_name
    operator: regex_match|contains|equals|not_contains|starts_with|ends_with
    pattern: 'pattern'
---

ルールがトリガーされた時に表示されるメッセージ。
マークダウン形式で記述可能。
```

## フロントマターフィールド

### 必須

- **name**: 一意の kebab-case 識別子。グローバル/プロジェクト間の上書きマッチングに使用。
- **enabled**: `true` または `false`。
- **event**: ルールを評価するタイミング。

### 任意

- **pattern**: 簡易 regex。イベントに応じて自動的に condition にマッピング:
  - `bash` → `field: command`
  - `file` → `field: new_text`
  - その他 → `field: content`
- **action**: `warn` (デフォルト) はメッセージ表示、`block` は操作を拒否。
- **tool_matcher**: ツール名にマッチする regex パターン。例:
  - `Bash` — 完全一致
  - `Edit|Write|MultiEdit` — OR マッチ
  - `mcp__.*` — 全 MCP ツール
  - `mcp__claude_ai_(?!Slack__).*` — Slack 以外の MCP ツール
  - `*` — 全ツール
- **conditions**: 条件のリスト (AND 論理)。複雑なルールには `pattern` の代わりに使用。

## イベント

| イベント | フック           | タイミング                       |
| -------- | ---------------- | -------------------------------- |
| `bash`   | PreToolUse       | Bash ツール実行前                |
| `file`   | PreToolUse       | Edit/Write/MultiEdit 実行前      |
| `stop`   | Stop             | Claude が停止しようとした時      |
| `prompt` | UserPromptSubmit | ユーザーがプロンプトを送信した時 |
| `all`    | 全フック         | 常に評価                         |

## 条件フィールド

| フィールド                | 利用可能イベント | 説明                   |
| ------------------------- | ---------------- | ---------------------- |
| `command`                 | bash             | Bash コマンド文字列    |
| `file_path`               | file             | 対象ファイルパス       |
| `new_text` / `new_string` | file             | 書き込まれる新しい内容 |
| `old_text` / `old_string` | file (Edit)      | 置換される内容         |
| `content`                 | file (Write)     | ファイル内容           |
| `tool_name`               | all              | 使用されるツール名     |
| `user_prompt`             | prompt           | ユーザーの入力テキスト |
| `reason`                  | stop             | 停止理由               |
| `transcript`              | stop             | 会話全文               |

## 条件演算子

| 演算子         | 説明                                              |
| -------------- | ------------------------------------------------- |
| `regex_match`  | regex 検索 (デフォルト、大文字小文字を区別しない) |
| `contains`     | 部分文字列マッチ                                  |
| `equals`       | 完全一致                                          |
| `not_contains` | 部分文字列の否定                                  |
| `starts_with`  | 前方一致                                          |
| `ends_with`    | 後方一致                                          |

## ルール例

### 危険な rm をブロック

```markdown
---
name: block-dangerous-rm
enabled: true
event: bash
pattern: "rm\\s+-rf\\s+/"
action: block
---

絶対パスに対する rm -rf を検出しました。安全な代替手段を使用してください。
```

### ファイル内の console.log に警告

```markdown
---
name: warn-console-log
enabled: true
event: file
pattern: "console\\.log\\("
action: warn
---

console.log を検出しました。適切なロギングライブラリの使用を検討してください。
```

### 特定の MCP ツールをブロック (regex tool_matcher)

```markdown
---
name: block-slack-mcp
enabled: true
event: all
action: block
tool_matcher: 'mcp__claude_ai_Slack__.*'
---

Slack MCP ツールはこのプロジェクトでブロックされています。
```

### 停止前にテスト実行を要求

```markdown
---
name: require-tests
enabled: true
event: stop
action: block
conditions:
  - field: transcript
    operator: not_contains
    pattern: 'npm test|pytest|cargo test|bun test'
---

テスト実行が検出されませんでした。完了前にテストを実行してください。
```

### 複数条件 (AND)

```markdown
---
name: warn-env-write
enabled: true
event: file
action: warn
conditions:
  - field: file_path
    operator: regex_match
    pattern: "\\.env"
  - field: new_text
    operator: regex_match
    pattern: "(password|secret|token|api_key)\\s*="
---

.env ファイルにシークレットを書き込んでいます。このファイルが .gitignore に含まれていることを確認してください。
```

### グローバルルールをプロジェクトで無効化

```markdown
---
name: block-dangerous-rm
enabled: false
event: bash
---

(このプロジェクトレベルのルールはグローバルの block-dangerous-rm ルールを無効化します。)
```

## Tips

- 単一条件のシンプルなルールには `pattern` を使用する
- 複数フィールドや複雑なマッチングには `conditions` を使用する
- `tool_matcher` は conditions の前にフィルタされる (パフォーマンス最適化)
- regex パターンのテスト: `echo "test string" | python3 -c "import re,sys; print(bool(re.search(r'pattern', sys.stdin.read())))"`
- まず `action: warn` で試し、確信が持てたら `block` に切り替える
