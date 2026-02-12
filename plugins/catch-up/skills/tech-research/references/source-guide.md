# 調査ソース詳細ガイド

各ソースの詳細な使い方、具体的なプロンプト例、よくあるユースケースをまとめる。

## LSP (優先度 1)

### 対象ユースケース

- 関数の定義元を知りたい
- あるシンボルがどこから参照されているか調べたい
- 呼び出し関係を追跡したい
- 型情報を確認したい

### 具体例

```
# 関数の定義元を特定
goToDefinition("handleSubmit")
→ src/components/Form.tsx:45

# 参照箇所を列挙
findReferences("UserService")
→ src/api/users.ts:12, src/controllers/auth.ts:34, ...

# 呼び出し元を追跡
incomingCalls("validateInput")
→ handleSubmit() → processForm() → ...

# 呼び出し先を追跡
outgoingCalls("handleSubmit")
→ validateInput() → submitToAPI() → ...
```

### Grep を使わない理由

- LSP はシンボルの意味的な関係を理解する (同名の異なるシンボルを区別可能)
- 型情報やスコープを考慮した正確な結果を返す
- リネームやリファクタリングにも対応

## deepwiki MCP (優先度 2)

### 対象ユースケース

- OSS ライブラリの内部アーキテクチャを理解したい
- 特定の機能がどう実装されているか知りたい
- コントリビューションガイドを確認したい

### 使い方

```
# Step 1: Wiki 構造を確認
ToolSearch: select:mcp__deepwiki__read_wiki_structure
mcp__deepwiki__read_wiki_structure:
  repoName: "vercel/next.js"

# Step 2: 特定ページを読む
mcp__deepwiki__read_wiki_contents:
  repoName: "vercel/next.js"
  pagePath: "architecture/routing"

# Step 3: 特定の質問をする
mcp__deepwiki__ask_question:
  repoName: "vercel/next.js"
  question: "How does the App Router handle parallel routes?"
```

### よくあるリポジトリ名

| ツール     | リポジトリ           |
| ---------- | -------------------- |
| React      | facebook/react       |
| Next.js    | vercel/next.js       |
| Vue.js     | vuejs/core           |
| Svelte     | sveltejs/svelte      |
| Bun        | oven-sh/bun          |
| Deno       | denoland/deno        |
| Rust       | rust-lang/rust       |
| Go         | golang/go            |
| TypeScript | microsoft/TypeScript |
| Terraform  | hashicorp/terraform  |
| Docker     | moby/moby            |

## context7 MCP (優先度 3)

### 対象ユースケース

- ライブラリの API リファレンスを確認したい
- 公式ドキュメントのコード例を取得したい
- 設定方法やオプションを調べたい

### 使い方

```
# Step 1: ライブラリ ID を解決
ToolSearch: select:mcp__context7__resolve-library-id
mcp__context7__resolve-library-id:
  libraryName: "react"

# Step 2: ドキュメントを検索
mcp__context7__query-docs:
  libraryId: "<resolved-id>"
  query: "useEffect cleanup function"
```

### 効果的なクエリ例

| 目的             | クエリ例                          |
| ---------------- | --------------------------------- |
| API の使い方     | "useState hook usage"             |
| 設定方法         | "configuration options"           |
| マイグレーション | "migration guide v2 to v3"        |
| 特定機能         | "server components data fetching" |

## WebFetch (優先度 4)

### 対象ユースケース

- 公式ドキュメントの特定ページを参照したい
- GitHub Releases のリリースノートを確認したい
- Changelog を読みたい

### 使い方

```
WebFetch:
  url: "https://nodejs.org/en/blog/release/v22.0.0"
  prompt: "このリリースの主要な変更点を抽出して"
```

### よく使う URL パターン

| 用途            | URL パターン                                 |
| --------------- | -------------------------------------------- |
| GitHub Releases | `https://github.com/{owner}/{repo}/releases` |
| npm パッケージ  | `https://www.npmjs.com/package/{name}`       |
| PyPI パッケージ | `https://pypi.org/project/{name}/`           |
| Go パッケージ   | `https://pkg.go.dev/{module}`                |
| Rust crate      | `https://crates.io/crates/{name}`            |

## WebSearch (優先度 5)

### 対象ユースケース

- 最新のリリース情報を確認したい
- ベストプラクティスや推奨パターンを調べたい
- 特定のエラーや問題の解決策を探したい

### 効果的な検索クエリ

| 目的               | クエリテンプレート                                      |
| ------------------ | ------------------------------------------------------- |
| 最新リリース       | "{tool} latest release {year}"                          |
| マイグレーション   | "{tool} migration guide {from_version} to {to_version}" |
| ベストプラクティス | "{tool} best practices {year}"                          |
| エラー解決         | "{tool} {error_message} solution"                       |
| 比較               | "{tool_a} vs {tool_b} {year}"                           |

### 検索のコツ

- 年を含めて最新の情報を優先する (例: "2026")
- 公式ソースを優先するため site: フィルターを活用
- 具体的なキーワードで絞り込む
- 英語で検索すると情報量が多い

## 例外的な優先順位

以下の内容については、通常の優先順位に関わらず専用 MCP を最優先で使用する:

- **terraform に関する内容**: terraform MCP (`mcp__terraform__*`) が最優先
- **Google Cloud に関する内容**: google-developer-knowledge MCP (`mcp__google-developer-knowledge__*`) が最優先

## フォールバック戦略

上位ソースで情報が得られない場合のフォールバックパターン:

### パターン 1: ライブラリの使い方

```
context7 MCP で API ドキュメントを取得
  ↓ 不十分な場合
deepwiki MCP でリポジトリの内部ドキュメントを確認
  ↓ 不十分な場合
WebFetch で公式ドキュメントページを直接取得
  ↓ 不十分な場合
WebSearch で関連記事やチュートリアルを検索
```

### パターン 2: 最新バージョン情報

```
catch-up:latest-version agent を起動 (gh CLI 優先)
  ↓ 不十分な場合
WebFetch で GitHub Releases ページを取得
  ↓ 不十分な場合
WebSearch で最新リリース情報を検索
```

### パターン 3: エラー・問題解決

```
LSP でコードベース内の関連コードを調査
  ↓ 不十分な場合
deepwiki MCP で関連リポジトリの Issues/Wiki を確認
  ↓ 不十分な場合
WebSearch でエラーメッセージを検索
```
