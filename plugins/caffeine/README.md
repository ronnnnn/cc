# caffeine

Claude Code セッション中に macOS のスリープ・スクリーンセーバーを自動で抑制するプラグイン。

## 仕組み

| イベント     | 動作                                        |
| ------------ | ------------------------------------------- |
| SessionStart | `caffeinate -dims` をバックグラウンドで起動 |
| SessionEnd   | caffeinate プロセスを停止                   |

- `-d` : ディスプレイスリープ防止
- `-i` : アイドルスリープ防止
- `-m` : ディスクスリープ防止
- `-s` : システムスリープ防止 (AC 電源時)

## 前提条件

- macOS (`caffeinate` コマンドが必要)

## 動作確認

セッション中に caffeinate が動作しているか確認:

```bash
pgrep -l caffeinate
```

## 注意事項

- PID ファイルは `/tmp/claude-caffeinate.pid` に保存されます
- 複数の Claude Code セッションを同時に実行している場合、最初に終了したセッションが caffeinate を停止します
