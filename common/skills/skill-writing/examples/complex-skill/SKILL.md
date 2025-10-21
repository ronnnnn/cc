---
name: complex-skill
description: 複数ファイル、スクリプト、プログレッシブディスクロージャを含む高度なスキル機能を示す包括的なサンプルです。ユーザーが複雑なスキルの構造を理解したい場合に使用します。
allowed-tools:
  - Read
  - Write
  - Glob
---

# Complex Skill Example

このスキルは、複数のファイルとプログレッシブディスクロージャを活用した複雑なスキルの例です。

## 概要

このスキルは以下の高度な機能を示します：

- プログレッシブディスクロージャ（段階的な情報開示）
- 複数の補助ファイル
- スクリプトの統合
- テンプレートの使用

### 主要機能

- **機能 1**: 複数ファイルの管理
- **機能 2**: 外部スクリプトの実行
- **機能 3**: テンプレートベースの生成

## 使用方法

### 前提条件

- Python 3.7 以上
- Node.js 14 以上（オプション）

### 基本的な使い方

#### ステップ 1: 環境設定

環境変数を `.env` ファイルに設定:

```bash
# .env
API_KEY=your_api_key_here
OUTPUT_DIR=./output
```

`.env.example` をコピーして開始できます:

```bash
cp .env.example .env
```

#### ステップ 2: 初期化スクリプトの実行

```bash
cd scripts
python init.py
```

#### ステップ 3: 処理の実行

詳細な API については `REFERENCE.md` を参照してください。

## 例

### 例 1: 基本的な処理

**目的**: デフォルト設定での処理実行

**前提条件**:

- `.env` ファイルが設定済み
- 必要な依存関係がインストール済み

**シナリオ**: 標準的なワークフローを実行

**実行手順**:

1. 設定ファイルを読み込む
2. データを処理する
3. 結果を出力する

**コード**:

```python
from complex_skill import Processor

processor = Processor()
result = processor.run()
print(result)
```

**出力**:

```
Processing complete: 100 items processed
Results saved to: ./output/results.json
```

**ポイント**:

- デフォルト設定は `config/default.json` で定義されています
- カスタム設定は `config/custom.json` で上書き可能

### 例 2: カスタム設定での処理

**目的**: 高度なオプションを使用した処理

**シナリオ**: カスタムパラメータで処理を実行

**コード**:

```python
from complex_skill import Processor

processor = Processor(
    config_path="config/custom.json",
    output_format="csv",
    verbose=True
)
result = processor.run()
```

**ポイント**:

- 詳細なパラメータは `REFERENCE.md` を参照
- 複数の出力形式をサポート: JSON, CSV, XML

### 例 3: バッチ処理

**目的**: 複数のファイルを一括処理

詳細な例は `examples/batch-processing.md` を参照してください。

## 詳細設定

### 設定ファイル

設定ファイルは `config/` ディレクトリに配置します。

**構造**:

```json
{
  "input": {
    "format": "json",
    "path": "./data/input"
  },
  "output": {
    "format": "json",
    "path": "./data/output"
  },
  "processing": {
    "workers": 4,
    "timeout": 30
  }
}
```

### テンプレート

テンプレートは `templates/` ディレクトリにあります：

- `default.template.json`: デフォルトテンプレート
- `custom.template.json`: カスタムテンプレート

## ベストプラクティス

- ✅ DO: 環境変数を使用して機密情報を管理
- ✅ DO: テンプレートを活用して一貫性を保つ
- ✅ DO: エラーハンドリングを適切に実装
- ❌ DON'T: API キーをハードコード
- ❌ DON'T: 大量のデータを一度に処理

## トラブルシューティング

### 問題: "API_KEY not found"

**症状**: 環境変数が見つからないエラー

**原因**: `.env` ファイルが設定されていない

**解決策**:

```bash
cp .env.example .env
# .env ファイルを編集して API_KEY を設定
```

### 問題: "Permission denied"

**症状**: ファイルへの書き込みエラー

**原因**: 出力ディレクトリの書き込み権限がない

**解決策**:

```bash
mkdir -p output
chmod 755 output
```

## 追加リソース

このスキルは複数のファイルで構成されています：

- `REFERENCE.md`: 完全な API リファレンスと技術仕様
- `examples/`: 詳細な使用例
  - `examples/basic-usage.md`: 基本的な使い方
  - `examples/batch-processing.md`: バッチ処理の例
  - `examples/advanced-patterns.md`: 高度なパターン
- `templates/`: 再利用可能なテンプレート
- `scripts/`: ヘルパースクリプト
  - `scripts/init.py`: 初期化スクリプト
  - `scripts/validate.py`: 検証スクリプト

## 変更履歴

### v2.1.0 (2025-01-15)

- 機能追加: CSV 出力サポート
- 改善: バッチ処理のパフォーマンス向上
- バグ修正: エラーハンドリングの改善

### v2.0.0 (2025-01-01)

- [BREAKING] 設定ファイル構造を変更
- 機能追加: テンプレートシステム
- 機能追加: 複数出力形式のサポート

### v1.0.0 (2024-12-01)

- 初回リリース
