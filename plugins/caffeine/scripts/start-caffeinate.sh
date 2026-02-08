#!/bin/bash
set -euo pipefail

PID_FILE="/tmp/claude-caffeinate.pid"

# 既に caffeinate が動作中ならスキップ
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE")
  if kill -0 "$OLD_PID" 2>/dev/null; then
    exit 0
  fi
  rm -f "$PID_FILE"
fi

# caffeinate をバックグラウンドで起動
# -d: ディスプレイスリープ防止
# -i: アイドルスリープ防止
# -m: ディスクスリープ防止
# -s: システムスリープ防止 (AC 電源時)
caffeinate -dims &
echo $! > "$PID_FILE"

exit 0
