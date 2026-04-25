---
table: soundstripe_prod.core.fct_sessions_attribution
last_calibrated: 2026-04-24
schema_hash: ecfdbcdd96b78aace0877554a678e1a73945c76d82365aae6f6ae250abd3182c
dbt_model: marts/core/fct_sessions_attribution.sql
row_count: 60277421
bytes_gib: 3.27
col_count: 16
---

# core.fct_sessions_attribution — Calibration

## Purpose (business meaning)

Multi-touch attribution fact table. For each session in `fct_sessions`, this table expands the session into one row per attribution touchpoint, representing each non-direct session in the 30-day lookback window. A U-shaped weighting model distributes credit (40% first touch, 40% last touch, 20% split across middle touches). Sessions with no non-direct touchpoints in the 30-day window receive a single row with `touch_channel = 'Direct'` and `attribution_credit = 1.0`. The table supports channel-weighted attribution queries without requiring analysts to re-implement the lookback and weighting logic inline.

Description missing from dbt schema.yml (no schema.yml exists in `context/dbt/models/marts/core/`). Description above is derived from model SQL.

## Lineage

- **dbt model:** `context/dbt/models/marts/core/fct_sessions_attribution.sql`
- **Upstream sources:** `{{ ref("fct_sessions") }}` — referenced three times (as `target_sessions`, as the historical touchpoint pool, and in the `direct_sessions` NOT EXISTS subquery)
- **dbt tags:** none declared
- **Materialization:** `table` — from `dbt_project.yml` `marts.core: +materialized: table`. No `{{ config(...) }}` block in the model file; no `unique_key`, no incremental strategy
- **Incremental watermark behavior:** not applicable — full `table` materialization. Every dbt run rebuilds the entire table from current `fct_sessions`

## Columns (primary + frequently used)

| Column | Type | Source | Description | Known nulls / gotchas |
|---|---|---|---|---|
| `session_id` | TEXT | `fct_sessions.session_id` (target session) | The session being attributed — the destination of traffic | Not a true unique key; one row per touch per session. Multiple rows per `session_id` when `total_touches > 1` |
| `distinct_id` | TEXT | `fct_sessions.distinct_id` | User identifier for the target session | Always populated (sourced from `fct_sessions` with `WHERE distinct_id IS NOT NULL`) |
| `session_started_at` | TIMESTAMP_NTZ | `fct_sessions.session_started_at` (target) | When the target session started | Use this to date-scope; it is the target session's timestamp, not the touch timestamp |
| `touch_session_id` | TEXT | `fct_sessions.session_id` (touchpoint) | Session ID of the attributed touchpoint. Equals `session_id` when direct (only touch = itself) | For direct-only sessions, `touch_session_id = session_id` |
| `touch_session_started_at` | TIMESTAMP_NTZ | `fct_sessions.session_started_at` (touchpoint) | When the touchpoint session started | Earlier than or equal to `session_started_at` |
| `touch_position` | NUMBER | `ROW_NUMBER()` over session | Ordinal position of this touch in the 30-day chain (1 = first, `total_touches` = last) | Always 1 for direct-only sessions |
| `total_touches` | NUMBER | `COUNT(*)` over session | Total number of non-direct touchpoints in the 30-day lookback | 1 for direct-only sessions |
| `touch_channel` | TEXT | `NVL(fct_sessions.channel, 'Direct')` | Channel of the touchpoint session. Direct sessions excluded from multi-touch pool; only surfaces as 'Direct' in the fallback CTE | Pure-Direct rows have `touch_channel = 'Direct'`. Never NULL — NVL applied |
| `attribution_credit` | NUMBER | U-shaped weighting formula | Credit weight for this touch (0.0–1.0). Sums to 1.0 per `session_id` | SUM(attribution_credit) WHERE session_id = X always equals 1.0 |
| `touch_utm_source` | TEXT | `fct_sessions.utm_source` | UTM source of the touchpoint session | NULL for direct-only rows |
| `touch_utm_medium` | TEXT | `fct_sessions.utm_medium` | UTM medium of the touchpoint session | NULL for direct-only rows |
| `touch_utm_campaign` | TEXT | `fct_sessions.utm_campaign` | UTM campaign of the touchpoint session | NULL for direct-only rows |
| `touch_referring_domain` | TEXT | `fct_sessions.referring_domain` | Referring domain of the touchpoint session | NULL for direct-only rows |
| `touch_referrer` | TEXT | `fct_sessions.referrer` | Full referrer URL of the touchpoint | NULL for direct-only rows |
| `touch_utm_content` | TEXT | `fct_sessions.utm_content` | UTM content of the touchpoint session | NULL for direct-only rows |
| `touch_utm_term` | TEXT | `fct_sessions.utm_term` | UTM term of the touchpoint session | NULL for direct-only rows |

## Canonical joins

| To table | On | Cardinality | Notes |
|---|---|---|---|
| `core.fct_sessions` | `fct_sessions_attribution.session_id = fct_sessions.session_id` | N:1 (attribution to session) | **Fan-out risk.** `fct_sessions_attribution` has multiple rows per `session_id` when `total_touches > 1`. A naive INNER JOIN back to `fct_sessions` will multiply session-level metrics by the touch count. Always aggregate attribution metrics first, then join, or use `WHERE touch_position = 1` / `WHERE touch_position = total_touches` for first/last-touch views |
| `core.fct_sessions` (touchpoint side) | `fct_sessions_attribution.touch_session_id = fct_sessions.session_id` | N:1 (touch to its session) | Used to pull additional touchpoint session attributes not stored in this table |

## Grain & identity

- **Grain:** one row per target-session × attribution-touchpoint. A session with 4 non-direct touches in the prior 30 days produces 4 rows. A pure-direct session produces 1 row
- **Primary key:** `(session_id, touch_session_id)` — composite; not declared in dbt (no schema.yml tests). For deterministic ordering within a session use `touch_position`
- **Distinct-user column:** `distinct_id` — same as `fct_sessions.distinct_id`; Mixpanel pre-identity distinct ID
- **Attribution model exposed:** U-shaped only. First-touch = `WHERE touch_position = 1`. Last-touch = `WHERE touch_position = total_touches`. Linear = treat each touch equally (uniform weight). Time-decay = not natively stored; must derive from `touch_session_started_at` vs `session_started_at` gap. Last-non-direct-touch = `WHERE touch_position = total_touches AND total_touches > 0` (all rows are non-direct in the multi-touch pool)

## Typical usage patterns

- **Date scoping:** scope on `session_started_at` (the target session's timestamp). At ~60M rows and 3.27 GiB, a 30-day window is approximately 5–6M rows. Always include a date predicate
- **Attribution-weighted channel analysis:** `SUM(attribution_credit)` grouped by `touch_channel` for a session population. The SUM is interpretable as "credited sessions" for that channel
- **First-touch analysis:** `WHERE touch_position = 1`; filter to a single row per session
- **Last-touch analysis:** `WHERE touch_position = total_touches`; filter to a single row per session
- **Direct-traffic attribution:** `WHERE touch_channel = 'Direct'` OR `WHERE total_touches = 1 AND touch_channel = 'Direct'` for pure-direct sessions
- **Canonical queries:** none yet in `knowledge/query-patterns/`; first use establishes the pattern

## Known pitfalls

1. **Fan-out on JOIN to fct_sessions (highest risk).** `fct_sessions_attribution` has N rows per `session_id` where N = `total_touches`. Any JOIN from `fct_sessions` to `fct_sessions_attribution` on `session_id` will multiply `fct_sessions` row counts by N. To get session-level attribution, either: (a) aggregate `fct_sessions_attribution` to session level first in a CTE, then JOIN; or (b) filter to a single touch per session (`touch_position = 1` or `= total_touches`) before joining. This is the most common fan-out pattern in this codebase.

2. **Domain consolidation artifact sessions in the touchpoint pool.** `fct_sessions_attribution` is built entirely from `fct_sessions`. The ~200K artifact sessions created during the March 2026 domain consolidation (03/05–03/25, Fastly recrawl) are present in `fct_sessions` and will therefore enter the 30-day touchpoint lookback pool for any target session starting between 03/05 and 04/24 (30 days after the last artifact session date). Attribution analyses covering the February–April 2026 period will contain contaminated touch data for sessions whose lookback window crosses 03/05–03/25. See memory `project_domain_consolidation.md` (OPEN).

3. **`touch_channel` vs `fct_sessions.channel` are different constructs.** `fct_sessions.channel` is the session's own `ENTRY_CHANNEL` — the first non-null channel across sub-sessions, a property of that one session. `touch_channel` in this table is `NVL(fct_sessions.channel, 'Direct')` for a historical touchpoint session evaluated in the context of the TARGET session's lookback window. Joining `fct_sessions_attribution.touch_channel` to `fct_sessions.channel` on the same session for comparison is valid; but the two columns answer different questions and should not be used interchangeably in multi-table analyses.

4. **Attribution model is U-shaped only; no last-non-direct-touch column.** The table does not store a `last_non_direct_channel` column equivalent to what Looker's `channel` or `fct_sessions.last_channel_non_direct` (if it exists) might expose. Simulating last-non-direct-touch requires `WHERE touch_position = total_touches` — which by construction already excludes Direct (the multi-touch pool filters `channel != 'Direct'`). Direct-fallback sessions are in a separate CTE and identifiable via `touch_channel = 'Direct' AND total_touches = 1`.

5. **Full table rebuild on every dbt run.** There is no `unique_key` or incremental strategy. Every production dbt run drops and rebuilds all 60M rows from `fct_sessions`. If `fct_sessions` is stale or being rebuilt concurrently, this table will reflect that staleness completely. Check `fct_sessions` `last_altered` before attributing discrepancies to this table.

6. **No LookML view exists for this table.** `fct_sessions_attribution` is not exposed in any Looker explore as of the current LookML submodule state. Any Looker-based attribution analysis uses `fct_sessions.channel` (first-touch / entry-channel logic) rather than U-shaped multi-touch credit. This creates a methodology gap between warehouse-based analyses and Looker dashboards.

## Cost profile (from query_history — 3 rows, minimal history)

3 queries found in recent history — below the threshold for stable P50/P95 estimates. Values are informational only.

- **Elapsed range:** 539–765 ms
- **Bytes scanned range:** 512–1,040 bytes (information_schema introspection queries only — no substantive scans recorded)
- **Estimated cost for date-scoped aggregates:** at 3.27 GiB total, a 30-day window of ~5M rows on X-Small should run in 1–5 seconds with a date predicate on `session_started_at`. Full-table scans at 60M rows will be proportionally slower
- **Avoid:** joining `fct_sessions_attribution` to `fct_sessions` without pre-aggregating (fan-out multiplies both row count and scan cost); unbounded scans (no date predicate); `SELECT *` in row-returning queries

## Prior analyses referencing this table

No prior analyses found in `analysis/` that reference `fct_sessions_attribution`. This is a first-calibration, not a refresh.

## LookML semantics

No LookML view sourced from `core.fct_sessions_attribution` exists in `context/lookml/views/`. The table is not currently exposed in Looker. The nearest related view is `context/lookml/views/Mixpanel/fct_sessions.view.lkml`, which sources from `soundstripe_prod.CORE.FCT_SESSIONS` and exposes `channel` (= `ENTRY_CHANNEL`, session-level first-touch) and `last_channel_non_direct` (if present). Those are single-touch metrics, not U-shaped credit.
