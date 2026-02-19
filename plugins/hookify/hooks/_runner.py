#!/usr/bin/env python3
"""Shared hook runner for all hook events."""

import json
import os
import sys
from typing import Optional


def run(event: Optional[str], hook_event_name: str = "") -> None:
    """Load rules for *event*, evaluate against stdin, and print JSON result.

    Always exits 0 so that hook errors never block operations.
    """
    plugin_root = os.environ.get("CLAUDE_PLUGIN_ROOT")
    if plugin_root and plugin_root not in sys.path:
        sys.path.insert(0, plugin_root)

    try:
        from core.config_loader import load_rules
        from core.rule_engine import RuleEngine
    except ImportError as e:
        print(json.dumps({"systemMessage": f"Hookify import error: {e}"}))
        sys.exit(0)

    try:
        input_data = json.load(sys.stdin)

        # Inject hook_event_name so rule_engine can produce correct output format
        if hook_event_name:
            input_data["hook_event_name"] = hook_event_name

        # Determine effective event for rule filtering
        effective_event = event
        if event is None:
            tool_name = input_data.get("tool_name", "")
            if tool_name == "Bash":
                effective_event = "bash"
            elif tool_name in ("Edit", "Write", "MultiEdit"):
                effective_event = "file"
            else:
                effective_event = "all"

        rules = load_rules(event=effective_event)
        result = RuleEngine().evaluate_rules(rules, input_data)
        print(json.dumps(result))

    except Exception as e:
        print(json.dumps({"systemMessage": f"Hookify error: {e}"}))

    finally:
        sys.exit(0)
