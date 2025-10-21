---
name: skill-writing
description: 公式ドキュメントのベストプラクティスに従って Claude Code スキルを作成・更新します。ユーザーが新しいスキルの作成、既存スキルの更新、またはスキル作成のガイダンスを依頼したときに使用します。
---

# Skill Writing and Management

このスキルは、Claude Code の Agent Skills を作成・更新するための包括的なガイドとツールを提供します。公式ドキュメント ([Agent Skills Best Practices](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices)) および [公式仕様](https://github.com/anthropics/skills/blob/main/agent_skills_spec.md) に完全準拠しています。

## 🎯 このスキルを使用するタイミング

- ユーザーが新しいスキルの作成を依頼したとき
- 既存スキルの更新・改善を依頼されたとき
- スキル作成のベストプラクティスについて質問されたとき

## 📋 スキル作成ワークフロー

以下のチェックリストをコピーして進捗を追跡してください：

```
スキル作成進捗:
- [ ] STEP 1: 要件の明確化
- [ ] STEP 2: スキル名と説明の決定
- [ ] STEP 3: SKILL.md の構造設計
- [ ] STEP 4: プログレッシブディスクロージャの実装
- [ ] STEP 5: 具体例の作成
- [ ] STEP 6: スクリプトとツールの追加（必要な場合）
- [ ] STEP 7: allowed-tools の設定（必要な場合）
- [ ] STEP 8: 検証とテスト
```

### STEP 1: 要件の明確化

ユーザーから以下の情報を収集：

1. **スキルの目的**: 何を実現したいか？
2. **使用タイミング**: いつ Claude が自動的にこのスキルを呼び出すべきか？
3. **入力・出力**: どのような情報を受け取り、何を生成するか？
4. **追加リソース**: スクリプト、テンプレート、参照ドキュメントが必要か？

### STEP 2: スキル名と説明の決定

#### スキル名 (name)

- **形式**: `lowercase-hyphen-case`
- **文字制限**: 64 文字以内
- **制約**: 小文字の Unicode 英数字 + ハイフン (`-`) のみ
- **ディレクトリ名と一致**: スキル名はディレクトリ名と完全に一致させる
- **例**: `document-formatter`, `api-client-generator`, `test-suite-creator`

**重要な注記**:
公式ベストプラクティスドキュメントでは "Processing PDFs" のような Human-readable な形式が例示されていますが、実際の [公式仕様](https://github.com/anthropics/skills/blob/main/agent_skills_spec.md) と公式リポジトリの全例（`pdf`, `slack-gif-creator` など）は `lowercase-hyphen-case` を使用しています。**必ず `lowercase-hyphen-case` を使用してください**。

#### 説明 (description)

- **文字制限**: 1024 文字以内（200 文字以内推奨）
- **必須要素**:
  1. スキルが **何をするか** (What)
  2. **いつ使うべきか** (When)
- **三人称で記述**: "Excel ファイルを処理します..." (Good) / "私が手伝います..." (Bad)

**良い例**:

```yaml
description: Material-UI デザインパターンに従って TypeScript で React コンポーネントを作成します。ユーザーが新しい UI コンポーネントの作成、または既存コンポーネントの Material Design ガイドラインへの更新を依頼したときに使用します。
```

### STEP 3: SKILL.md の構造設計

**基本テンプレート**を使用:

```markdown
---
name: [skill-name-in-lowercase-hyphen-case]
description: [このスキルが何をするか]. [ユーザーが特定の条件や要求をしたとき]に使用します。
---

# [スキル名]

## 概要

[スキルの目的と主要機能を1-2文で]

## 使用方法

[基本的な使い方を簡潔に。コード例を含める場合は最小限に]

## 例

[最低1つの具体例]

## 追加リソース

[必要な場合のみ: 他のファイルへの参照]

## バージョン履歴

### v1.0.0 (YYYY-MM-DD)

- 初回リリース
```

**重要な注意事項**:

- SKILL.md の末尾にバージョン履歴を記載
- 日付は JST 基準で記載（`date +%Y-%m-%d` コマンドで取得）
- ライセンス表記は記載しない

詳細なテンプレートは `templates/skill_template.md` `templates/REFERENCE_template.md` を参照。

### STEP 4: プログレッシブディスクロージャの実装

**原則**: SKILL.md は簡潔に（500行以内）。詳細は別ファイルに分離。

**推奨構造**:

- **SKILL.md**: 80% のユースケースをカバーする基本情報
- **REFERENCE.md**: 詳細な技術仕様、API リファレンス
- **examples/**: 複数の具体例（個別ファイル）
- **templates/**: 再利用可能なテンプレート
- **scripts/**: 自動化スクリプト

**参照方法**:

```markdown
詳細なベストプラクティスについては [BEST_PRACTICES.md](BEST_PRACTICES.md) を参照してください。
```

**重要**: 参照は **1階層のみ** に保つ。SKILL.md → 詳細ファイル（直接参照）。
ネストした参照（SKILL.md → advanced.md → details.md）は避ける。

### STEP 5: 具体例の作成

**良い例の特徴**:

- **具体的**: 実際に動作するコード・手順
- **段階的**: ステップバイステップで説明
- **注釈付き**: なぜそうするのかを説明

**最低1つ、理想的には2-3個の例を含める**。

テンプレートと例は以下を参照:

- シンプルな例: `examples/markdown-formatter/`
- 複雑な例: `examples/complex-skill/`

### STEP 6: スクリプトとツールの追加

スキルに実行可能なスクリプトを含める場合:

**セキュリティ**:

- ✅ DO: 環境変数から機密情報を読み込む
- ❌ DON'T: API キー、パスワードをハードコード
- ✅ `.env.example` を提供

**スクリプトの利点**:

- Claude が生成するより信頼性が高い
- トークン節約（コンテキストに含めない）
- 一貫性の保証

### STEP 7: allowed-tools の設定

ユーザーに確認を求めずにツールを自動実行したい場合:

```yaml
---
name: my-skill
description: Skill description
allowed-tools:
  - Read
  - Write
  - Bash
---
```

**注意**: セキュリティリスクを考慮し、必要最小限のツールのみ許可。

### STEP 8: 検証とテスト

#### 自動検証

基本的な構造とフォーマットを自動チェック：

```bash
bash scripts/validate_skill.sh /path/to/skill

# または現在のディレクトリで
bash scripts/validate_skill.sh .
```

**自動検証項目**:

- SKILL.md の存在
- YAML frontmatter の構造（--- で囲まれているか）
- name フィールドの形式（lowercase-hyphen-case、64文字以内）
- name とディレクトリ名の一致
- description フィールドの存在と長さ（1024文字以内、200文字推奨）
- SKILL.md の行数（500行以内推奨）
- サポートされていないフィールドの検出（version, license）
- 基本的なセキュリティパターン（ハードコードされた認証情報）
- 参照ファイルの存在確認
- allowed-tools の形式

#### 手動チェックリスト

自動検証では確認できない品質項目をチェック：

**description の品質**:

- [ ] description に "何をするか" (What) が明記されている
- [ ] description に "いつ使うか" (When) が明記されている
- [ ] description が三人称で記述されている（"〜します" ○ / "私が〜" ✗）
- [ ] description が簡潔で明確（200文字以内推奨）

**コンテンツの品質**:

- [ ] 具体的な例が最低1つ含まれている
- [ ] 例が実際に動作する内容である
- [ ] 用語が一貫して使用されている（同じ概念に異なる用語を使っていない）
- [ ] 説明が簡潔である（Claude が知っている情報を重複して説明していない）

**構造の品質**:

- [ ] プログレッシブディスクロージャが適切に使用されている（詳細は別ファイル）
- [ ] ファイル参照が1階層のみ（SKILL.md → 詳細ファイル、深いネストなし）
- [ ] 参照ファイルに目次がある（100行以上のファイルの場合）

**セキュリティ**:

- [ ] 環境変数から機密情報を読み込んでいる（ハードコードしていない）
- [ ] .env.example が提供されている（環境変数を使う場合）
- [ ] スクリプトにエラーハンドリングがある（スクリプトを含む場合）

## 🎨 ベストプラクティス概要

詳細な全チェックリストは `BEST_PRACTICES.md` を参照してください。

### 主要原則

1. **簡潔性**: Claude はすでに賢い。Claude が知らない情報のみ追加
2. **明確性**: 具体的な指示を提供。曖昧な表現を避ける
3. **一貫性**: 用語、フォーマット、命名規則を統一
4. **完全性**: エッジケース、エラー処理、前提条件を明記
5. **保守性**: 変更履歴、モジュール化、適切なファイル分割

### よくある間違い

**❌ description が曖昧**:

```yaml
description: ドキュメント作成を手伝います
```

**✅ 具体的で明確**:

```yaml
description: JSDoc コメント付き TypeScript ソースコードから API ドキュメントを生成します。ユーザーが TypeScript プロジェクトの API ドキュメント作成または更新を依頼したときに使用します。
```

その他の間違いと対策は `BEST_PRACTICES.md` を参照。

## 🔄 スキル更新フロー

既存スキルを更新する場合:

```
更新進捗:
- [ ] 1. 現在のスキルを読み込む (Read ツール)
- [ ] 2. 変更要件を明確化
- [ ] 3. 変更を適用 (Edit ツール)
- [ ] 4. 自動検証 (bash scripts/validate_skill.sh .)
- [ ] 5. 手動チェックリストで品質確認
- [ ] 6. 変更履歴を更新（必要に応じて）
```

## 📚 詳細リソース

- **完全なベストプラクティス**: `BEST_PRACTICES.md`
- **テンプレート**: `templates/skill_template.md`, `templates/REFERENCE_template.md`
- **実動作する例**: `examples/markdown-formatter/`
- **複雑な構造の例**: `examples/complex-skill/`
- **検証スクリプト**: `scripts/validate_skill.sh`

### 公式リソース

- [Agent Skills Best Practices](https://docs.claude.com/en/docs/agents-and-tools/agent-skills/best-practices)
- [Agent Skills Spec](https://github.com/anthropics/skills/blob/main/agent_skills_spec.md)
- [Public Skills Repository](https://github.com/anthropics/skills)

## 📝 まとめ

**スキル作成の鍵**:

1. **明確な description**: Claude がいつ使うべきか判断できるように
2. **プログレッシブディスクロージャ**: SKILL.md は簡潔に、詳細は別ファイル
3. **具体的な例**: 実際に動作する例を最低1つ含める
4. **セキュリティ**: 機密情報をハードコードしない
5. **検証**: 作成後は必ず品質チェック

質問や不明点がある場合は、`BEST_PRACTICES.md` を参照するか、公式ドキュメントを確認してください。

## バージョン履歴

### v1.0.0 (2025-10-22)

- 初回リリース
- 公式仕様準拠のスキル作成ワークフロー
- 自動検証スクリプト (bash)
- 手動チェックリスト
- 実動作する例 (markdown-formatter)
