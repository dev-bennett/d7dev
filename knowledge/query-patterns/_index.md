# Query Patterns Index

Canonical, reusable SQL patterns. See `CLAUDE.md` for promotion rules and file conventions.

## By topic

### Schema discovery / pre-flight

- `schema_snapshot.sql` — row count, date range, and PK null rate for any table. Run before writing queries against an unfamiliar table
- `column_existence.sql` — confirm columns exist in a table before referencing them. Guards against `feedback_verify_before_writing`

### Joins

- `session_event_bridge.sql` — bridge `fct_events` and `fct_sessions` via `dim_session_mapping` (they do NOT join directly). Pattern encoded in `reference_session_event_join`

### Cohort pulls

- `statsig_exposure_cohort.sql` — canonical exposed-user pull for a Statsig experiment, applying the 1:1 identifier-mapping exclusions documented in `knowledge/domains/experimentation/identifier-mapping-and-exclusions.md`

### Rate templates

- `step_rate_with_nesting.sql` — funnel step-rate template that enforces population nesting (step N INNER JOIN step N-1) per `sql-snowflake.md` STEP NESTING AUDIT and `feedback_population_nesting_in_step_rates`

## By table

| Table | Patterns |
|-------|----------|
| `fct_events` | `schema_snapshot`, `column_existence`, `session_event_bridge` |
| `fct_sessions` | `schema_snapshot`, `session_event_bridge` |
| `dim_session_mapping` | `session_event_bridge` |
| `dim_daily_kpis` | `schema_snapshot` |
| Statsig exposure tables | `statsig_exposure_cohort` |
| Any | `schema_snapshot`, `column_existence`, `step_rate_with_nesting` |

## Adding a new pattern

1. Confirm it has been used in ≥2 analyses (cite them in the header)
2. Create the `.sql` file with the standard header block
3. Add a bullet above under the appropriate topic
4. Add a row to the table above
5. If the pattern encodes a correctness requirement from a feedback memory, reference the memory in the header
