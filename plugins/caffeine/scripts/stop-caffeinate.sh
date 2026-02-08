#!/bin/bash
set -euo pipefail

# stdin から session_id を取得
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || true)

SESSION_DIR="/tmp/claude-caffeinate"
PID_FILE="$SESSION_DIR/caffeinate.pid"

# セッションマーカーを削除
if [ -n "$SESSION_ID" ]; then
  rm -f "$SESSION_DIR/session-$SESSION_ID"
fi

# 他のセッションが残っていれば何もしない
REMAINING=$(find "$SESSION_DIR" -name "session-*" 2>/dev/null | wc -l | tr -d ' ')
if [ "$REMAINING" -gt 0 ]; then
  exit 0
fi

# 最後のセッション: caffeinate を停止
if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE" 2>/dev/null || true)
  if [[ "$PID" =~ ^[0-9]+$ ]] && [ "$PID" -gt 0 ]; then
    if ps -p "$PID" -o comm= 2>/dev/null | grep -qx "caffeinate"; then
      kill "$PID" 2>/dev/null || true
    fi
  fi
  rm -f "$PID_FILE"
fi

exit 0
