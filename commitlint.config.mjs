/** @type {import("@commitlint/types").UserConfig} */
export default {
  extends: ['@commitlint/config-conventional'],
  rules: {
    "type-enum": [
      2,
      'always',
      [
        'build', // ビルドシステムの変更 (webpack, rollup 等)
        'chore', // 雑務 (ビルドプロセスやツール設定など)
        'ci', // CI 設定の変更
        'deps', // 依存パッケージの追加・更新・削除
        'docs', // ドキュメントのみの変更
        'feat', // 新機能の追加
        'fix', // バグ修正
        'perf', // パフォーマンス改善
        'refactor', // バグ修正や機能追加を伴わないコード変更
        'revert', // 以前のコミットの取り消し
        'style', // コードの意味に影響しない変更 (空白、フォーマット等)
        'test', // テストの追加・修正
      ],
    ],
    "scope-enum": [
      2,
      'always',
      [
        'claude',
        'git',
      ],
    ],
  },
};
