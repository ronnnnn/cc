---
name: tech-research
description: |
  このスキルは、「技術調査して」「ドキュメントを調べて」「使い方を教えて」「最新情報を調べて」「API の仕様を確認して」「ライブラリの使い方」「フレームワークのドキュメント」などのリクエスト、または技術・ツール・フレームワーク・ライブラリの調査が必要な場合に使用する。優先順位に基づく複数ソースからの構造化された技術調査アプローチを提供する。
version: 0.1.0
---

# Tech Research Skill

技術やツール、フレームワークの使い方や最新情報を、信頼できるソースから優先順位に基づいて調査するためのガイダンス。

## 概要

技術調査は subagent (Task ツール) を起動して行う。調査対象に応じて適切なソースを優先順位に基づいて選択し、正確な情報を取得する。

## 調査ソースの優先順位

以下の優先順位でソースを使い分ける:

| 優先度 | ソース       | 用途                                          | ツール                                                                                                   |
| ------ | ------------ | --------------------------------------------- | -------------------------------------------------------------------------------------------------------- |
| 1      | LSP          | コードベース内の定義・参照・型情報の調査      | goToDefinition, findReferences, incomingCalls, outgoingCalls                                             |
| 2      | deepwiki MCP | OSS リポジトリの Wiki・ドキュメント           | `mcp__deepwiki__read_wiki_structure`, `mcp__deepwiki__read_wiki_contents`, `mcp__deepwiki__ask_question` |
| 3      | context7 MCP | ライブラリの公式ドキュメントとコード例        | `mcp__context7__resolve-library-id`, `mcp__context7__query-docs`                                         |
| 4      | WebFetch     | 公式サイト・GitHub・特定 URL のコンテンツ取得 | WebFetch                                                                                                 |
| 5      | WebSearch    | 最新情報・ブログ・リリースノートの検索        | WebSearch                                                                                                |

## 調査手順

### 1. 調査対象の分類

調査リクエストを以下のカテゴリに分類する:

- **コードベース内の調査**: 関数の定義、参照元、呼び出し関係 → LSP を使用
- **OSS ライブラリの仕組み**: 内部実装、アーキテクチャ → deepwiki MCP を使用
- **ライブラリの使い方**: API、設定方法、コード例 → context7 MCP を使用
- **特定ページの情報**: 公式ドキュメント、GitHub Issues → WebFetch を使用
- **最新情報・トレンド**: リリース情報、ベストプラクティス → WebSearch を使用

### 2. subagent の起動

Task ツールで調査用の subagent を起動する。subagent には以下を指定する:

- `subagent_type`: 調査の性質に応じて選択
  - コードベース探索: `Explore`
  - 汎用調査: `general-purpose`
- `prompt`: 調査内容を具体的に記述
- `model`: 軽量な調査は `haiku`、複雑な調査は `sonnet`

**並列調査**: 独立した複数の調査対象がある場合、複数の Task を同時に起動して並列実行する。

### 3. 各ソースの使い方

#### LSP (優先度 1)

コードベース内の調査に使用する。Grep ではなく LSP を優先する。

```
goToDefinition: 関数・クラスの定義元を特定
findReferences: 特定のシンボルの参照箇所を列挙
incomingCalls: 関数の呼び出し元を追跡
outgoingCalls: 関数が呼び出す先を追跡
```

#### deepwiki MCP (優先度 2)

OSS リポジトリの内部ドキュメントを調査する。

```
1. ToolSearch で deepwiki ツールをロード
2. mcp__deepwiki__read_wiki_structure: リポジトリの Wiki 構造を確認
3. mcp__deepwiki__read_wiki_contents: 特定ページの内容を取得
4. mcp__deepwiki__ask_question: 特定の質問に回答を得る
```

リポジトリの指定形式: `owner/repo` (例: `facebook/react`, `vercel/next.js`)

#### context7 MCP (優先度 3)

ライブラリの公式ドキュメントとコード例を取得する。

```
1. ToolSearch で context7 ツールをロード
2. mcp__context7__resolve-library-id: ライブラリ ID を解決
3. mcp__context7__query-docs: ドキュメントを検索・取得
```

#### WebFetch (優先度 4)

特定の URL からコンテンツを取得する。

```
WebFetch:
  url: "<対象 URL>"
  prompt: "<抽出したい情報の説明>"
```

主な用途:

- 公式ドキュメントページの特定セクション
- GitHub Releases / Changelog
- API リファレンス

#### WebSearch (優先度 5)

最新情報やトレンドを検索する。

```
WebSearch:
  query: "<検索クエリ>"
```

検索クエリのコツ:

- 年を含める (例: "React Server Components 2026")
- 公式ソースを優先 (site:github.com, site:docs.\*)
- 具体的なキーワードを使用

### 4. 結果の構造化

調査結果を以下の形式でまとめる:

```markdown
## 調査結果: <対象名>

### 概要

<1-2 文で要約>

### 詳細

<調査で得られた具体的な情報>

### ソース

- [ソース名](URL) - 取得した情報の概要
```

## ソース選択のフローチャート

```
調査対象は何か？
├── コードベース内の定義・参照 → LSP
├── OSS の内部実装・アーキテクチャ → deepwiki MCP
├── ライブラリの使い方・API → context7 MCP
├── 特定 URL のコンテンツ → WebFetch
└── 最新情報・トレンド → WebSearch
```

上位ソースで情報が不足する場合、次の優先度のソースにフォールバックする。

## Additional Resources

### Reference Files

詳細なプロンプトテンプレートやソースごとの使い分けガイド:

- **`references/source-guide.md`** - 各ソースの詳細な使い方と具体例
