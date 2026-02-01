# Git Plugin

Git/GitHub 操作を効率化する Claude Code plugin です。

## 機能

### Skills

| スキル                | 説明                                                          |
| --------------------- | ------------------------------------------------------------- |
| `/git:commit`         | 全変更をステージングし、Conventional Commits 形式でコミット   |
| `/git:pr-create`      | PR を作成 (テンプレート準拠、ラベル自動選択、CODEOWNERS 対応) |
| `/git:pr-review`      | PR を複数 AI でレビューし、指摘箇所にコメントを投稿           |
| `/git:pr-fix`         | レビュー指摘を修正 (妥当性判断、コミット/返信前に承認)        |
| `/git:pr-update`      | PR のタイトルと description を最新化                          |
| `/git:review`         | ローカル変更を複数 AI でレビューし、指摘箇所を自動修正        |
| `japanese-text-style` | 日本語テキストのスペース・句読点・括弧・文体ルール            |
| `/git:pr-ci`          | CI 失敗の調査・修正 (ci-analyzer subagent で原因分析)         |
| `code-review`         | 複数 AI (Claude/Codex/Gemini) へのレビュー依頼方法            |

### Agents

| エージェント      | 説明                                                                    |
| ----------------- | ----------------------------------------------------------------------- |
| `ci-analyzer`     | CI 失敗のログを取得・分析し、原因と修正方針を構造化レポートで返却       |
| `commit-proposer` | 変更差分を分析し、commitlint 設定に準拠したコミットメッセージ候補を提案 |

## インストール

### マーケットプレースから (推奨)

```bash
# 1. マーケットプレースを追加
/plugin marketplace add ronnnnn/cc

# 2. プラグインマネージャーを開く
/plugin

# 3. Discover タブで "git" を選択してインストール
```

または CLI から直接インストール:

```bash
/plugin install git@cc
```

**インストールスコープ:**

| スコープ  | 説明                                   |
| --------- | -------------------------------------- |
| `user`    | 全プロジェクトで使用可能 (デフォルト)  |
| `project` | このリポジトリの全コラボレーターで共有 |
| `local`   | このリポジトリで自分のみ使用           |

スコープを指定してインストール:

```bash
claude plugin install git@cc --scope project
```

詳細は [Discover and install prebuilt plugins through marketplaces](https://code.claude.com/docs/en/discover-plugins) を参照。

## 使い方

### コミット

```bash
/git:commit  # 全変更をステージングしてコミット
```

**ワークフロー:**

1. 全変更 (unstaged + untracked) を自動ステージング
2. **commit-proposer subagent** が差分分析・commitlint 確認・メッセージ候補生成
3. **コミットメッセージ候補を最大 3 つ提示** (推奨度順)
4. **ユーザー承認を取得**
5. 選択されたメッセージでコミット実行

### PR 作成

```bash
/git:pr-create              # 現在のブランチから Draft PR を作成
/git:pr-create --base main  # ベースブランチを指定
```

**自動処理:**

- **常に Draft PR として作成**
- PR タイトルは **Conventional Commits** 形式 (commitlint 設定があれば準拠)
- `.github/PULL_REQUEST_TEMPLATE.md` に準拠した description
- リポジトリのラベルから適切なものを自動選択
- `.github/CODEOWNERS` から Reviewer を自動設定
- Assignee は PR 作成者自身
- **完了後、ブラウザで PR を自動的に開く**

### レビュー指摘の修正

```bash
/git:pr-fix      # 現在のブランチの PR を修正
/git:pr-fix 123  # PR #123 を修正
```

**ワークフロー:**

1. 未解決 (unresolved) のレビューコメントを取得
2. 各コメントの妥当性を判断
3. 修正が必要なもののみ修正
4. **commit-proposer subagent** でコミットメッセージ生成
5. **コミット前にユーザー承認を取得**
6. Conventional Commits 形式でコミット実行
7. **返信コメント前にユーザー承認を取得**
8. レビューコメントに返信

### PR タイトルと description の更新

```bash
/git:pr-update      # 現在のブランチの PR を更新
/git:pr-update 123  # PR #123 を更新
```

**自動処理:**

- 全コミットを確認し、タイトルと description が古くなっていれば更新
- タイトルは **Conventional Commits** 形式 (commitlint 設定があれば準拠)
- description はテンプレートまたは既存フォーマットに準拠
- **タイトルと description をまとめて確認・更新**

### PR レビュー

```bash
/git:pr-review                                    # 現在のブランチの PR をレビュー
/git:pr-review 123                                # PR #123 をレビュー
/git:pr-review https://github.com/owner/repo/123 # URL で指定
```

**ワークフロー:**

1. PR の差分を取得
2. **並列で複数 AI (Claude/Codex MCP/Gemini MCP) にレビュー依頼**
3. 結果を統合・重複排除
4. インラインコメント案を作成
5. **コメント投稿前にユーザー承認を取得**
6. 承認後、PR にコメントを投稿

### CI 失敗の調査・修正

```bash
/git:pr-ci      # 現在のブランチの PR の CI を調査・修正
/git:pr-ci 123  # PR #123 の CI を調査・修正
```

**ワークフロー:**

1. PR の CI チェック状態を取得
2. **ci-analyzer subagent** が失敗ログを分析し原因を特定
3. 分析結果と修正計画をユーザーに提示
4. **修正方針の承認を取得**
5. コードを修正しローカルで検証
6. **コミット前にユーザー承認を取得**
7. Conventional Commits 形式でコミット・プッシュ

### ローカルレビュー

```bash
/git:review  # ローカルの変更 (staged/unstaged) をレビュー
```

**ワークフロー:**

1. ローカル差分を取得 (staged + unstaged)
2. **並列で複数 AI (Claude/Codex MCP/Gemini MCP) にレビュー依頼**
3. 結果を統合・重複排除
4. 修正が必要なものを**承認なしで自動修正**
5. **指摘がなくなるまでレビュー・修正を繰り返す**
6. 修正サマリを報告

## 前提条件

- **Git** がインストールされていること
- PR 関連コマンドには **gh CLI** が必要

```bash
# Git 確認
git --version

# gh CLI 確認 (PR コマンド用)
gh --version
gh auth status
```

## ファイル構造

```
git/
├── .claude-plugin/
│   └── plugin.json          # Plugin マニフェスト
├── skills/
│   ├── commit/
│   │   └── SKILL.md         # コミットスキル
│   ├── pr-create/
│   │   └── SKILL.md         # PR 作成スキル
│   ├── pr-review/
│   │   └── SKILL.md         # PR レビュースキル
│   ├── pr-fix/
│   │   └── SKILL.md         # レビュー修正スキル
│   ├── pr-update/
│   │   └── SKILL.md         # Description 更新スキル
│   ├── review/
│   │   └── SKILL.md         # ローカルレビュースキル
│   ├── code-review/
│   │   ├── SKILL.md         # 複数 AI レビューガイド
│   │   └── references/
│   │       └── mcp-prompts.md  # MCP プロンプトリファレンス
│   ├── japanese-text-style/
│   │   └── SKILL.md         # 日本語テキストスタイルガイド
│   └── pr-ci/
│       └── SKILL.md         # CI 失敗の調査・修正スキル
├── agents/
│   ├── ci-analyzer.md       # CI 失敗分析エージェント
│   └── commit-proposer.md   # コミットメッセージ提案エージェント
└── README.md
```

## 技術仕様

| 項目             | 内容                                   |
| ---------------- | -------------------------------------- |
| **ツール**       | git, gh CLI (PR 用)                    |
| **言語**         | 日本語                                 |
| **コミット形式** | Conventional Commits / commitlint 準拠 |

## トラブルシューティング

### gh CLI が認証されていない

```bash
gh auth login
```

### PR が見つからない

現在のブランチに関連する PR がない場合は、PR 番号を明示的に指定してください:

```bash
/git:pr-fix 123
```

### コミットする変更がない

```
コミットする変更がありません。
```

### pre-commit hook が失敗した

hook のエラーを確認し、問題を修正してから再度コマンドを実行してください。
