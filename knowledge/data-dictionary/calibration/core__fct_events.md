---
table: core.fct_events
last_calibrated: 2026-04-24
schema_hash: efbb001bf0c8589c6e7dfad034c352356ec369084b4e13b9cd5f6395316cffb9
dbt_model: marts/core/fct_events.sql
row_count: 1293618698
bytes_gib: 75.18
col_count: 70
---

# core.fct_events — Calibration

## Purpose (business meaning)

One row per Mixpanel-captured user event. The canonical event-grain fact table for product analytics — pageviews, plays, searches, signup/checkout steps, subscription events. Sourced from Stitch-replicated Mixpanel data; covers roughly 5 years of history. `~700K rows/day` on average; span 2021-03-24 → today.

## Lineage

- **dbt model:** `context/dbt/models/marts/core/fct_events.sql`
- **Upstream sources:** `pc_stitch_db.mixpanel.export` (Stitch-replicated Mixpanel raw)
- **Materialization:** `incremental` with `unique_key = __sdc_primary_key` and `on_schema_change = sync_all_columns`
- **Incremental watermark behavior:** filters on `time` column from the source; late-arriving rows may or may not be picked up depending on replication cadence. Downstream Statsig models drop late-arrival rows — see pitfalls.

## Columns (primary + frequently used)

| Column | Type | Source | Description | Known nulls / gotchas |
|---|---|---|---|---|
| `__sdc_primary_key` | TEXT | Stitch-generated | Unique row identifier | PRIMARY KEY; never NULL |
| `distinct_id` | TEXT | Mixpanel | Client-side distinct ID (pre-identity) | Always populated |
| `user_id` | TEXT | coalesce(user_id, mp_reserved_user_id, mp_reserved_distinct_id_before_identity) | Post-identity user ID | NULL for pre-identify events |
| `session_id` | TEXT | derived | Session identifier **on the event side** | Joins to `fct_sessions` ONLY via `dim_session_mapping.session_id_events → session_id`. Do NOT join directly |
| `event` | TEXT | Mixpanel | Event name (e.g., `"Viewed Pricing Page"`) | Free-text; case matters |
| `event_ts` | TIMESTAMP_NTZ | `time::timestamp` | Event timestamp | NEVER unbounded; always date-scope queries |
| `url` / `path` / `host` | TEXT / TEXT / TEXT | `coalesce(current_url, mp_reserved_current_url, url)` then parsed | Normalized URL + parts | Pre-March 2026, `host` was `www.soundstripe.com` or `app.soundstripe.com`; post-consolidation, everything is `soundstripe.com` with `/library/*` paths |
| `page_category` | TEXT | `stg_events.sql` classifier | Canonical page category | **BROKEN** for pricing/checkout/signup/sign_in since 2026-03-17 — exact-match classifier fails on `/library/*` paths. OPEN. |
| `channel` | TEXT | attribution logic | Session-level marketing channel | Non-direct-last-touch logic in `fct_sessions` |
| `utm_source` / `utm_medium` / `utm_campaign` | TEXT | URL parameters | Attribution params at event time | May differ from `fct_sessions` attribution (which is session-level, non-direct-last-touch) |
| `statsig_stable_id` | TEXT | Mixpanel property | Statsig stable identifier for exposure bridging | Post-consolidation stable_id sprawl — see statsig exposure calibration |
| `inactivity_minutes` / `is_new_session` | NUMBER / NUMBER | derived | Session boundary fields | Used to define session_id |
| `event_counter` | NUMBER | derived | Per-user event sequence counter |  |

Full schema (70 cols): `SELECT column_name, data_type FROM soundstripe_prod.information_schema.columns WHERE table_schema = 'CORE' AND table_name = 'FCT_EVENTS' ORDER BY ordinal_position`.

### Columns DROPPED from upstream source

`fct_events` does **NOT** carry the following from `pc_stitch_db.mixpanel.export`:
- `USER_AGENT`, `IP` (bot/device classification)
- `MP_LIB` (SDK library / version)
- Screen dimensions (`mp_reserved_screen_*`)
- `initial_referrer`
- `mp_reserved_max_scroll_percentage`, `mp_reserved_pagey`, `mp_reserved_pageheight` (see autocapture-collapse pitfall)

If these are needed, query `pc_stitch_db.mixpanel.export` directly (see that table's calibration).

## Canonical joins

| To table | On | Cardinality | Notes |
|---|---|---|---|
| `core.dim_session_mapping` | `fct_events.session_id = dim_session_mapping.session_id_events` | M:1 | **Mandatory bridge** — `fct_events.session_id ≠ fct_sessions.session_id`. See memory `reference_session_event_join.md` |
| `core.fct_sessions` | via `dim_session_mapping` (two hops) | M:1 per session | Do not attempt a direct join |
| `_external_statsig.exposures` | `fct_events.statsig_stable_id = exposures.stable_id` AND `user_id` agreement | N:M (sprawl) | Post-consolidation stable_id sprawl affects `user_id ↔ stable_id` stability — see exposures calibration |

## Grain & identity

- **Grain:** one row per Mixpanel event (post-dedup via `__sdc_primary_key`)
- **Primary key:** `__sdc_primary_key`
- **Distinct-user column:** usually `distinct_id` for broad event counting; `user_id` for authenticated/known-user analyses. `user_id` is `COALESCE(user_id, mp_reserved_user_id, mp_reserved_distinct_id_before_identity)` in the model

## Typical usage patterns

- **Date scoping:** typical window is 7–30 days; rows/day ≈ 700K. A 30-day window scans ~20M rows, typically <10 GB on X-Small, <5s elapsed
- **Common filters:** `event IN ('Viewed Pricing Page', 'Clicked Subscribe', ...)`, `event_ts >= DATEADD(...)`
- **Canonical queries:** see `knowledge/query-patterns/session_event_bridge.sql`, `knowledge/query-patterns/schema_snapshot.sql`, `knowledge/query-patterns/step_rate_with_nesting.sql`

## Known pitfalls

- **`page_category` classifier broken (OPEN)** — exact-match classifier in `stg_events.sql` returns near-zero for pricing/checkout/signup/sign_in from 2026-03-17 after domain consolidation moved paths under `/library/`. Do not filter on `page_category` for these categories; filter on `path LIKE '%/library/pricing%'` etc. See `project_page_category_classifier_broken_open.md`.
- **Mixpanel autocapture collapse (OPEN)** — `mp_reserved_max_scroll_percentage`, `mp_reserved_pagey`, `mp_reserved_pageheight` stopped populating on pricing URLs 2026-02-25. `$mp_session_record` turned on 2026-03-01. Warehouse-side scroll / click-position recovery impossible for Feb 25 – Apr 23. These fields are dropped from `fct_events` anyway, but note that the upstream source is also gap-filled for this period. See `project_mixpanel_autocapture_collapse_open.md`.
- **Statsig late-arrival drop (OPEN, downstream)** — `statsig_clickstream_events_etl_output` incremental predicate drops `fct_events` rows with `event_ts` older than the current watermark. If analyzing experiments, pull from `_external_statsig.exposures` for first-exposure, not the downstream clickstream table. See `project_statsig_model_late_arrival_open.md`.
- **Session bridge trap** — `fct_events.session_id` and `fct_sessions.session_id` are different concepts. Direct joins silently return wrong cardinality. Always bridge via `dim_session_mapping`.
- **Domain consolidation artifact (ongoing)** — March 2026 consolidation caused ~200K artifact sessions 03/05–03/25 via Fastly recrawl. Check `session_id` cardinality and `host` distribution for windows crossing this period.
- **UTM drift** — `fct_events` UTM columns are event-time values. For **session-level attribution**, use `fct_sessions.utm_*` (non-direct-last-touch).

## Cost profile (from query_history; EMBEDDED_ANALYST, 31 recent queries against this table)

- **Date-scoped aggregates (1–7 day window):** elapsed 300–1000 ms, bytes scanned 100–500 MB
- **Date-scoped with 1–2 JOINs to dims:** elapsed 4–8 s, bytes scanned 5–15 GB
- **Multi-window analytical queries (WCPM-style):** elapsed 60–120 s, bytes scanned 400–800 GB — this is the upper practical bound on X-Small; larger should move to dbt
- **Avoid:** full-table scans (5 years × 700K/day = 1.29B rows), `SELECT *` on large windows, unbounded date predicates

## Prior analyses referencing this table

- `analysis/experimentation/2026-04-18-wcpm-test-audit/` — pulse reconciliation + step-rate nesting fixes
- `analysis/experimentation/2026-04-23-pricing-page-scroll-depth/` — scroll-depth investigation (led to autocapture-collapse finding)
- `analysis/**/direct-traffic-spike-*` — 2026-04-01 and 2026-04-17 spike investigations (bot / Fastly recrawl hypothesis)
- Multiple MQL / pricing-analysis / tracking analyses across `analysis/`

## LookML semantics

Primary LookML view is in `context/lookml/views/General/` (likely `fct_events.view.lkml` or similar — grep `context/lookml/views/` for `sql_table_name.*fct_events` to locate). Key measures typically include `count_events`, `count_unique_users`, with dimensions on `event`, `page_category`, `channel`, `utm_source`.
