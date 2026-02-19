#!/usr/bin/env python3
"""UserPromptSubmit hook — evaluates prompt-event rules."""

import os, sys

_root = os.environ.get("CLAUDE_PLUGIN_ROOT") or os.path.dirname(os.path.dirname(__file__))
if _root not in sys.path:
    sys.path.insert(0, _root)
from hooks._runner import run

if __name__ == "__main__":
    run(event="prompt", hook_event_name="UserPromptSubmit")
