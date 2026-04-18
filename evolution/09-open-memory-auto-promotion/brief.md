# Project 09: Open-memory auto-promotion

## Overview
Unresolved-problem memories use the `_open.md` suffix. `/orient` enumerates them, but stale and fresh open memories are treated equally. A 30-day-old `_open.md` receives the same surfacing as a 1-day-old one. Without explicit promotion and forced resolution, open problems accumulate silently.

## Linked framework section
`../../analytical-orchestration-framework.md` §5.5

## End goal
- `_open.md` with mtime ≥14d: `/orient` surfaces with STALE tag
- `_open.md` with mtime ≥30d: `/orient` prompts forced resolution — update, promote to a rule, or archive with explicit rationale
- Archival is not deletion; archived memories move to a `memory/archive/` subdirectory with a closure note

## Phased approach

### Phase 1 — 14-day STALE tag in /orient
**Complexity:** Low
**Exit criteria:** /orient's OPEN_PROBLEMS_QUEUE emits STALE tag for memories ≥14d since mtime.
**Steps:**
- Update /orient's phase-3 computation
- Cross-reference existing OPEN memories and backfill tags

### Phase 2 — 30-day forced-resolution prompt
**Complexity:** Medium
**Exit criteria:** /orient outputs a forced-resolution block at the end of its summary listing any ≥30d OPEN memory with three options (update / promote / archive).
**Steps:**
- Add resolution block to /orient output
- Document archival convention (directory + closure-note format)
- Update `.claude/rules/guardrails.md` with the protocol

### Phase 3 — Archival workflow
**Complexity:** Low
**Exit criteria:** An archival skill or command moves the memory file, writes a closure note, updates MEMORY.md.
**Steps:**
- Implement archival helper
- Test on existing stale memories
- Document in evolve retrospective section

## Dependencies
- None

## Risks
- Forced resolution under time pressure can produce low-quality decisions → surface as a block, not a deadline
