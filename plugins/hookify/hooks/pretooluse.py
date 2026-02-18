#!/usr/bin/env python3
"""PreToolUse hook — evaluates rules before tool execution."""

import os, sys

sys.path.insert(0, os.environ.get("CLAUDE_PLUGIN_ROOT", os.path.dirname(os.path.dirname(__file__))))
from hooks._runner import run

if __name__ == "__main__":
    run(event=None)  # auto-detect bash/file from tool_name
