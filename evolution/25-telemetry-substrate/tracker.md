# Tracker: 25-telemetry-substrate

## Current state
**Tier:** 0 (substrate & bootstrap hygiene)
**Epic:** 0.3
**Priority:** P1
**Complexity:** Medium (overall)
**Current phase:** not-started
**Status:** not-started
**Last touched:** 2026-04-18
**Blockers:** none
**Next action:** Phase 1 — add env block to `.claude/settings.json`, verify spans emit in a fresh session.

## Phase log
### Phase 1 — Enable + local console capture
- Start: —
- Complete: —
- Notes: —

### Phase 2 — Local collector + persistence
- Start: —
- Complete: —
- Notes: —

### Phase 3 — Downstream consumption
- Start: —
- Complete: —
- Notes: —

## Decisions
- 2026-04-18 — User introduced this epic post-audit. Rationale: verification substrate is foundational; without it, downstream work rests on promise not measurement. Priority P1.
- 2026-04-18 — Local-only retention by default. External observability backend is out of scope.

## Related artifacts
- `.claude/settings.json`
- `knowledge/runbooks/telemetry-queries.md` (to be created in Phase 2)
- Epic consumers: 1.2, 2.3, 5.2, 6.8, 6.9
