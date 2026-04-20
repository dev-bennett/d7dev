# Tracker: 03-runtime-substrate-audit

## Current state
**Tier:** 1
**Epic:** 0.1 (Swimlane 0, P1)
**Complexity:** Medium (overall)
**Current phase:** complete
**Status:** complete
**Last touched:** 2026-04-20
**Blockers:** none
**Next action:** downstream epics (1.1 hook lifecycle, 1.2 unified event log, 0.3 telemetry) can consume the runbook as their substrate reference.

## Phase log
### Phase 1 — Inventory
- Start: 2026-04-20
- Complete: 2026-04-20
- Notes: enumerated every user-scope (`~/.claude/`) and project-scope (`<repo>/.claude/`) resource; captured paths, lifecycle cues, authoring and invocation mechanisms. Raw output at `inventory/phase1-enumeration.md`. Covered the 15 brief-specified resources + 14 additional user-scope paths observed during enumeration (backups, cache, chrome, debug, file-history, ide, paste-cache, plans, session-env, sessions, shell-snapshots, statsig, stats-cache, telemetry). Absences confirmed: `~/.claude/{agents,commands,hooks,skills,memory,keybindings.json,statusline.json,settings.local.json}`.

### Phase 2 — Interaction mapping
- Start: 2026-04-20
- Complete: 2026-04-20
- Notes: produced adjacency edge list (28 edges across config→activation, hook→state, hook→context injection, tool→user-scope state, plugin→tool surface). Precedence rules documented for settings merge, memory keying, CLAUDE.md loading, tool name resolution, hook firing order, sub-agent dispatch. Known-problematic interactions cross-referenced to feedback memories (dont_edit_live_hooks, hook_events, claude_md_chain). Raw output at `inventory/phase2-interactions.md`.

### Phase 3 — Canonical patterns + runbook
- Start: 2026-04-20
- Complete: 2026-04-20
- Notes: `knowledge/runbooks/runtime-substrate-catalog.md` committed as primary deliverable. Contains purpose, prerequisites, scope boundaries, per-resource catalog (15 primary + 14 supporting), interaction adjacency summary, precedence rules, canonical usage decision tree, known failure modes cross-referenced to feedback memories, troubleshooting section, host-version sensitivity note, related references. Framework doc §1.4 updated at line 94 with cross-reference to runbook. `/orient` command updated with substrate deep-dive pointer in the Phase 1 catalog-only section.

## Decisions
- 2026-04-18 — Scoped as tier 1 per user's explicit observation that runtime-substrate recognition was a material gap in the original framework doc.
- 2026-04-20 — Epic completed in a single session as one task bundle. All three phases landed with raw artifacts in `inventory/` and consolidated runbook at `knowledge/runbooks/`.
- 2026-04-20 — Expanded the brief's 15-resource scope to include 14 additional observed user-scope resources (backups, file-history, plans, telemetry, etc.). Lifecycle notes added for each to document what persists vs what is transient.

## Related artifacts
- `~/.claude/` (user-scope root)
- `<repo>/.claude/` (project-scope root)
- `../analytical-orchestration-framework.md` §1.4 — updated with cross-reference to runbook
- `knowledge/runbooks/runtime-substrate-catalog.md` — primary deliverable (NEW)
- `inventory/phase1-enumeration.md` — Phase 1 raw output
- `inventory/phase2-interactions.md` — Phase 2 raw output
- `.claude/commands/orient.md` — updated with substrate deep-dive pointer
