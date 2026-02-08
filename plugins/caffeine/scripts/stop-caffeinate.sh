#!/bin/bash
set -euo pipefail

PID_FILE="/tmp/claude-caffeinate.pid"

if [ -f "$PID_FILE" ]; then
  PID=$(cat "$PID_FILE")
  kill "$PID" 2>/dev/null || true
  rm -f "$PID_FILE"
fi

exit 0
