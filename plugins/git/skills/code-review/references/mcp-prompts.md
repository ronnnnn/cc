# MCP Review Prompts Reference

各 MCP ツールへのレビュー依頼プロンプトの詳細。

## Codex MCP (`mcp__codex__codex`)

### ローカルファイルレビュー

```json
{
  "prompt": "/review",
  "cwd": "/absolute/path/to/project"
}
```

`cwd` を指定すると、Codex はそのディレクトリのファイルをコンテキストとして使用する。

### PR レビュー

```json
{
  "prompt": "/review https://github.com/owner/repo/pull/123"
}
```

PR の URL を指定すると、Codex は PR の変更内容を取得してレビューを実行する。

## Gemini MCP (`mcp__gemini__ask-gemini`)

### ローカルファイルレビュー

```json
{
  "prompt": "/bug /absolute/path/to/project"
}
```

`/bug` の後にディレクトリパスを指定すると、Gemini はそのディレクトリをレビュー対象として使用する。

### PR レビュー

```json
{
  "prompt": "/bug https://github.com/owner/repo/pull/123"
}
```

PR の URL を指定すると、Gemini は PR の変更内容を取得してレビューを実行する。

## 出力パース

各 MCP からの出力は自由形式のテキスト。以下のパターンで問題を抽出する:

### 問題の識別パターン

- `[BUG]`, `[ERROR]`, `[ISSUE]` - バグ/問題
- `[SECURITY]`, `[VULNERABILITY]` - セキュリティ
- `[PERFORMANCE]`, `[PERF]` - パフォーマンス
- `[STYLE]`, `[LINT]` - スタイル/可読性

### ファイル位置の抽出

- `file.ts:123` - ファイル名:行番号
- `line 123` - 行番号のみ
- `in function foo()` - 関数名

### severity マッピング

| MCP 出力                   | 統合 severity |
| -------------------------- | ------------- |
| critical, severe, security | CRITICAL      |
| bug, error, high           | HIGH          |
| warning, medium            | MEDIUM        |
| info, suggestion, nit      | LOW           |
