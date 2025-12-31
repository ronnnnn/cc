---
name: Conventional Commit ガイド
description: このスキルは、「コミットメッセージの形式は？」「conventional commit の書き方」「commitlint の設定を確認して」「PR タイトルの形式」「type や scope の一覧」「コミットメッセージのルール」などを質問した際、または PR 作成やコミット時に適切なメッセージ形式を決定する際に使用する。Conventional Commits 規約と commitlint 設定に基づいたメッセージ形式のガイダンスを提供する。
version: 0.1.0
---

# Conventional Commit ガイド

Conventional Commits 規約と commitlint 設定に基づいたコミットメッセージ・PR タイトルの形式ガイド。

## 概要

このスキルは以下の場面で使用する:

- PR タイトルの決定 (`/github:pr-create`)
- コミットメッセージの作成 (`/github:pr-fix`)
- コミットメッセージ形式の質問への回答

## commitlint 設定の確認手順

### 1. 設定ファイルの検索

プロジェクトルートで以下のファイルを探す:

```bash
# commitlint 設定ファイルを探す (優先順位順)
ls -la commitlint.config.{js,cjs,mjs,ts,cts} 2>/dev/null
ls -la .commitlintrc{,.json,.yaml,.yml,.js,.cjs,.mjs,.ts,.cts} 2>/dev/null
```

package.json 内の設定も確認:

```bash
grep -A 20 '"commitlint"' package.json 2>/dev/null
```

### 2. 設定ファイルの解析

設定ファイルが見つかった場合、Read ツールで内容を確認し、以下のルールを抽出する:

| ルール              | 説明                  | 値の例                            |
| ------------------- | --------------------- | --------------------------------- |
| `type-enum`         | 許可される type 一覧  | `['feat', 'fix', 'docs', ...]`    |
| `scope-enum`        | 許可される scope 一覧 | `['core', 'ui', 'api', ...]`      |
| `scope-empty`       | scope の必須/任意     | `[2, 'never']` = 必須             |
| `subject-case`      | subject の書式        | `['lower-case', 'sentence-case']` |
| `header-max-length` | ヘッダー最大文字数    | `[2, 'always', 100]`              |

### 3. extends の解析

`extends` フィールドがある場合、継承元の設定を考慮する:

**`@commitlint/config-conventional` の場合:**

```
type: build, chore, ci, docs, feat, fix, perf, refactor, revert, style, test
scope: 任意
```

**`@commitlint/config-angular` の場合:**

```
type: build, ci, docs, feat, fix, perf, refactor, style, test
scope: 任意
```

### 4. 設定がない場合のデフォルト

commitlint 設定ファイルがない場合は、標準の Conventional Commits 形式を使用:

```
type: feat, fix, docs, style, refactor, perf, test, chore, build, ci, revert
scope: 任意 (変更対象のモジュール/ディレクトリから推測)
```

## メッセージ形式

### 基本形式

```
<type>(<scope>): <subject>

<body>

<footer>
```

### 形式の決定ルール

| 条件                                      | 形式                                                    |
| ----------------------------------------- | ------------------------------------------------------- |
| `scope-empty: [2, 'never']` (scope 必須)  | `<type>(<scope>): <subject>`                            |
| `scope-empty: [2, 'always']` (scope 禁止) | `<type>: <subject>`                                     |
| その他 (scope 任意)                       | `<type>: <subject>` または `<type>(<scope>): <subject>` |

### type の選択基準

| type       | 使用場面                                            |
| ---------- | --------------------------------------------------- |
| `feat`     | 新機能の追加                                        |
| `fix`      | バグ修正                                            |
| `docs`     | ドキュメントのみの変更                              |
| `style`    | コードの意味に影響しない変更 (空白、フォーマット等) |
| `refactor` | バグ修正でも機能追加でもないコード変更              |
| `perf`     | パフォーマンス改善                                  |
| `test`     | テストの追加・修正                                  |
| `chore`    | ビルドプロセスやツールの変更                        |
| `build`    | ビルドシステムや外部依存関係に影響する変更          |
| `ci`       | CI 設定ファイルやスクリプトの変更                   |
| `revert`   | 以前のコミットを取り消す                            |

### scope の推測方法

変更されたファイルのパスから scope を推測する:

1. **単一ディレクトリの変更**: そのディレクトリ名を scope に
   - `src/auth/*.ts` → `auth`
   - `components/Button/*.tsx` → `button`

2. **複数ディレクトリの変更**: 共通の親ディレクトリまたは省略
   - `src/auth/*.ts` + `src/api/*.ts` → `auth,api` または省略

3. **設定ファイルの変更**: 該当する scope または省略
   - `package.json`, `tsconfig.json` → `deps` または省略

### subject の書き方

- 命令形で書く (「追加する」ではなく「追加」)
- 先頭を小文字にする (英語の場合)
- 末尾にピリオドを付けない
- 50 文字以内を目安

**例:**

- `feat(auth): ログイン機能を追加`
- `fix(api): null チェックを追加`
- `docs: README にインストール手順を追記`

## PR タイトルへの適用

PR タイトルにも同じ Conventional Commits 形式を適用する:

```
feat(auth): ユーザー認証機能を追加
fix(api): エラーハンドリングを修正
docs: API ドキュメントを更新
```

## コミットメッセージへの適用

### 単純な修正

```
fix(auth): null ポインタ例外を修正
```

### レビュー指摘対応

```
fix: レビュー指摘に基づく修正

- 変数名を修正 (userData → user)
- エラーハンドリングを追加
- 不要なコメントを削除
```

### 複数の修正をまとめる場合

```
fix: コードレビュー対応

Co-authored-by: reviewer <reviewer@example.com>

- src/auth.ts: 認証ロジックを修正
- src/api.ts: エラーハンドリングを追加
```

## 追加リソース

詳細な commitlint 設定リファレンスは以下を参照:

- **`references/commitlint-rules.md`** - commitlint の全ルール一覧と設定例
