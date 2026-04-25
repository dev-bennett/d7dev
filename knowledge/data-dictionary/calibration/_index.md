# Calibration Index

Auto-updated by `/calibrate` on every artifact write. See `CLAUDE.md` for conventions.

The calibration mechanism is **universal** — any table queried via MCP is a candidate. Artifacts accumulate organically as the user (and Claude) work with different tables. There is no fixed "required" list; the rule in `.claude/rules/snowflake-mcp.md` decides block-vs-warn at first touch based on table size, naming, and query shape.

## Calibrated tables

| Table | Artifact | Last calibrated | Schema hash (short) | Status | Notes |
|---|---|---|---|---|---|
| core.fct_events | [core__fct_events.md](core__fct_events.md) | 2026-04-24 | `efbb001b` | current | Initial seed |
| _external_statsig.exposures | [_external_statsig__exposures.md](_external_statsig__exposures.md) | 2026-04-24 | `1110ae4a` | current | Initial seed |
| core.fct_sessions_attribution | [core__fct_sessions_attribution.md](core__fct_sessions_attribution.md) | 2026-04-24 | `ecfdbcdd` | current | Initial calibration |
| core.dim_daily_kpis | [core__dim_daily_kpis.md](core__dim_daily_kpis.md) | 2026-04-24 | `b4a51e89` | current | Proactive calibration; Identity Check anchor for domain consolidation impact analysis |
| core.fct_sessions | [core__fct_sessions.md](core__fct_sessions.md) | 2026-04-24 | `b92eee13` | current | Domain consolidation + contamination zones documented |

<!-- /calibrate appends rows here as new tables are calibrated. No ordering implied — sort however is useful. -->

## Status legend

- **current** — `last_calibrated` within 30 days AND `schema_hash` matches live
- **stale (age)** — older than 30 days; contents may still be correct
- **stale (drift)** — `schema_hash` doesn't match live `information_schema` — refresh required
- **pending** — row reserved but no artifact yet (rare; typically only during directory setup)

## How tables land in this index

1. `/calibrate <schema.table>` — direct invocation; the user or Claude explicitly calibrates a table
2. `/sql` first-touch — a query against a table with no artifact triggers calibration per the rule's first-touch decision (block for fact-grain/large/raw; soft-warn for small dim tables)
3. `/preflight` — when a task is classified as Analysis, the target tables are checked against this index
4. `/evolve` — the retrospective step may propose updates to artifacts for tables touched in the session

## Seeded artifacts are not privileged

The two tables already calibrated above (`fct_events`, `exposures`) were the first seeds because they were the tables Claude was already holding context for at the time of scaffolding. They are not inherently more important than any other table that later gets calibrated. Each artifact stands on its own merit.
