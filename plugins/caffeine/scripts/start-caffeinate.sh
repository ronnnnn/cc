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

mkdir -p "$SESSION_DIR"

# mkdir ロックで排他制御 (macOS には flock がないため)
cleanup() { rmdir "$LOCK_DIR" 2>/dev/null || true; }
trap cleanup EXIT
WAITED=0
while ! mkdir "$LOCK_DIR" 2>/dev/null; do
  sleep 0.1
  WAITED=$((WAITED + 1))
  if [ "$WAITED" -ge 100 ]; then
    exit 0
  fi
done

# 古いセッションマーカーを削除 (SessionEnd 未発火時の残留対策)
find "$SESSION_DIR" -name "session-*" -mmin +240 -delete 2>/dev/null || true

# セッションマーカーを作成
if [ -n "$SESSION_ID" ]; then
  touch "$SESSION_DIR/session-$SESSION_ID"
fi

# 既存の caffeinate プロセスを停止 (PID ファイルベース)
if [ -f "$PID_FILE" ]; then
  OLD_PID=$(cat "$PID_FILE" 2>/dev/null || true)
  if [[ "$OLD_PID" =~ ^[0-9]+$ ]] && [ "$OLD_PID" -gt 0 ]; then
    if ps -p "$OLD_PID" -o comm= 2>/dev/null | grep -q "caffeinate"; then
      kill "$OLD_PID" 2>/dev/null || true
    fi
  fi
  rm -f "$PID_FILE"
fi

# caffeinate をバックグラウンドで起動
# -d: ディスプレイスリープ防止
# -i: アイドルスリープ防止
# -m: ディスクスリープ防止
# -s: システムスリープ防止 (AC 電源時)
nohup /usr/bin/caffeinate -dims > /dev/null 2>&1 &
echo $! > "$PID_FILE"

exit 0
