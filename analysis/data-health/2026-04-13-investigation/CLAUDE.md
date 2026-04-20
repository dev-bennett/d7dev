# 2026-04-13 Investigation

@../CLAUDE.md

Investigation into weekly `fct_sessions.total_revenue_per_session` anomaly: weeks of 2026-03-23 and 2026-03-30 returned 0; week of 2026-04-06 returned 1.17 (below the ~1.3–1.6 baseline for the prior 11 months).

## Working Files

- `console.sql` -- queries pasted/appended for execution against `soundstripe_prod`
- `results.csv` -- exported result sets (latest export: first query's weekly rate)

## Conventions

- Append new queries to `console.sql` with a `-- Query N` header and purpose comment
- Do not delete prior queries -- keep the full investigation trail
- Reference `soundstripe_prod.core.fct_sessions` (and its lineage: `fct_sessions_build_step2` -> `fct_sessions_build`) for diagnostic work
