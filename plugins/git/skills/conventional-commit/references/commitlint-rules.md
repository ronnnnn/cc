# commitlint ルールリファレンス

commitlint の全ルールと設定例。

## ルール形式

各ルールは以下の形式で設定:

```javascript
'rule-name': [level, applicable, value]
```

| 要素         | 説明                                    |
| ------------ | --------------------------------------- |
| `level`      | `0` = 無効, `1` = 警告, `2` = エラー    |
| `applicable` | `'always'` = 常に適用, `'never'` = 反転 |
| `value`      | ルール固有の値                          |

## type 関連ルール

### type-enum

許可される type の一覧。

```javascript
'type-enum': [2, 'always', [
  'feat',     // 新機能
  'fix',      // バグ修正
  'docs',     // ドキュメント
  'style',    // フォーマット
  'refactor', // リファクタリング
  'perf',     // パフォーマンス改善
  'test',     // テスト
  'chore',    // その他
  'build',    // ビルド
  'ci',       // CI
  'revert'    // リバート
]]
```

### type-case

type の大文字/小文字。

```javascript
'type-case': [2, 'always', 'lower-case']
// 'lower-case', 'upper-case', 'camel-case', 'pascal-case', 'kebab-case', 'snake-case'
```

### type-empty

type の空チェック。

```javascript
'type-empty': [2, 'never']  // type は必須
```

## scope 関連ルール

### scope-enum

許可される scope の一覧。

```javascript
'scope-enum': [2, 'always', [
  'core',
  'ui',
  'api',
  'auth',
  'deps'
]]
```

### scope-case

scope の大文字/小文字。

```javascript
'scope-case': [2, 'always', 'lower-case']
```

### scope-empty

scope の空チェック。

```javascript
'scope-empty': [2, 'never']   // scope は必須
'scope-empty': [2, 'always']  // scope は禁止
'scope-empty': [0]            // scope は任意 (デフォルト)
```

## subject 関連ルール

### subject-case

subject の大文字/小文字。

```javascript
'subject-case': [2, 'always', 'lower-case']
// 複数指定可能
'subject-case': [2, 'always', ['sentence-case', 'lower-case']]
```

### subject-empty

subject の空チェック。

```javascript
'subject-empty': [2, 'never']  // subject は必須
```

### subject-full-stop

subject の末尾ピリオド。

```javascript
'subject-full-stop': [2, 'never', '.']  // ピリオド禁止
```

### subject-max-length

subject の最大文字数。

```javascript
'subject-max-length': [2, 'always', 50]
```

### subject-min-length

subject の最小文字数。

```javascript
'subject-min-length': [2, 'always', 10]
```

## header 関連ルール

### header-max-length

ヘッダー (type + scope + subject) の最大文字数。

```javascript
'header-max-length': [2, 'always', 100]
```

### header-min-length

ヘッダーの最小文字数。

```javascript
'header-min-length': [2, 'always', 10]
```

## body 関連ルール

### body-leading-blank

body の前の空行。

```javascript
'body-leading-blank': [2, 'always']  // 空行必須
```

### body-max-line-length

body の 1 行の最大文字数。

```javascript
'body-max-line-length': [2, 'always', 100]
```

### body-empty

body の空チェック。

```javascript
'body-empty': [2, 'never']  // body は必須
```

## footer 関連ルール

### footer-leading-blank

footer の前の空行。

```javascript
'footer-leading-blank': [2, 'always']
```

### footer-max-line-length

footer の 1 行の最大文字数。

```javascript
'footer-max-line-length': [2, 'always', 100]
```

## 設定例

### 基本設定 (config-conventional 継承)

```javascript
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
};
```

### カスタム設定

```javascript
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'type-enum': [
      2,
      'always',
      [
        'feat',
        'fix',
        'docs',
        'style',
        'refactor',
        'perf',
        'test',
        'chore',
        'build',
        'ci',
      ],
    ],
    'scope-enum': [2, 'always', ['core', 'ui', 'api', 'auth', 'deps']],
    'scope-empty': [2, 'never'],
    'subject-case': [2, 'always', 'lower-case'],
    'header-max-length': [2, 'always', 72],
  },
};
```

### 日本語対応設定

```javascript
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    // 日本語の subject を許可
    'subject-case': [0],
    // 日本語は文字数が少なくなるため緩和
    'header-max-length': [2, 'always', 100],
  },
};
```

### scope 必須設定

```javascript
// commitlint.config.js
module.exports = {
  extends: ['@commitlint/config-conventional'],
  rules: {
    'scope-empty': [2, 'never'],
    'scope-enum': [
      2,
      'always',
      ['core', 'ui', 'api', 'auth', 'deps', 'config'],
    ],
  },
};
```

## プリセット設定

### @commitlint/config-conventional

```javascript
{
  type: ['build', 'chore', 'ci', 'docs', 'feat', 'fix', 'perf', 'refactor', 'revert', 'style', 'test'],
  scope: 任意,
  subject: 必須, 大文字禁止, ピリオド禁止
}
```

### @commitlint/config-angular

```javascript
{
  type: ['build', 'ci', 'docs', 'feat', 'fix', 'perf', 'refactor', 'style', 'test'],
  scope: 任意,
  subject: 必須
}
```

## 設定ファイルの優先順位

1. `commitlint.config.js`
2. `commitlint.config.cjs`
3. `commitlint.config.mjs`
4. `commitlint.config.ts`
5. `.commitlintrc`
6. `.commitlintrc.json`
7. `.commitlintrc.yaml` / `.commitlintrc.yml`
8. `.commitlintrc.js` / `.commitlintrc.cjs` / `.commitlintrc.mjs`
9. `.commitlintrc.ts`
10. `package.json` の `commitlint` フィールド
