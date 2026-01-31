---
name: conventional-commit
description: このスキルは、「コミットメッセージの形式は？」「conventional commit の書き方」「commitlint の設定を確認して」「PR タイトルの形式」「type や scope の一覧」「コミットメッセージのルール」などを質問した際、または PR 作成やコミット時に適切なメッセージ形式を決定する際に使用する。Conventional Commits 規約と commitlint 設定に基づいたメッセージ形式のガイダンスを提供する。
version: 0.1.0
---

# Conventional Commit ガイド

Conventional Commits 規約と commitlint 設定に基づいたコミットメッセージ・PR タイトルの形式ガイド。

## 概要

このスキルは以下の場面で使用する:

- PR タイトルの決定 (`/git:pr-create`)
- コミットメッセージの作成 (`/git:pr-fix`)
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

#### 1.1. 継承先 (子) ファイルの探索

設定ファイルが見つかった場合、そのファイルを `extends` で継承している別のファイルがローカルに存在しないか確認する。

**探索手順:**

```bash
# 例: commitlint.config.mjs が見つかった場合
# そのファイルを継承している可能性のあるファイルを探す
ls -la commitlint.config.*.{js,cjs,mjs,ts,cts} 2>/dev/null
ls -la .commitlintrc.*.{json,yaml,yml,js,cjs,mjs,ts,cts} 2>/dev/null
```

**見つかったファイルの extends を確認:**

```bash
# 各候補ファイルの extends フィールドを確認
grep -l "extends.*commitlint.config.mjs" commitlint.config.*.mjs 2>/dev/null
```

または Read ツールで内容を確認し、`extends` が元の設定ファイルを指しているか確認。

**継承先ファイルの例:**

```javascript
// commitlint.config.local.mjs - commitlint.config.mjs を継承
export default {
  extends: ['./commitlint.config.mjs'],
  rules: {
    // ローカル用のカスタムルール
    'scope-enum': [2, 'always', ['frontend', 'backend', 'shared']],
  },
};
```

**継承先が見つかった場合:**

- 継承先ファイル（子）を最終的な設定ファイルとして使用
- 継承チェーン: 子 → 親 → 親の親... の順でルールをマージ

**典型的な継承先ファイル名パターン:**

| ベースファイル          | 継承先の候補                                                  |
| ----------------------- | ------------------------------------------------------------- |
| `commitlint.config.mjs` | `commitlint.config.local.mjs`, `commitlint.config.custom.mjs` |
| `commitlint.config.js`  | `commitlint.config.local.js`, `commitlint.config.dev.js`      |
| `.commitlintrc.json`    | `.commitlintrc.local.json`                                    |

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

`extends` フィールドがある場合、継承元の設定を再帰的に解決する。

#### 3.1. extends の形式

```javascript
// 単一の継承
extends: ['@commitlint/config-conventional']

// 複数の継承 (後の設定が優先)
extends: ['./commitlint.base.js', '@commitlint/config-conventional']

// 文字列形式 (配列でない場合)
extends: '@commitlint/config-conventional'
```

#### 3.2. 継承元の解決手順

`extends` で指定された各エントリを以下の順序で解決する:

**1. 相対パス (`./` または `../` で始まる) の場合:**

```bash
# 設定ファイルからの相対パスでファイルを読み込む
cat ./commitlint.base.js
```

**2. npm パッケージの場合:**

```bash
# パッケージのメインファイルを探す
# @scope/package 形式
cat node_modules/@commitlint/config-conventional/index.js 2>/dev/null || \
cat node_modules/@commitlint/config-conventional/lib/index.js 2>/dev/null

# package 形式
cat node_modules/commitlint-config-custom/index.js 2>/dev/null
```

**3. package.json の main フィールドを確認:**

```bash
# パッケージのエントリポイントを確認
cat node_modules/@scope/package/package.json | grep '"main"'
```

#### 3.3. 再帰的な継承チェーンの解決

継承元の設定ファイルにも `extends` がある場合は、再帰的に解決する:

```
commitlint.config.js
  └── extends: ['./commitlint.base.js']
        └── extends: ['@commitlint/config-conventional']
              └── (既知のプリセット: 解決完了)
```

**解決の優先順位** (後の設定が前の設定を上書き):

1. 継承元の継承元... (再帰的に最深部から)
2. 継承元の設定
3. 現在の設定ファイル

#### 3.4. 既知のプリセット

以下のプリセットは node_modules を参照せずに既知の値を使用:

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

#### 3.5. ルールのマージ

継承チェーンで見つかったルールは以下のようにマージする:

```javascript
// 例: 継承元
rules: {
  'type-enum': [2, 'always', ['feat', 'fix', 'docs']]
}

// 例: 現在の設定 (継承元を上書き)
rules: {
  'type-enum': [2, 'always', ['feat', 'fix', 'docs', 'chore', 'refactor']]
}
```

- 同じルールキーがある場合: 現在の設定が優先
- 継承元にのみあるルール: そのまま継承

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
