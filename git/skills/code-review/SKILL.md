---
name: code-review
description: This skill should be used when the user asks to "code review", "レビュー依頼", "codex レビュー", "gemini レビュー", "multi-ai review", "並列レビュー", or needs guidance on requesting code reviews from multiple AI sources (Claude, Codex MCP, Gemini MCP). Provides review request patterns and result aggregation methods for subagent execution.
version: 0.1.0
---

# Code Review Skill

複数の AI (Claude, Codex MCP, Gemini MCP) にコードレビューを依頼し、結果を統合するためのガイダンス。

## 概要

このスキルは sub agent 内で実行され、以下の AI にレビューを依頼する:

1. **Claude** - 自身でコードを分析してレビュー
2. **Codex MCP** - `mcp__codex__codex` ツール (以降 `codex` と表記) で `/review` を実行 (利用可能時)
3. **Gemini MCP** - `mcp__gemini__ask-gemini` ツール (以降 `ask-gemini` と表記) で `/bug` を実行 (利用可能時)

## レビュー依頼手順

### 1. MCP 利用可能性の確認

レビュー依頼前に、MCP サーバーの利用可能性を確認する:

```bash
# 利用可能な MCP ツールを確認
claude mcp list 2>/dev/null || echo "MCP unavailable"
```

または、ToolSearch tool で確認:

- `select:mcp__codex__codex` - Codex MCP の確認
- `select:mcp__gemini__ask-gemini` - Gemini MCP の確認

### 2. Claude 自身によるレビュー

コードを直接分析し、以下の観点でレビューする:

| 観点           | 確認事項                          |
| -------------- | --------------------------------- |
| バグ           | 論理エラー、off-by-one、null 参照 |
| セキュリティ   | インジェクション、認証、機密情報  |
| パフォーマンス | N+1、不要なループ、メモリリーク   |
| 可読性         | 命名、複雑度、コメント            |
| テスト         | カバレッジ、エッジケース          |

**出力フォーマット:**

```markdown
## Claude Review Results

### Issues Found

1. **[SEVERITY: HIGH]** [file:line] - 説明
   - 問題: 具体的な問題の説明
   - 推奨: 修正案

2. **[SEVERITY: MEDIUM]** [file:line] - 説明
   ...
```

### 3. Codex MCP へのレビュー依頼

Codex MCP が利用可能な場合、`codex` ツールでレビューを依頼する。

**ローカルファイルのレビュー:**

```
ToolSearch: select:mcp__codex__codex
mcp__codex__codex:
  prompt: "/review"
  cwd: "<レビュー対象ディレクトリの絶対パス>"
```

Codex は `cwd` で指定されたディレクトリのファイルを自動で参照する。

**PR のレビュー:**

```
mcp__codex__codex:
  prompt: "/review <PR の URL>"
```

詳細なプロンプトは `references/mcp-prompts.md` を参照。

### 4. Gemini MCP へのレビュー依頼

Gemini MCP が利用可能な場合、`ask-gemini` ツールでレビューを依頼する。

**ローカルファイルのレビュー:**

```
ToolSearch: select:mcp__gemini__ask-gemini
mcp__gemini__ask-gemini:
  prompt: "/bug <レビュー対象ディレクトリの絶対パス>"
```

**PR のレビュー:**

```
mcp__gemini__ask-gemini:
  prompt: "/bug <PR の URL>"
```

詳細なプロンプトは `references/mcp-prompts.md` を参照。

## 結果の統合

複数の AI からのレビュー結果を統合する際のルール:

### 重複排除

同じ箇所への指摘は 1 つにマージする:

1. ファイルパスと行番号で指摘をグループ化
2. 同じ問題への指摘は、最も詳細な説明を採用
3. severity は最も高いものを採用

### 優先度付け

| SEVERITY | 説明                                 | 対応         |
| -------- | ------------------------------------ | ------------ |
| CRITICAL | セキュリティ脆弱性、データ損失リスク | 即時修正必須 |
| HIGH     | バグ、重大なロジックエラー           | 修正推奨     |
| MEDIUM   | パフォーマンス問題、可読性           | 検討推奨     |
| LOW      | スタイル、軽微な改善                 | 任意         |

### 統合結果フォーマット

```markdown
## Aggregated Review Results

**Reviewed by:** Claude, Codex, Gemini
**Total Issues:** N

### Critical Issues (X)

[issues...]

### High Priority Issues (Y)

[issues...]

### Medium Priority Issues (Z)

[issues...]

### Low Priority Issues (W)

[issues...]
```

## 並列実行パターン

Task tool を使用して複数の AI に並列でレビューを依頼する:

```markdown
# 並列で 3 つの Task を起動

Task 1: Claude レビュー (code-review スキル + 自身で分析)
Task 2: Codex レビュー (codex MCP 経由)
Task 3: Gemini レビュー (gemini MCP 経由)
```

各 Task は独立して実行され、結果を返す。メインエージェントが結果を統合する。

## Additional Resources

### Reference Files

- **`references/mcp-prompts.md`** - 各 MCP への詳細なプロンプトテンプレート
