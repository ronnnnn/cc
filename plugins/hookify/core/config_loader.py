#!/usr/bin/env python3
"""Configuration loader for hookify plugin.

Loads rules from two directories (global → project) with project-level overrides.
- Global:  ~/.claude/hooks-rules/*.md
- Project: $CWD/.claude/hooks-rules/*.md

Same-name rules in the project directory override global rules.
Project rules with `enabled: false` can disable global rules.
"""

import os
import sys
import glob
import re
from typing import List, Optional, Dict, Any, Tuple
from dataclasses import dataclass, field


@dataclass
class Condition:
    """A single condition for matching."""

    field: str  # "command", "new_text", "file_path", "tool_name", etc.
    operator: str  # "regex_match", "contains", "equals", etc.
    pattern: str

    @classmethod
    def from_dict(cls, data: Dict[str, Any]) -> "Condition":
        return cls(
            field=data.get("field", ""),
            operator=data.get("operator", "regex_match"),
            pattern=data.get("pattern", ""),
        )


@dataclass
class Rule:
    """A hookify rule."""

    name: str
    enabled: bool
    event: str  # "bash", "file", "stop", "prompt", "all"
    pattern: Optional[str] = None
    conditions: List[Condition] = field(default_factory=list)
    action: str = "warn"  # "warn" or "block"
    tool_matcher: Optional[str] = None  # regex pattern for tool name matching
    message: str = ""
    source: str = ""  # "global" or "project"

    @classmethod
    def from_dict(cls, frontmatter: Dict[str, Any], message: str, source: str = "") -> "Rule":
        conditions = []

        if "conditions" in frontmatter:
            cond_list = frontmatter["conditions"]
            if isinstance(cond_list, list):
                conditions = [Condition.from_dict(c) for c in cond_list]

        simple_pattern = frontmatter.get("pattern")
        if simple_pattern and not conditions:
            event = frontmatter.get("event", "all")
            if event == "bash":
                cond_field = "command"
            elif event == "file":
                cond_field = "new_text"
            else:
                cond_field = "content"

            conditions = [
                Condition(field=cond_field, operator="regex_match", pattern=simple_pattern)
            ]

        return cls(
            name=frontmatter.get("name", "unnamed"),
            enabled=frontmatter.get("enabled", True),
            event=frontmatter.get("event", "all"),
            pattern=simple_pattern,
            conditions=conditions,
            action=frontmatter.get("action", "warn"),
            tool_matcher=frontmatter.get("tool_matcher"),
            message=message.strip(),
            source=source,
        )


def _unquote(value: str) -> str:
    """Strip surrounding quotes and unescape YAML double-quote escapes."""
    if len(value) >= 2 and value[0] == '"' and value[-1] == '"':
        # Double-quoted YAML: process escape sequences
        inner = value[1:-1]
        inner = inner.replace("\\\\", "\x00")  # placeholder
        inner = inner.replace("\\n", "\n")
        inner = inner.replace("\\t", "\t")
        inner = inner.replace('\\"', '"')
        inner = inner.replace("\x00", "\\")
        return inner
    if len(value) >= 2 and value[0] == "'" and value[-1] == "'":
        # Single-quoted YAML: no escape processing
        return value[1:-1]
    return value


def extract_frontmatter(content: str) -> Tuple[Dict[str, Any], str]:
    """Extract YAML frontmatter and message body from markdown.

    Simple parser — no external YAML dependency required.
    Handles nested list-of-dict items (conditions).
    """
    if not content.startswith("---"):
        return {}, content

    parts = content.split("---", 2)
    if len(parts) < 3:
        return {}, content

    frontmatter_text = parts[1]
    message = parts[2].strip()

    frontmatter: Dict[str, Any] = {}
    lines = frontmatter_text.split("\n")

    current_key: Optional[str] = None
    current_list: List[Any] = []
    current_dict: Dict[str, Any] = {}
    in_list = False
    in_dict_item = False

    def _flush_list():
        nonlocal current_key, current_list, current_dict, in_list, in_dict_item
        if in_list and current_key:
            if in_dict_item and current_dict:
                current_list.append(current_dict)
                current_dict = {}
            frontmatter[current_key] = current_list
        in_list = False
        in_dict_item = False
        current_list = []

    for line in lines:
        stripped = line.strip()
        if not stripped or stripped.startswith("#"):
            continue

        indent = len(line) - len(line.lstrip())

        # Top-level key: value
        if indent == 0 and ":" in line and not stripped.startswith("-"):
            _flush_list()

            key, value = line.split(":", 1)
            key = key.strip()
            value = value.strip()

            if not value:
                current_key = key
                in_list = True
                current_list = []
            else:
                value = _unquote(value)
                if isinstance(value, str) and value.lower() == "true":
                    value = True
                elif isinstance(value, str) and value.lower() == "false":
                    value = False
                frontmatter[key] = value

        # List item
        elif stripped.startswith("-") and in_list:
            if in_dict_item and current_dict:
                current_list.append(current_dict)
                current_dict = {}

            item_text = stripped[1:].strip()

            if ":" in item_text and "," in item_text:
                item_dict = {}
                for part in item_text.split(","):
                    if ":" in part:
                        k, v = part.split(":", 1)
                        item_dict[k.strip()] = _unquote(v.strip())
                current_list.append(item_dict)
                in_dict_item = False
            elif ":" in item_text:
                in_dict_item = True
                k, v = item_text.split(":", 1)
                current_dict = {k.strip(): _unquote(v.strip())}
            else:
                current_list.append(_unquote(item_text))
                in_dict_item = False

        # Continuation of dict item under list
        elif indent > 2 and in_dict_item and ":" in line:
            k, v = stripped.split(":", 1)
            current_dict[k.strip()] = _unquote(v.strip())

    _flush_list()

    return frontmatter, message


def load_rules(event: Optional[str] = None) -> List[Rule]:
    """Load rules from global and project directories.

    Global:  ~/.claude/hooks-rules/*.md
    Project: $CWD/.claude/hooks-rules/*.md

    Project rules override global rules with the same name.
    """
    rules_by_name: Dict[str, Rule] = {}

    # 1. Load global rules (lower priority)
    home = os.path.expanduser("~")
    global_dir = os.path.join(home, ".claude", "hooks-rules")
    _load_from_directory(global_dir, "global", rules_by_name)

    # 2. Load project rules (higher priority — overrides global)
    project_dir = os.path.join(".claude", "hooks-rules")
    _load_from_directory(project_dir, "project", rules_by_name)

    # Filter by event and enabled status
    result = []
    for rule in rules_by_name.values():
        if not rule.enabled:
            continue
        if event and rule.event != "all" and rule.event != event:
            continue
        result.append(rule)

    return result


def _load_from_directory(
    directory: str, source: str, rules_by_name: Dict[str, Rule]
) -> None:
    """Load all *.md rule files from a directory."""
    if not os.path.isdir(directory):
        return

    pattern = os.path.join(directory, "*.md")
    for file_path in sorted(glob.glob(pattern)):
        try:
            rule = _load_rule_file(file_path, source)
            if rule:
                rules_by_name[rule.name] = rule
        except Exception as e:
            print(f"Warning: Failed to load {file_path}: {e}", file=sys.stderr)


def _load_rule_file(file_path: str, source: str) -> Optional[Rule]:
    """Load a single rule file."""
    try:
        with open(file_path, "r") as f:
            content = f.read()

        frontmatter, message = extract_frontmatter(content)
        if not frontmatter:
            return None

        return Rule.from_dict(frontmatter, message, source=source)

    except Exception as e:
        print(f"Error: Cannot load {file_path}: {e}", file=sys.stderr)
        return None
