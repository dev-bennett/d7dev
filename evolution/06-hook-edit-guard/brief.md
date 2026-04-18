# Project 06: Hook-edit guard

## Overview
Mid-session edits to hook scripts in `.claude/hooks/` can silently disable the hook runner for the remainder of the session. This failure mode is documented (`feedback_dont_edit_live_hooks.md`) and well-known, but enforcement is purely behavioral — a distracted or forgetful agent can still edit a hook mid-session and break the runner. The failure is invisible until hooks stop firing, at which point counters and state tracking are already corrupt.

## Linked framework section
`../../analytical-orchestration-framework.md` §4.3 (Immutable during a live session)

## End goal
A `PreToolUse` hook on Write/Edit refuses operations whose target path is under `.claude/hooks/` unless the user's current prompt contains an explicit override phrase (e.g., `apply-hook-edit-then-restart`). The guard prompts the user to save pending hook changes as a queued edit and restart the session.

## Phased approach

### Phase 1 — Block-on-default
**Complexity:** Low
**Exit criteria:** A new hook `hook-edit-guard.sh` wired as `PreToolUse` on Write|Edit. Blocks writes under `.claude/hooks/` with a clear message. Override phrase documented but not yet implemented.
**Steps:**
- Write hook script
- Wire into `.claude/settings.json`
- Add to zero-prompt allowlist
- Test by attempting an edit (should block)

### Phase 2 — Override mechanism
**Complexity:** Low
**Exit criteria:** A documented override phrase present in the user's most-recent prompt allows the edit. Override events are logged to the unified session log.
**Steps:**
- Parse recent transcript for override phrase
- Log override in session event log
- Emit a session-end warning reminding the user to restart

### Phase 3 — Queued edit workflow
**Complexity:** Medium
**Exit criteria:** Agent can write hook edits to a `.claude/hooks/_pending/` directory during session; a `SessionStart` hook applies pending edits to live hook scripts and archives the pending file.
**Steps:**
- Define queued-edit directory + file convention
- Write SessionStart apply-and-archive logic
- Document workflow in `.claude/rules/guardrails.md`

## Dependencies
- Project 02 (session event log) is useful for Phase 2 logging but not strictly blocking

## Risks
- Override phrase misuse (agent self-overriding) → the override must reference a phrase from the user's prompt, not self-authored text
