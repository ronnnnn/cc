#!/bin/bash
set -euo pipefail

# stdin から session_id を取得 (jq 優先、python3 フォールバック)
INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty' 2>/dev/null || \
  echo "$INPUT" | python3 -c "import sys,json; print(json.load(sys.stdin).get('session_id',''))" 2>/dev/null || \
  true)

# TMPDIR はユーザー固有のため、シンボリックリンク攻撃のリスクを軽減
SESSION_DIR="${TMPDIR:-/tmp}"
SESSION_DIR="${SESSION_DIR%/}/claude-caffeinate"
PID_FILE="$SESSION_DIR/caffeinate.pid"
LOCK_DIR="$SESSION_DIR/.lock"

# mkdir ロックで排他制御 (macOS には flock がないため)
cleanup() { rmdir "$LOCK_DIR" 2>/dev/null || true; }
trap cleanup EXIT
if [ -d "$SESSION_DIR" ]; then
  WAITED=0
  while ! mkdir "$LOCK_DIR" 2>/dev/null; do
    sleep 0.1
    WAITED=$((WAITED + 1))
    if [ "$WAITED" -ge 100 ]; then
      exit 0
    fi
  done
fi

# セッションマーカーを削除
if [ -n "$SESSION_ID" ]; then
  rm -f "$SESSION_DIR/session-$SESSION_ID"
fi

# 他のセッションが残っていれば何もしない
if [ -d "$SESSION_DIR" ]; then
  REMAINING=$(find "$SESSION_DIR" -name "session-*" 2>/dev/null | wc -l | tr -d ' ')
else
  REMAINING=0
fi
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
