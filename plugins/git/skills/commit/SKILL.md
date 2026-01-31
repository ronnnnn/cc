---
name: commit
description: 全変更をステージングし、Conventional Commits 形式でコミットする。commitlint 設定があれば準拠。コミット前にユーザー承認を取る。
allowed-tools:
  - Bash
  - Read
  - Glob
  - Grep
  - TaskCreate
  - TaskUpdate
  - TaskList
  - AskUserQuestion
version: 0.1.0
---

# コミットワークフロー

全変更 (staged + unstaged) をステージングし、Conventional Commits 形式でコミットする。

## 重要な原則

1. **コミットメッセージの言語は対象リポジトリに従う** - 既存のコミット履歴 (`git log`) を確認し、リポジトリで使用されている言語 (日本語/英語等) に合わせる
2. **日本語でコミットメッセージを書く場合は `japanese-text-style` スキルに従う** - スペース、句読点、括弧のルールを適用する
3. **全変更を一括でコミット** - unstaged も untracked も全てステージング
4. **コミットメッセージは commitlint 設定 / Conventional Commits に準拠する**
5. **pre-commit hook がある場合は、それに従う**
6. **機密情報 (.env, credentials 等) がステージングされていないか確認**

## 作業開始前の準備

**必須:** 作業開始前に TaskCreate ツールで以下のステップをタスクとして登録する:

```
TaskCreate({ subject: "変更状態の確認", description: "git status で現在の変更状態を確認", activeForm: "変更状態を確認中" })
TaskCreate({ subject: "全変更のステージング", description: "git add -A で全変更をステージング", activeForm: "変更をステージング中" })
TaskCreate({ subject: "commitlint 設定の確認", description: "commitlint 設定ファイルを探索・解析", activeForm: "commitlint 設定を確認中" })
TaskCreate({ subject: "変更内容の分析", description: "git diff --cached で変更内容を分析", activeForm: "変更内容を分析中" })
TaskCreate({ subject: "コミットメッセージ候補の提示", description: "Conventional Commits 形式で候補を生成", activeForm: "コミットメッセージ候補を提示中" })
TaskCreate({ subject: "コミット前の承認確認", description: "ユーザーにコミットメッセージの承認を求める", activeForm: "コミット承認を確認中" })
TaskCreate({ subject: "コミットの実行", description: "承認されたメッセージでコミットを実行", activeForm: "コミットを実行中" })
TaskCreate({ subject: "完了報告", description: "コミット結果を報告", activeForm: "完了報告を作成中" })
```

各ステップの開始時に TaskUpdate で `in_progress` に、完了時に `completed` に更新する。

## 実行手順

### 1. 変更状態の確認

```bash
# 現在の変更状態を確認
git status

# 変更がない場合は終了
```

**変更がない場合:**

```
コミットする変更がありません。
```

### 2. 全変更のステージング

```bash
# 全変更をステージング (unstaged + untracked)
git add -A

# ステージング結果を確認
git status
```

### 3. commitlint 設定の確認

**`conventional-commit` スキルを参照して、コミットメッセージの形式を決定する。**

```bash
# commitlint 設定ファイルを探す
ls -la commitlint.config.{js,cjs,mjs,ts,cts} 2>/dev/null || \
ls -la .commitlintrc{,.json,.yaml,.yml,.js,.cjs,.mjs,.ts,.cts} 2>/dev/null || \
grep -l '"commitlint"' package.json 2>/dev/null
```

設定ファイルが見つかった場合:

**1. 継承先 (子) ファイルの探索:**

```bash
# 見つけた設定ファイルを継承している別のファイルがないか確認
ls -la commitlint.config.*.{js,cjs,mjs,ts,cts} 2>/dev/null
ls -la .commitlintrc.*.{js,cjs,mjs,ts,cts} 2>/dev/null
```

継承先ファイルが見つかった場合は、そちらを最終的な設定ファイルとして使用。

**2. 設定ファイルの解析:**

Read ツールで内容を確認し、以下を抽出:

- `type-enum`: 許可される type 一覧
- `scope-enum`: 許可される scope 一覧
- `scope-empty`: scope の必須/任意
- `extends`: 継承元設定 (継承チェーンを再帰的に解決)

詳細な解析方法は `conventional-commit` スキルを参照。

### 4. 変更内容の分析

```bash
# ステージングされた変更の差分を確認
git diff --cached --stat

# 変更されたファイル一覧
git diff --cached --name-only

# 詳細な差分 (必要に応じて)
git diff --cached
```

変更内容を分析し、以下を判断する:

- 変更の種類 (新機能、バグ修正、リファクタリング等)
- 影響範囲 (scope の決定)
- 変更の要約

### 5. コミットメッセージ候補の提示

**Conventional Commits 形式でメッセージ候補を最大 3 つ生成し、推奨度順に提示する。**

**type の選択基準:**

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

**scope の推測:**

- 単一ディレクトリの変更 → そのディレクトリ名
- 複数ディレクトリの変更 → 共通の親または省略
- 設定ファイルの変更 → `config` または省略

**subject のルール:**

- 命令形で書く
- 先頭を小文字にする (英語の場合)
- 末尾にピリオドを付けない
- 50 文字以内を目安

### 6. コミット前の承認確認

**必須:** コミットメッセージ候補をユーザーに提示し、承認を求める。

**提示フォーマット:**

```
## コミットメッセージの確認

以下の変更をコミットします:

**変更ファイル:**
- path/to/file1.ts (+10, -5)
- path/to/file2.ts (+3, -1)

---

**コミットメッセージ候補** (推奨度順):

### 1. (推奨)
```

<type>(<scope>): <subject>

<body>
```

### 2.

```
<type>(<scope>): <subject>

<body>
```

### 3.

```
<type>(<scope>): <subject>

<body>
```

---

どのメッセージでコミットしますか？ (1/2/3、または修正案を入力)

````

**候補生成の考え方:**
- **候補 1 (推奨):** 変更内容を最も的確に表現するメッセージ
- **候補 2:** 別の観点 (異なる type や scope) からのメッセージ
- **候補 3:** より簡潔、または より詳細なメッセージ

ユーザーが修正案を入力した場合は、その内容でコミットを実行する。

### 7. コミットの実行

承認されたメッセージでコミットを実行:

```bash
git commit -m "$(cat <<'EOF'
<type>(<scope>): <subject>

<body>
EOF
)"
````

**例:**

```bash
git commit -m "$(cat <<'EOF'
feat(auth): ログイン機能を追加

- メール/パスワード認証を実装
- セッション管理を追加
EOF
)"
```

### 8. 完了報告

```bash
# コミット結果を確認
git log -1 --oneline
```

**報告フォーマット:**

```
## コミット完了

- **コミット:** <hash>
- **メッセージ:** <type>(<scope>): <subject>
- **変更ファイル数:** N
- **追加行数:** +X
- **削除行数:** -Y
```

## エラーハンドリング

### 変更がない場合

```
コミットする変更がありません。
```

### pre-commit hook が失敗した場合

1. hook のエラーメッセージを確認
2. 問題を修正
3. 再度 `git add -A` でステージング
4. コミットを再実行

### コンフリクトがある場合

```bash
# コンフリクトを解決後
git add -A
git commit
```
