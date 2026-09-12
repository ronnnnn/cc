# CLAUDE.md

Claude Code プラグインのマーケットプレースおよびプラグイン群。`plugins/` 配下に各プラグインを格納。

## 開発コマンド

```bash
bun i                                    # 依存関係インストール (bun 必須)
bun fmt                                  # フォーマット
claude plugin validate .                 # マーケットプレース検証
claude plugin validate ./plugins/<name>  # 個別プラグイン検証
(cd plugins/<name> && claude plugin eval . --ablation none)  # スキル発火の eval (モデル呼び出しあり)
```

## Evals

`plugins/<name>/evals/<case>/` に `prompt.md` (依頼文) と `graders/*.md` (`tool_used: Skill` グレーダー) を置く。ケース名とディレクトリ名はスキル名に揃え、`tags` にもスキル名を含める (CI が `--tag` で選ぶため)。スキルを追加・description を変更したら対応するケースも追加・更新する (CI はケースの無いスキル変更を失敗させる)。model から起動できないスキル (`disable-model-invocation: true`) のみ対象外 (`user-invocable: false` は model から起動されるので対象)。CI (`plugin-evals.yaml`) は PR を開いたとき (opened のみ) に、変更されたスキルのケースだけを `--ablation none --threshold 0.6` (3 run 中 2 回発火で合格) で実行する (対象判定は `.github/scripts/detect-eval-targets.sh`)。認証は Workload Identity Federation (リポジトリ変数 `ANTHROPIC_*_ID`)。

## コミット規約

Conventional Commits 形式 (`commitlint.config.mjs` 参照)

例: `feat(git): PR 作成スキルを追加`

## ツールチェーン

- **パッケージマネージャー**: bun (npm/yarn 不可)
- **Git hooks**: lefthook (pre-commit: prettier + zizmor, commit-msg: commitlint)
