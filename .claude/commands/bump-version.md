---
description: プラグインまたはマーケットプレースのバージョンを更新
---

プラグインまたはマーケットプレースのバージョンを更新してください。

## 引数

- `$ARGUMENTS` の形式: `<target> <version>` (省略可能)
  - `<target>`: プラグイン名 (git, claude) または `marketplace`
  - `<version>`: 新しいバージョン (例: 1.6.0)

## 実行手順

### 引数がない場合: 変更差分から推測

1. `git diff --cached --name-only` と `git diff --name-only` で変更ファイル一覧を取得
2. 変更されたファイルのパスから target を推測:
   - `git/` 配下のファイルが変更 → target は `git`
   - `claude/` 配下のファイルが変更 → target は `claude`
   - 複数のプラグインが変更されている場合 → 各プラグインを順に更新
   - `.claude-plugin/marketplace.json` のみ変更 → target は `marketplace`
3. 現在のバージョンを取得し、変更の種類に応じて version を推測:
   - 互換性のない破壊的変更 → メジャーバージョンをインクリメント (1.5.0 → 2.0.0)
   - 新機能追加 → マイナーバージョンをインクリメント (1.5.0 → 1.6.0)
   - バグ修正 → パッチバージョンをインクリメント (1.5.0 → 1.5.1)
4. 推測した target と version をユーザーに提示し、確認を求める

### 引数がある場合: 指定された値を使用

引数で `<target>` と `<version>` が指定されている場合は、その値を使用する。

### プラグインのバージョン更新の場合 (target がプラグイン名)

1. `<target>/.claude-plugin/plugin.json` の `version` を `<version>` に更新
2. `.claude-plugin/marketplace.json` の `plugins` 配列内で、`name` が `<target>` と一致するプラグインの `version` を `<version>` に更新
3. `.claude-plugin/marketplace.json` の `metadata.version` のパッチバージョンをインクリメント (例: 1.6.0 → 1.6.1)

### マーケットプレースのバージョン更新の場合 (target が marketplace)

1. `.claude-plugin/marketplace.json` の `metadata.version` を `<version>` に更新

## 注意事項

- プラグインのバージョン更新時は、必ずマーケットプレースのバージョンも更新すること
- セマンティックバージョニング (semver) 形式を使用すること
- 更新完了後、変更内容を報告すること
