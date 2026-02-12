# Session Context

**Session ID:** a2103211-deeb-43e9-845e-37626d6bc1d8

**Commit Message:** Pr-fix や pr-watch のレビュー修正の際に、レビューの指摘内容を鵜呑みにせず、検証や信頼できるソースからのファクトチェックにより、

## Prompt

pr-fix や pr-watch のレビュー修正の際に、レビューの指摘内容を鵜呑みにせず、検証や信頼できるソースからのファクトチェックにより、指摘が正しい確認するようにして
ファクトチェックのソースは tech-research と同じ優先順位で確認して

tech-research や claude-md-style に例外的な優先順位として下記を含めてほしい
- terraform に関する内容は terraform MCP が最優先
- Google Cloud に関する内容は google-developer-knowledge MCP が最優先

## Summary

変更完了です。以下の 5 ファイルを更新しました。

### 変更内容

**1. `plugins/git/skills/pr-fix/SKILL.md`**
- ステップ 3 を「レビューコメントの分析とファクトチェック」に変更
- ファクトチェック必須のケース (言語仕様、API、セキュリティ、パフォーマンス、規範的主張) を明記
- ソース優先順位テーブル (LSP → deepwiki → Gemini → context7 → WebFetch → WebSearch) を追加
- terraform / Google Cloud の例外優先順位を追加
- ファクトチェック結果を修正計画に反映する旨を追記

**2. `plugins/git/skills/pr-watch/SKILL.md`**
- 同様のファクトチェックセクションをレビュー修正の妥当性判断の直後に追加
- 指摘が誤りの場合はソース付きで返信コメントに記載するルールを追加
- 処理フローの step 1 にファクトチェック検証を組み込み

**3. `plugins/catch-up/skills/tech-research/SKILL.md`**
- ソース優先順位テーブルの直後に例外 (terraform MCP / google-developer-knowledge MCP) を追加

**4. `plugins/claude/skills/claude-md-style/SKILL.md`**
- 技術調査セクションのテンプレートに例外を追加

**5. `plugins/catch-up/skills/tech-research/references/source-guide.md`**
- フォールバック戦略の前に「例外的な優先順位」セクションを追加

## Key Actions

- - **Glob**: plugins/git/skills/pr-fix*
- - **Glob**: plugins/git/skills/pr-watch*
- - **Glob**: plugins/catch-up/skills/tech-research*
- - **Glob**: plugins/claude/skills/claude-md-style*
- - **Glob**: plugins/**/pr-fix*
- - **Glob**: plugins/**/pr-watch*
- - **Glob**: plugins/**/tech-research*
- - **Glob**: plugins/**/claude-md-style*
- - **Glob**: plugins/**/*.md
- - **Read**: /Users/s01059/Documents/agent/cc/plugins/git/skills/pr-fix/SKILL.md
