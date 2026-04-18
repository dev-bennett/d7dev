# Tracker: 02-unified-session-state-log

## Current state
**Tier:** 1
**Complexity:** Medium-High (overall)
**Current phase:** not-started
**Status:** not-started
**Last touched:** 2026-04-18
**Blockers:** Prefer project 06 (hook-edit guard) to land first so hook edits in Phase 2 don't disable the runner.
**Next action:** Start Phase 1 — inventory current marker files and design event schema.

## Phase log
### Phase 1 — Event schema design
- Start: —
- Complete: —
- Notes: —

### Phase 2 — Hook migration
- Start: —
- Complete: —
- Notes: —

### Phase 3 — /orient and /evolve consume the log
- Start: —
- Complete: —
- Notes: —

## Decisions
- 2026-04-18 — Migration must respect `feedback_dont_edit_live_hooks.md` — hook edits apply at session boundaries.

## Related artifacts
- `.claude/hooks/_lib.sh`
- `.claude/hooks/*.sh`
- `.claude/commands/orient.md`
- `.claude/commands/evolve.md`
