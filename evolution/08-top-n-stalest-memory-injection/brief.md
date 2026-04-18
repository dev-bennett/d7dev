# Project 08: Top-N stalest memory injection

## Overview
`prompt-context.sh` currently injects today's date and the session-checkpoint age. Memory staleness is only surfaced when the MEMORY.md index itself is >14 days old (one-shot flag). Individual memories decay silently. A memory cited from stale state can lead the agent to recommend action on a file or function that no longer exists.

## Linked framework section
`../../analytical-orchestration-framework.md` §5.3

## End goal
On each `UserPromptSubmit`, the top-N stalest memories (by mtime) are injected as additionalContext with their descriptions. The agent sees stale items on every prompt and can prioritize verification or update before action.

## Phased approach

### Phase 1 — Stale scanner
**Complexity:** Low
**Exit criteria:** `prompt-context.sh` scans the memory directory, sorts by mtime, emits top-N oldest.
**Steps:**
- Add stat-based mtime sort
- Emit description + age in additionalContext payload
- Tune N (default: 3)

### Phase 2 — Filter to relevant memories
**Complexity:** Medium
**Exit criteria:** Only stale memories matching current session context are injected (e.g., if the prompt mentions topic X, stale memories about X come first).
**Steps:**
- Lightweight prompt-keyword extraction
- Score memories by keyword overlap
- Fallback to pure-age ordering when no overlap

### Phase 3 — Action nudges
**Complexity:** Low-Medium
**Exit criteria:** When a stale memory is cited mid-session, the hook nudges toward update or archival.
**Steps:**
- Event-log hook to detect memory citation in assistant output
- Emit reminder in next prompt context if the cited memory was >14d old

## Dependencies
- Project 02 (session event log) helps with Phase 3

## Risks
- Over-injection bloats prompt context → cap at N, truncate long descriptions
