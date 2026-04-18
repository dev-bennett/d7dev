# Project 01: Zero-prompt contract audit

## Overview
Canonical commands (`/orient`, `/preflight`, `/analyze`, etc.) are specified in the framework doc to run with zero permission prompts. The current implementation violates this for at least `/orient`, as observed during this session — bash patterns like `stat`, `grep`, `for`, and composite loops triggered prompts during the inventory phase. The root cause is a settings.json allowlist that was populated reactively rather than derived from the command specifications.

## Linked framework section
`../../analytical-orchestration-framework.md` §4.1 (Commands vs skills → Zero-prompt contract)

## End goal
A canonical command run produces zero permission prompts. Verified by:

1. A static audit script enumerating every Bash pattern referenced in `.claude/commands/*.md` and every tool class (Write, Edit, Read, Glob, Grep) invoked, cross-referenced against `.claude/settings.json` and `.claude/settings.local.json` allowlists.
2. A regression guard in `/test` that runs the audit and fails if any command references a tool call not in the allowlist.
3. A commit-time check that any new tool reference in a command file is paired with a corresponding allowlist entry in the same commit.

## Phased approach

### Phase 1 — Audit /orient specifically
**Complexity:** Low
**Exit criteria:** /orient runs end-to-end with zero prompts on a fresh session.
**Steps:**
- Enumerate every Bash pattern /orient issues (ls, git, stat, grep, for-loops, awk, etc.)
- Cross-reference against current allowlists
- Add missing patterns to `.claude/settings.json` allow list
- Test /orient from a fresh session

### Phase 2 — Audit remaining 15 commands
**Complexity:** Medium
**Exit criteria:** All 16 canonical commands have a documented tool-call inventory and matching allowlist entries.
**Steps:**
- For each command, grep for Bash/shell invocations, skill invocations, and file-system tool references
- Build a command-to-tool-call matrix
- Reconcile against allowlist
- Commit the matrix as a reference artifact

### Phase 3 — Automated audit + commit-time guard
**Complexity:** Medium
**Exit criteria:** CI-style audit script exists at `scripts/audit_command_permissions.py`; `/test` invokes it; PR fails if audit fails.
**Steps:**
- Write parser for command markdown → extract tool-call patterns
- Write validator comparing against settings allowlist
- Wire into `/test` and pre-commit

## Dependencies
- None (can start immediately)

## Risks
- Allowlist entries may interact unexpectedly with user-level settings precedence → mitigate by testing the merged effective allowlist
- Dynamic bash patterns (variable interpolation) may be hard to statically audit → accept conservative over-approximation
