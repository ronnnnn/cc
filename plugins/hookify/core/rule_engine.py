#!/usr/bin/env python3
"""Rule evaluation engine for hookify plugin.

Supports regex-based tool_matcher and tool_name as a condition field.
"""

import re
import sys
from functools import lru_cache
from typing import List, Dict, Any, Optional

from core.config_loader import Rule, Condition


@lru_cache(maxsize=128)
def _compile_regex(pattern: str) -> re.Pattern:
    return re.compile(pattern, re.IGNORECASE)


class RuleEngine:
    """Evaluates rules against hook input data."""

    def evaluate_rules(
        self, rules: List[Rule], input_data: Dict[str, Any]
    ) -> Dict[str, Any]:
        """Evaluate all rules and return combined results.

        Blocking rules → deny / block.  Warning rules → systemMessage only.
        """
        hook_event = input_data.get("hook_event_name", "")
        blocking: List[Rule] = []
        warning: List[Rule] = []

        for rule in rules:
            if self._rule_matches(rule, input_data):
                if rule.action == "block":
                    blocking.append(rule)
                else:
                    warning.append(rule)

        if blocking:
            messages = [f"**[{r.name}]**\n{r.message}" for r in blocking]
            combined = "\n\n".join(messages)

            if hook_event == "Stop":
                return {
                    "decision": "block",
                    "reason": combined,
                    "systemMessage": combined,
                }
            elif hook_event in ("PreToolUse", "PostToolUse"):
                return {
                    "hookSpecificOutput": {
                        "hookEventName": hook_event,
                        "permissionDecision": "deny",
                    },
                    "systemMessage": combined,
                }
            else:
                return {"systemMessage": combined}

        if warning:
            messages = [f"**[{r.name}]**\n{r.message}" for r in warning]
            return {"systemMessage": "\n\n".join(messages)}

        return {}

    # ------------------------------------------------------------------
    # Internal helpers
    # ------------------------------------------------------------------

    def _rule_matches(self, rule: Rule, input_data: Dict[str, Any]) -> bool:
        tool_name = input_data.get("tool_name", "")
        tool_input = input_data.get("tool_input", {})

        # Check tool_matcher (regex)
        if rule.tool_matcher:
            if not self._matches_tool(rule.tool_matcher, tool_name):
                return False

        if not rule.conditions:
            # tool_matcher-only rules match when tool_matcher passes
            return bool(rule.tool_matcher)

        # All conditions must match (AND)
        return all(
            self._check_condition(c, tool_name, tool_input, input_data)
            for c in rule.conditions
        )

    def _matches_tool(self, matcher: str, tool_name: str) -> bool:
        """Regex-based tool matcher (improved from hookify's exact match)."""
        if matcher == "*":
            return True
        try:
            regex = _compile_regex(f"^(?:{matcher})$")
            return bool(regex.match(tool_name))
        except re.error:
            # Fallback to exact match on regex error
            return tool_name == matcher

    def _check_condition(
        self,
        condition: Condition,
        tool_name: str,
        tool_input: Dict[str, Any],
        input_data: Dict[str, Any],
    ) -> bool:
        field_value = self._extract_field(
            condition.field, tool_name, tool_input, input_data
        )
        if field_value is None:
            return False

        op = condition.operator
        pat = condition.pattern

        if op == "regex_match":
            return self._regex_match(pat, field_value)
        elif op == "contains":
            return pat in field_value
        elif op == "equals":
            return pat == field_value
        elif op == "not_contains":
            return pat not in field_value
        elif op == "starts_with":
            return field_value.startswith(pat)
        elif op == "ends_with":
            return field_value.endswith(pat)
        return False

    def _extract_field(
        self,
        field: str,
        tool_name: str,
        tool_input: Dict[str, Any],
        input_data: Dict[str, Any],
    ) -> Optional[str]:
        # New: tool_name as a condition field
        if field == "tool_name":
            return tool_name

        # Direct lookup in tool_input
        if field in tool_input:
            v = tool_input[field]
            return v if isinstance(v, str) else str(v)

        # Stop event fields
        if field == "reason":
            return input_data.get("reason", "")
        if field == "transcript":
            path = input_data.get("transcript_path")
            if path:
                try:
                    with open(path, "r", encoding="utf-8") as f:
                        return f.read()
                except Exception:
                    return ""
            return ""
        if field == "user_prompt":
            return input_data.get("user_prompt", "")

        # Tool-specific aliases
        if tool_name == "Bash" and field == "command":
            return tool_input.get("command", "")

        if tool_name in ("Write", "Edit"):
            if field in ("content", "new_text", "new_string"):
                return tool_input.get("content") or tool_input.get("new_string", "")
            if field in ("old_text", "old_string"):
                return tool_input.get("old_string", "")
            if field == "file_path":
                return tool_input.get("file_path", "")

        if tool_name == "MultiEdit":
            if field == "file_path":
                return tool_input.get("file_path", "")
            if field in ("new_text", "new_string", "content"):
                edits = tool_input.get("edits", [])
                return " ".join(e.get("new_string", "") for e in edits)

        return None

    def _regex_match(self, pattern: str, text: str) -> bool:
        try:
            return bool(_compile_regex(pattern).search(text))
        except re.error as e:
            print(f"Invalid regex '{pattern}': {e}", file=sys.stderr)
            return False
