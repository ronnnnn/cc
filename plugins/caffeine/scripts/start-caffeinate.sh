#!/bin/bash
set -euo pipefail

# stdin から session_id を取得
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)

SESSION_DIR="/tmp/claude-caffeinate"
PID_FILE="$SESSION_DIR/caffeinate.pid"

mkdir -p "$SESSION_DIR"

# セッションマーカーを作成
if [ -n "$SESSION_ID" ]; then
  touch "$SESSION_DIR/session-$SESSION_ID"
fi

# caffeinate が動作中でなければ起動
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE" 2>/dev/null || true)
  if [[ "$OLD_PID" =~ ^[0-9]+$ ]] && [ "$OLD_PID" -gt 0 ] && \
     ps -p "$OLD_PID" -o comm= 2>/dev/null | grep -qx "caffeinate"; then
    exit 0
  fi
  rm -f "$PID_FILE"
fi

# caffeinate をバックグラウンドで起動
# -d: ディスプレイスリープ防止
# -i: アイドルスリープ防止
# -m: ディスクスリープ防止
# -s: システムスリープ防止 (AC 電源時)
nohup caffeinate -dims > /dev/null 2>&1 &
echo $! > "$PID_FILE"

exit 0
