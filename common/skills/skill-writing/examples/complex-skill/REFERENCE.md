# Complex Skill - Technical Reference

このドキュメントは `complex-skill` の詳細な技術仕様を提供します。

## API リファレンス

### Processor クラス

```python
class Processor:
    def __init__(
        self,
        config_path: str = "config/default.json",
        output_format: str = "json",
        verbose: bool = False
    )
```

**説明**: メインの処理クラス

**パラメータ**:

| 名前            | 型     | 必須 | デフォルト              | 説明                      |
| --------------- | ------ | ---- | ----------------------- | ------------------------- |
| `config_path`   | `str`  | ❌   | `"config/default.json"` | 設定ファイルのパス        |
| `output_format` | `str`  | ❌   | `"json"`                | 出力形式 (json, csv, xml) |
| `verbose`       | `bool` | ❌   | `False`                 | 詳細ログを出力            |

**戻り値**:

| 型          | 説明                   |
| ----------- | ---------------------- |
| `Processor` | Processor インスタンス |

**例外**:

| エラー              | 条件                       |
| ------------------- | -------------------------- |
| `FileNotFoundError` | 設定ファイルが見つからない |
| `ValueError`        | 無効な output_format       |

### run メソッド

```python
def run(self) -> ProcessResult
```

**説明**: 処理を実行

**戻り値**:

| 型              | 説明                 |
| --------------- | -------------------- |
| `ProcessResult` | 処理結果オブジェクト |

**使用例**:

```python
processor = Processor()
result = processor.run()
print(f"Processed: {result.count} items")
```

## 設定スキーマ

### 設定ファイル構造

```json
{
  "input": {
    "format": "json",
    "path": "./data/input",
    "encoding": "utf-8"
  },
  "output": {
    "format": "json",
    "path": "./data/output",
    "overwrite": false
  },
  "processing": {
    "workers": 4,
    "timeout": 30,
    "retry": 3
  }
}
```

### フィールド詳細

#### input.format

- **型**: `string`
- **デフォルト**: `"json"`
- **有効な値**: `"json"`, `"csv"`, `"xml"`
- **説明**: 入力データの形式

#### processing.workers

- **型**: `integer`
- **デフォルト**: `4`
- **範囲**: 1-16
- **説明**: 並列処理のワーカー数

## エラーコード

| コード | 名前               | 説明                   | 対処法                     |
| ------ | ------------------ | ---------------------- | -------------------------- |
| `E001` | `VALIDATION_ERROR` | 入力データの検証エラー | データ形式を確認           |
| `E002` | `PROCESSING_ERROR` | 処理中のエラー         | ログを確認し、データを修正 |
| `E003` | `OUTPUT_ERROR`     | 出力エラー             | 出力先の権限を確認         |

## パフォーマンス

### ベンチマーク

| 操作       | データ量      | 処理時間 | メモリ使用量 |
| ---------- | ------------- | -------- | ------------ |
| JSON 処理  | 1,000 items   | 50ms     | 10MB         |
| CSV 処理   | 10,000 items  | 500ms    | 50MB         |
| バッチ処理 | 100,000 items | 5s       | 200MB        |

---

**最終更新**: 2025-01-15
**バージョン**: 2.1.0
