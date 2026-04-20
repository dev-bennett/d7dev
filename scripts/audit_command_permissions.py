#!/usr/bin/env python3
"""Zero-prompt contract audit for d7dev canonical slash-commands.

Parses `.claude/commands/*.md`, extracts every tool-call pattern each command
explicitly references, and reconciles against the effective permission
allowlist computed as the set union of project, project-local, and user
settings files per knowledge/runbooks/runtime-substrate-catalog.md §5.

A canonical command should never produce a permission prompt on a fresh
session. Any reference emitted by this auditor as uncovered will prompt.

Usage:
    python scripts/audit_command_permissions.py --report   # human-readable table
    python scripts/audit_command_permissions.py --check    # exit non-zero on gap
"""

from __future__ import annotations

import argparse
import json
import re
import sys
from dataclasses import dataclass
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
COMMANDS_DIR = REPO_ROOT / ".claude" / "commands"

DEFAULT_SETTINGS_PATHS: tuple[Path, ...] = (
    REPO_ROOT / ".claude" / "settings.json",
    REPO_ROOT / ".claude" / "settings.local.json",
    Path.home() / ".claude" / "settings.json",
)

SHELL_KEYWORDS = frozenset({"do", "done", "then", "fi", "elif", "else", "esac", "in"})
TOOL_CLASSES = frozenset({"Read", "Write", "Edit", "Glob", "Grep", "Bash", "Skill"})

BASH_FENCE_RE = re.compile(r"```(?:bash|sh)?\n(.*?)```", re.DOTALL)
RUN_PREFIX_RE = re.compile(r"Run:\s*`([^`]+)`", re.IGNORECASE)
INLINE_BACKTICK_RE = re.compile(r"`([^`\n]+)`")
TOOL_CALL_RE = re.compile(r"\b(Read|Write|Edit|Glob|Grep|Bash|Skill)\(([^)]+)\)")
BASH_CMD_NAME_RE = re.compile(r"^[a-z][a-z0-9_.-]*$")


@dataclass(frozen=True)
class ToolCall:
    command_file: str
    kind: str
    pattern: str
    first_token: str


def extract_tool_calls(command_file: Path) -> list[ToolCall]:
    text = command_file.read_text()
    name = command_file.name
    calls: list[ToolCall] = []
    seen: set[tuple[str, str]] = set()

    def add(kind: str, pattern: str, token: str) -> None:
        key = (kind, pattern)
        if key in seen:
            return
        seen.add(key)
        calls.append(ToolCall(name, kind, pattern, token))

    for match in BASH_FENCE_RE.finditer(text):
        for line in match.group(1).splitlines():
            stripped = line.strip().lstrip("$").strip()
            if not stripped or stripped.startswith("#"):
                continue
            token = _first_token(stripped)
            if _is_bash_command(stripped, token):
                add("bash", stripped, token)

    for match in RUN_PREFIX_RE.finditer(text):
        snippet = match.group(1).strip()
        token = _first_token(snippet)
        if _is_bash_command(snippet, token):
            add("bash", snippet, token)

    for match in INLINE_BACKTICK_RE.finditer(text):
        snippet = match.group(1).strip()
        token = _first_token(snippet)
        if _looks_like_invocation(snippet, token):
            add("bash", snippet, token)

    for match in TOOL_CALL_RE.finditer(text):
        tool, arg = match.group(1), match.group(2).strip()
        if tool == "Bash":
            token = _first_token(arg)
            add("bash", arg, token)
        else:
            add("tool", f"{tool}({arg})", tool)

    return calls


def _first_token(snippet: str) -> str:
    stripped = snippet.lstrip("$ ").strip()
    for i, ch in enumerate(stripped):
        if ch in " \t|&;(<>`\n":
            return stripped[:i]
    return stripped


def _is_bash_command(snippet: str, token: str) -> bool:
    if not token or token in SHELL_KEYWORDS:
        return False
    if token in TOOL_CLASSES:
        return False
    return bool(BASH_CMD_NAME_RE.match(token))


def _looks_like_invocation(snippet: str, token: str) -> bool:
    if not _is_bash_command(snippet, token):
        return False
    # Require at least one argument (space after command name) OR be a known
    # no-arg invocation like `date`, `pwd`. This filters out bare backtick-
    # wrapped identifiers that happen to match command-name syntax.
    rest = snippet[len(token):]
    return rest.startswith(" ") or rest.startswith("\t")


def load_allowlist(paths: list[Path]) -> set[str]:
    entries: set[str] = set()
    for path in paths:
        if not path.exists():
            continue
        try:
            data = json.loads(path.read_text())
        except json.JSONDecodeError:
            continue
        for entry in data.get("permissions", {}).get("allow", []):
            entries.add(entry)
    return entries


def is_covered(call: ToolCall, allowlist: set[str]) -> bool:
    if call.kind == "tool":
        if call.first_token in allowlist:
            return True
        if call.pattern in allowlist:
            return True
        for entry in allowlist:
            prefix = _wildcard_prefix(entry, call.first_token)
            if prefix is None:
                continue
            inner = call.pattern[len(call.first_token) + 1 : -1]
            if _prefix_matches(inner, prefix):
                return True
        return False

    if "Bash" in allowlist:
        return True
    if f"Bash({call.pattern})" in allowlist:
        return True
    for entry in allowlist:
        prefix = _wildcard_prefix(entry, "Bash")
        if prefix is None:
            continue
        if _prefix_matches(call.pattern, prefix):
            return True
    return False


def _wildcard_prefix(entry: str, tool_name: str) -> str | None:
    open_tag = f"{tool_name}("
    if not entry.startswith(open_tag) or not entry.endswith(":*)"):
        return None
    return entry[len(open_tag) : -3]


def _prefix_matches(value: str, prefix: str) -> bool:
    if value == prefix:
        return True
    if value.startswith(prefix + " "):
        return True
    if value.startswith(prefix + "\t"):
        return True
    return False


def audit(command_dir: Path, allowlist: set[str]) -> list[tuple[ToolCall, bool]]:
    rows: list[tuple[ToolCall, bool]] = []
    for md in sorted(command_dir.glob("*.md")):
        for call in extract_tool_calls(md):
            rows.append((call, is_covered(call, allowlist)))
    return rows


def format_report(rows: list[tuple[ToolCall, bool]]) -> str:
    covered = sum(1 for _, ok in rows if ok)
    total = len(rows)
    lines = [
        f"Permission audit: {covered}/{total} tool-call references covered",
        "",
        f"{'command':<20} {'kind':<5} {'token':<14} {'ok':<3} pattern",
        "-" * 100,
    ]
    for call, ok in rows:
        mark = "Y" if ok else "N"
        pattern = call.pattern if len(call.pattern) <= 60 else call.pattern[:57] + "..."
        lines.append(
            f"{call.command_file:<20} {call.kind:<5} {call.first_token:<14} {mark:<3} {pattern}"
        )
    return "\n".join(lines)


def main(argv: list[str] | None = None) -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="exit non-zero on any gap")
    parser.add_argument("--report", action="store_true", help="print human-readable table")
    parser.add_argument(
        "--commands-dir",
        type=Path,
        default=COMMANDS_DIR,
        help="commands directory (default: .claude/commands)",
    )
    parser.add_argument(
        "--settings",
        type=Path,
        action="append",
        help="settings JSON (repeatable; default: project + local + user)",
    )
    args = parser.parse_args(argv)

    settings_paths = args.settings if args.settings else list(DEFAULT_SETTINGS_PATHS)
    allowlist = load_allowlist(settings_paths)
    rows = audit(args.commands_dir, allowlist)
    gaps = [(call, ok) for call, ok in rows if not ok]

    if args.report or not args.check:
        print(format_report(rows))

    if args.check and gaps:
        print(
            f"\nGAP: {len(gaps)} tool-call reference(s) not covered by allowlist:",
            file=sys.stderr,
        )
        for call, _ in gaps:
            print(f"  {call.command_file}: {call.pattern}", file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
