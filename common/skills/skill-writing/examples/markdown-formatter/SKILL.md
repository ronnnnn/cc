---
name: markdown-formatter
description: ベストプラクティスに従って Markdown ファイルをフォーマット・標準化します。ユーザーが Markdown ドキュメントのフォーマット、クリーンアップ、または標準化を依頼したときに使用します。
---

# Markdown Formatter

## 概要

Markdown ファイルを標準的なフォーマットに整形するスキルです。見出しレベルの修正、リンク形式の統一、コードブロックの適切なフォーマットなどを行います。

## 使用方法

### 基本的なフォーマット

Markdown ファイルを読み込み、以下のルールに従ってフォーマットします：

1. **見出し**: ATX スタイル（`#`）を使用、Setext スタイル（`===`）は変換
2. **リスト**: インデントは2スペース
3. **コードブロック**: 言語指定を必ず含める
4. **リンク**: 参照スタイルではなくインラインスタイルを使用
5. **空行**: 見出しの前後に1行ずつ空行を挿入

### フォーマット手順

```bash
# 1. ファイルを読み込む
Read the Markdown file

# 2. フォーマットルールを適用
- Convert Setext headings to ATX style
- Standardize list indentation
- Add language tags to code blocks
- Convert reference links to inline
- Add blank lines around headings

# 3. フォーマット済みファイルを保存
Write the formatted content back to the file
```

## 例

### 例 1: 見出しのフォーマット

**入力**:

```markdown
# Title

## Subtitle

### Section
```

**出力**:

```markdown
# Title

## Subtitle

### Section
```

### 例 2: コードブロックの修正

**入力**:

```markdown
コード例:
```

function hello() {
console.log("Hello");
}

```

```

**出力**:

````markdown
コード例:

```javascript
function hello() {
  console.log("Hello");
}
```
````

### 例 3: リンクの標準化

**入力**:

```markdown
[link text][1]

[1]: https://example.com
```

**出力**:

```markdown
[link text](https://example.com)
```

## フォーマットルール詳細

### 見出し

- ✅ DO: `# Heading 1`, `## Heading 2`
- ❌ DON'T: Setext スタイル（`===`, `---`）

### リスト

- ✅ DO: 2スペースインデント
- ❌ DON'T: タブまたは4スペースインデント

### コードブロック

- ✅ DO: 言語指定を含める ` ```python `
- ❌ DON'T: 言語指定なし ` ``` `

### 空行

- 見出しの前: 1行
- 見出しの後: 1行
- リストの前: 1行
- コードブロックの前後: 1行

## トラブルシューティング

### 問題: フォーマット後にリンクが壊れる

**原因**: 参照スタイルのリンクをインラインに変換する際、参照が正しくマッピングされていない

**解決策**: 変換前にすべての参照リンクとその定義を確認し、正しくマッピングする

### 問題: コードブロック内の内容が変更される

**原因**: フォーマットルールがコードブロック内にも適用されている

**解決策**: コードブロックの内容は変更しない。言語タグの追加とインデント調整のみ行う

## 制限事項

- HTML タグを含む Markdown は部分的にサポート
- 複雑なテーブルフォーマットは手動調整が必要な場合がある
- カスタム Markdown 拡張機能はサポート外

## バージョン履歴

### v1.0.0 (2025-10-22)

- 初回リリース
- 基本的なフォーマット機能
- 見出し、リスト、コードブロック、リンクの標準化
