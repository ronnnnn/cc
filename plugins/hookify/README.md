# Hookify

Claude Code のアクションに対して警告またはブロックするルールを作成できるプラグイン。YAML フロントマター付きのマークダウンファイルでルールを定義し、グローバルとプロジェクトの 2 階層で管理する。

## 公式 hookify からの改善点

| 機能                 | 公式 hookify                            | このプラグイン                          |
| -------------------- | --------------------------------------- | --------------------------------------- |
| ルール配置           | `.claude/hookify.*.local.md` (フラット) | `hooks-rules/` ディレクトリ             |
| グローバルルール     | 非対応                                  | `~/.claude/hooks-rules/`                |
| tool_matcher         | 完全一致のみ                            | regex 対応                              |
| tool_name condition  | 非対応                                  | `field: tool_name` で条件指定可能       |
| グローバルルール参照 | 相対パスで CWD に依存                   | `~/.claude/hooks-rules/` で絶対パス参照 |

## クイックスタート

### 1. ルールファイルを作成

`~/.claude/hooks-rules/block-rm-rf.md`:

```markdown
---
name: block-rm-rf
enabled: true
event: bash
pattern: "rm\\s+-rf"
action: block
---

危険な rm -rf コマンドを検出しました。安全な代替手段を使用してください。
```

### 2. 動作確認

Claude Code で `rm -rf` を含むコマンドを実行しようとすると、ブロックされる。

## ルール配置場所

| 優先度 | パス                         | スコープ                    |
| ------ | ---------------------------- | --------------------------- |
| 低     | `~/.claude/hooks-rules/*.md` | グローバル (全プロジェクト) |
| 高     | `.claude/hooks-rules/*.md`   | プロジェクト固有            |

- 同名ルールはプロジェクト側が優先 (上書き)
- プロジェクトルールで `enabled: false` にするとグローバルルールを無効化できる

## ルール形式

```markdown
---
name: rule-name # 一意の kebab-case 識別子
enabled: true # true / false
event: bash # bash / file / stop / prompt / all
action: warn # warn (警告のみ) / block (操作を拒否)
pattern: 'regex' # 簡易 regex (単一条件向け)
tool_matcher: 'regex' # ツール名の regex フィルタ
conditions: # 複数条件 (AND 論理)
  - field: command
    operator: regex_match
    pattern: 'pattern'
---

ルールがトリガーされた時に表示されるメッセージ。
```

### イベント

| イベント | フック           | タイミング                       |
| -------- | ---------------- | -------------------------------- |
| `bash`   | PreToolUse       | Bash ツール実行前                |
| `file`   | PreToolUse       | Edit/Write/MultiEdit 実行前      |
| `stop`   | Stop             | Claude が停止しようとした時      |
| `prompt` | UserPromptSubmit | ユーザーがプロンプトを送信した時 |
| `all`    | 全フック         | 常に評価                         |

### 条件フィールド

`command`, `file_path`, `new_text`, `old_text`, `content`, `tool_name`, `user_prompt`, `reason`, `transcript`

### 条件演算子

`regex_match`, `contains`, `equals`, `not_contains`, `starts_with`, `ends_with`

### tool_matcher の例

```yaml
tool_matcher: "Bash"                              # 完全一致
tool_matcher: "Edit|Write|MultiEdit"              # OR マッチ
tool_matcher: "mcp__.*"                           # 全 MCP ツール
tool_matcher: "mcp__claude_ai_(?!Slack__).*"      # Slack 以外の MCP ツール
```

## スキル

| スキル               | 説明                                          |
| -------------------- | --------------------------------------------- |
| `/hookify:hookify`   | 新規ルール作成 (会話分析または明示的指示から) |
| `/hookify:list`      | 設定済みルールの一覧表示                      |
| `/hookify:configure` | ルールの有効/無効をインタラクティブに切り替え |
| `/hookify:help`      | ヘルプ表示                                    |

## 技術詳細

- **言語**: Python 3 (外部依存なし)
- **YAML パーサー**: 簡易実装 (ダブルクォートエスケープ対応)
- **エラーハンドリング**: 全フックが常に exit 0 (ルール評価エラーでもツール実行をブロックしない)
- **regex キャッシュ**: LRU キャッシュ (最大 128 パターン) でコンパイル済み正規表現を再利用
