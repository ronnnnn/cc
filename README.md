# cc

[Claude Code](https://code.claude.com/) プラグインのマーケットプレースです。Git/GitHub ワークフロー、CLAUDE.md 管理、開発支援など、日常の開発体験を向上させるプラグインを提供します。

## プラグイン一覧

| プラグイン                     | 説明                                                                       |
| :----------------------------- | :------------------------------------------------------------------------- |
| [git](./plugins/git)           | Git/GitHub ワークフロー (コミット、PR 作成・レビュー・修正・監視、CI 分析) |
| [claude](./plugins/claude)     | CLAUDE.md の作成・更新・品質管理、`.claude/rules` の作成                   |
| [catch-up](./plugins/catch-up) | 技術・ツール・フレームワークの最新バージョン取得と技術調査                 |
| [dev](./plugins/dev)           | 開発支援 (コードコメント追加、行動計画作成、並列タスク実行)                |
| [hookify](./plugins/hookify)   | ユーザー定義ルールで Claude Code のアクションを警告・ブロック              |
| [caffeine](./plugins/caffeine) | macOS のスリープ・スクリーンセーバーを自動抑制                             |

## インストール

### マーケットプレースの追加

Claude Code 内で以下を実行し、マーケットプレースを登録します。

```shell
/plugin marketplace add ronnnnn/cc
```

### プラグインのインストール

個別のプラグインをインストールします。

```shell
/plugin install git@cc
```

インストール後、`/reload-plugins` でプラグインを有効化してください。

### 全プラグインの一覧

登録済みのプラグインは `/plugin` の **Discover** タブから確認できます。

## 使い方

各プラグインのスキルはプラグイン名で名前空間化されています。

```shell
/git:commit          # 変更をコミット
/git:pr-create       # Draft PR を作成
/git:pr-review       # PR をレビュー
/claude:init         # CLAUDE.md を新規作成
/claude:update       # CLAUDE.md を精査・最適化
/dev:plan            # 行動計画を作成
/dev:do              # 複数タスクを並列実行
/hookify:hookify     # hookify ルールを作成
/catch-up:tech-research # 技術調査を実行
```

詳細は各プラグインの README を参照してください。

## 開発

### 前提条件

- [asdf](https://asdf-vm.com/) または [mise](https://mise.jdx.dev/)
- [Bun](https://bun.sh/)
- [Claude Code](https://code.claude.com/)

### セットアップ

```bash
asdf install   # または mise install
bun i
```

### コマンド

```bash
bun fmt                                  # フォーマット
claude plugin validate .                 # マーケットプレース検証
claude plugin validate ./plugins/<name>  # 個別プラグイン検証
```

### ローカルテスト

開発中のプラグインを `--plugin-dir` で読み込んでテストできます。

```bash
claude --plugin-dir ./plugins/git
```

### スキル発火の回帰テスト (evals)

各プラグインの `evals/` に、自然な依頼文で意図したスキルが発火するか (および無関係な依頼で発火しないか) を検証するケースを置いています。実行にはモデル呼び出しが伴い、利用中のアカウントのコストとして計上されます。

```bash
cd plugins/<name>
claude plugin eval . --ablation none                      # 全ケース (3 runs)
claude plugin eval . --ablation none --case <case> --runs 1  # 1 ケースだけ素早く確認
```

CI では `plugins/**` に変更がある PR を開いたとき (opened のみ、push ごとには実行しない) に `.github/workflows/plugin-evals.yaml` が実行されます。対象は `.github/scripts/detect-eval-targets.sh` が変更ファイルから決めます: 変更されたスキル (`skills/<name>/`) と変更されたケース (`evals/<name>/`) に対応するケースだけを `--tag` で選び、過剰発火を確認する `ignores-unrelated-request` を常に加えます。hooks や agents など共有部分が変わったプラグインは suite 全体を実行します。対応するケースが無いスキルを変更した場合、ケースを削除・rename して対応が外れた場合、否定ケース `ignores-unrelated-request` が無い場合は CI が失敗します (frontmatter に `disable-model-invocation: true` を持つ、model から起動できないスキルは除く)。`evals/mocks/` など共有アセットの変更は suite 全体を実行します。結果はプラグインごとの表 (ケース、score、合否、run ごとの P/F) にまとめて PR にコメントし、JSON と HTML レポートは artifact に保存します。追加で検証したい場合は Actions から workflow_dispatch で任意のプラグインの suite 全体を実行できます。認証は API キーではなく [Workload Identity Federation](https://platform.claude.com/docs/en/manage-claude/wif-providers/github-actions) を使い、GitHub の OIDC トークンを Claude API の短命トークンに交換します。Claude Console 側で GitHub Actions 用の issuer、service account、federation rule を作成し、リポジトリ変数 `ANTHROPIC_FEDERATION_RULE_ID`、`ANTHROPIC_ORGANIZATION_ID`、`ANTHROPIC_SERVICE_ACCOUNT_ID` (必要なら `ANTHROPIC_WORKSPACE_ID`) を設定してください。

### コミット規約

[Conventional Commits](https://www.conventionalcommits.org/) 形式に従います。

```
feat(git): PR 作成スキルを追加
fix(claude): CLAUDE.md 生成時のテンプレート修正
```

## ライセンス

[MIT](./LICENSE)
