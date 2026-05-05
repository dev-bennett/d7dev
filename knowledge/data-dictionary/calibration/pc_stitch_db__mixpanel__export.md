---
table: pc_stitch_db.mixpanel.export
last_calibrated: 2026-04-27
schema_hash: 956af91db4486f7635eef213642513d32615b18265d06ed18a30022e74ca4ae1
dbt_model: none
row_count: 2182283382
bytes_gib: 233.5
col_count: 491
---

# pc_stitch_db.mixpanel.export — Calibration

## Purpose (business meaning)

Raw Mixpanel event export landed by Stitch into Snowflake. This is the source-of-truth for all behavioral tracking events on soundstripe.com and app.soundstripe.com. Every user interaction Mixpanel tracks — page views, searches, plays, purchases, sign-ups, feature interactions — lands here before any transformation. Because this is a raw/external source with no dbt model of its own, there is no schema.yml description; the purpose is inferred from downstream dbt models (`stg_events.sql`, `fct_events.sql`) and prior analysis usage.

This table is the only warehouse location that retains columns dropped by `core.fct_events`: `USER_AGENT`, `USER_IP`, `MP_LIB`, `MP_RESERVED_SCREEN_HEIGHT`, `MP_RESERVED_SCREEN_WIDTH`, `MP_RESERVED_INITIAL_REFERRER`, `MP_RESERVED_INITIAL_REFERRING_DOMAIN`, and spatial autocapture properties (`MP_RESERVED_PAGEY`, `MP_RESERVED_PAGEHEIGHT`, `MP_RESERVED_MAX_SCROLL_PERCENTAGE`, etc.). Query the raw export when those fields are required.

**dbt_model:** `none` — this is a raw/external Stitch-replicated source. The declared dbt source is `mixpanel.export` in `context/dbt/models/staging/mixpanel/src_mixpanel.yml`. Downstream consumers: `stg_events.sql` (staging view) and `fct_events.sql` (incremental mart).

## Lineage

- **dbt model:** `none` — raw Stitch export; registered as `source("mixpanel", "export")` in `context/dbt/models/staging/mixpanel/src_mixpanel.yml`
- **Upstream sources:** Mixpanel event export via Stitch Singer tap; replication is append-based with `__SDC_PRIMARY_KEY` as the surrogate key. Stitch uses `_SDC_BATCHED_AT` / `_SDC_RECEIVED_AT` timestamps to track replication batches — **not** the event `TIME` column. Events can arrive in Stitch out of order with respect to their `TIME` value (Finding 4 in WCPM audit — see Known Pitfalls below).
- **Direct dbt consumers:**
  - `context/dbt/models/staging/mixpanel/stg_events.sql` → view over this table; adds URL parsing, channel attribution logic, page_category classifier, and session boundary markers
  - `context/dbt/models/marts/core/fct_events.sql` → incremental mart (`unique_key = '__sdc_primary_key'`); sources directly from this table (not from stg_events); adds session_id join, broader channel attribution logic, and additional event properties
  - `context/dbt/models/transformations/mixpanel/experiments.sql` — references this table
  - `context/dbt/models/transformations/mixpanel/identify.sql` — references this table
  - `context/dbt/models/transformations/mixpanel/dim_mixpanel_cart_events_build.sql` — references this table
  - `context/dbt/models/marts/looker_tables/wcpm_engagement_20250108.sql` — references this table
- **dbt tags:** not documented in src_mixpanel.yml (no tags defined)
- **Materialization:** raw table — Stitch-managed append/upsert. No dbt materialization applies.
- **Incremental watermark behavior:** Stitch replicates using `_SDC_BATCHED_AT` / `_SDC_RECEIVED_AT`, not `TIME`. An event can have `TIME = 2026-03-22` but `_SDC_RECEIVED_AT = 2026-03-23`. Downstream incremental dbt models that filter on `event_ts` (derived from `TIME`) will silently drop such events if their watermark has already advanced past the event's `TIME` date. This is confirmed for `_external_statsig.statsig_clickstream_events_etl_output` (OPEN structural issue — see Known Pitfalls).

## Columns (primary + frequently used)

Table has 491 columns — all TEXT except `TIME` (TIMESTAMP_TZ), `_SDC_BATCHED_AT` (TIMESTAMP_TZ), `_SDC_EXTRACTED_AT` (TIMESTAMP_TZ), `_SDC_RECEIVED_AT` (TIMESTAMP_TZ), `_SDC_SEQUENCE` (NUMBER), `_SDC_TABLE_VERSION` (NUMBER). All columns nullable except `__SDC_PRIMARY_KEY`.

Full schema: see `pc_stitch_db.information_schema.columns` (491 columns total).

| Column | Type | Description | Known nulls / gotchas |
|---|---|---|---|
| `__SDC_PRIMARY_KEY` | TEXT | Stitch-generated surrogate PK; used as `unique_key` in `fct_events` incremental logic | NOT NULL; format is a Mixpanel-generated hash |
| `DISTINCT_ID` | TEXT | Mixpanel anonymous or identified user identity. Pre-login: device ID (prefix `$device:`). Post-login: may be user_id or still device-prefixed depending on Mixpanel's identity resolution. | Nullable; coalesce with `MP_RESERVED_USER_ID` and `MP_RESERVED_DISTINCT_ID_BEFORE_IDENTITY` in downstream models |
| `EVENT` | TEXT | Event name string as instrumented in Mixpanel. Includes both custom events (`'Purchased Add-on'`, `'Created Subscription'`, `'Searched Songs'`) and Mixpanel autocapture events (`'$mp_page_leave'`, `'$mp_dead_click'`, `'$mp_session_record'`). | Filtered to exclude `'Called API Endpoint'`, `'$identify'`, `'$create_alias'` in `stg_events`; also excludes `'$mp_session_record'`, `'$mp_page_leave'`, `'$mp_dead_click'` in `fct_events` |
| `TIME` | TIMESTAMP_TZ | Event timestamp as recorded by Mixpanel client. This is the canonical event time used in downstream analytics. | NOT the replication ordering column — Stitch may deliver rows with older `TIME` values after its watermark has advanced; late-arriving rows are dropped by incremental models that filter on `event_ts` |
| `_SDC_RECEIVED_AT` | TIMESTAMP_TZ | Timestamp when Stitch received/replicated the row. Used as tiebreaker in `fct_events` dedup window: `ORDER BY _SDC_RECEIVED_AT ASC` | Always populated for replicated rows |
| `_SDC_BATCHED_AT` | TIMESTAMP_TZ | Timestamp of the Stitch batch that delivered this row | Always populated |
| `CURRENT_ADDONS` | TEXT | Comma-separated list of add-on product slugs active on the user's account at event time. Used to identify WCPM add-on purchasers: `ILIKE '%warner%'` or `ILIKE '%warner-chappell%'`. | Populated only on purchase/subscription events; NULL on most events |
| `ADD_ON_ID` | TEXT | Specific add-on product ID for the purchased add-on (ordinal 466). | Populated on `'Purchased Add-on'` events; NULL elsewhere |
| `CURRENT_PLAN_ID` | TEXT | Plan ID active on the user's account at event time (e.g., `'pro-monthly-usd'`, `'wcpm-monthly'`). | String `'None'` is used to represent no plan (not SQL NULL); downstream models filter `!= 'None'` |
| `CURRENT_PLAN_NAME` | TEXT | Human-readable plan name corresponding to `CURRENT_PLAN_ID`. | Same `'None'` string convention applies |
| `STATSIG_STABLE_ID` | TEXT | Statsig's `stable_id` property written to Mixpanel events by the Statsig SDK. Links events to Statsig experiment exposures. | 98.96% fill rate on `'Purchased Add-on'` events (q2, WCPM audit). Also see `STATSTIG_STABLE_ID` (ordinal 370) — a misspelled duplicate that appears to be a legacy/parallel property |
| `WCPM_PRICING_VARIANT` | TEXT | Pricing variant property for the WCPM test (ordinal 486). Populated on events where the WCPM pricing panel was rendered. | Distinct from `STATSIG_STABLE_ID` — tracks which pricing variant the user saw, not which Statsig arm they were assigned |
| `MP_RESERVED_MAX_SCROLL_PERCENTAGE` | TEXT | Autocapture scroll depth (0–100) on `$mp_page_leave` events. **BROKEN since 2026-02-25 on pricing URLs** (OPEN issue — see Known Pitfalls). | Near-zero fill on pricing URLs from 2026-02-25 onward; fill rate dropped from 100% to 1.7% on 2026-02-25, then to 0% from 2026-02-26 onward |
| `MP_RESERVED_PAGEY` / `MP_RESERVED_PAGEHEIGHT` | TEXT | Autocapture click position. **BROKEN since 2026-02-25 on pricing URLs** (OPEN issue — see Known Pitfalls). | Pre: 5,441 users with data; post-2wk: 16 users; post-8wk-clean: 0 users |
| `USER_AGENT` | TEXT | Raw browser user-agent string. Dropped in `fct_events` — only available in this raw table. | Retained in raw export; absent from `core.fct_events` |
| `USER_IP` | TEXT | Client IP address. Dropped in `fct_events`. | Retained in raw export; absent from `core.fct_events` |
| `MP_LIB` | TEXT | Mixpanel SDK library identifier. Dropped in `fct_events`. | Retained in raw export; absent from `core.fct_events` |
| `MP_RESERVED_INITIAL_REFERRER` | TEXT | First-touch referrer URL captured at identity resolution. Dropped in `fct_events`. | Only available in raw export |
| `USER_ID` | TEXT | Application user_id attached to the event. Coalesced with `MP_RESERVED_USER_ID` and `MP_RESERVED_DISTINCT_ID_BEFORE_IDENTITY` in downstream models. | NULL for anonymous/pre-login events |
| `UTM_SOURCE` / `UTM_MEDIUM` / `UTM_CAMPAIGN` / `UTM_CONTENT` / `UTM_TERM` | TEXT | Session-level UTM parameters written by Mixpanel at session start. Used for channel attribution in both `stg_events` and `fct_events`. | Session-level — attached to the event that starts the session, not propagated to all events in the session |

**Columns dropped from `core.fct_events` (only available in raw export):**
`USER_AGENT`, `USER_IP`, `MP_LIB`, `MP_RESERVED_SCREEN_HEIGHT`, `MP_RESERVED_SCREEN_WIDTH`, `MP_RESERVED_INITIAL_REFERRER`, `MP_RESERVED_INITIAL_REFERRING_DOMAIN`, `MP_RESERVED_MAX_SCROLL_PERCENTAGE`, `MP_RESERVED_PAGEY`, `MP_RESERVED_PAGEHEIGHT`, `MP_RESERVED_PAGEX`, `MP_RESERVED_PAGEWIDTH`, `MP_RESERVED_SCREENY`, `MP_RESERVED_SCREENX`, `MP_RESERVED_CLIENTX`, `MP_RESERVED_CLIENTY`, `MP_RESERVED_OFFSETX`, `MP_RESERVED_OFFSETY`, `MP_RESERVED_Y`, `MP_RESERVED_X`, `MP_RESERVED_SCROLL_HEIGHT`, `MP_RESERVED_MAX_SCROLL_VIEW_DEPTH`, `MP_RESERVED_FOLD_LINE_PERCENTAGE`, `MP_RESERVED_MP_REPLAY_ID`, `REPLAY_ENV`, `REPLAY_REGION`, `REPLAY_VERSION`, `REPLAY_LENGTH_MS`, `REPLAY_START_URL`, `REPLAY_START_TIME`, and all `CONVERT___TEST__*` / `CONVERT___*` A/B test columns. Note: this list is the set of columns present in the raw source but not extracted by `fct_events.sql` — inferred from the SELECT list in that model, not from a schema comparison query.

## Canonical joins

| To table | On | Cardinality | Notes |
|---|---|---|---|
| `core.fct_events` | `pc_stitch_db.mixpanel.export.__SDC_PRIMARY_KEY = core.fct_events.__sdc_primary_key` | 1:1 (at most) | `fct_events` deduplicates and applies exclusion filters; not all raw rows survive. Join backwards (raw → fct) to find dropped events. |
| `_external_statsig.statsig_clickstream_events_etl_output` | Via `fct_events` → Statsig model on `__sdc_primary_key` / `event_id` | 1:1 (at most) | An additional drop layer beyond fct_events: the Statsig model's incremental predicate drops late-arriving fct_events rows (see Known Pitfalls) |
| `_external_statsig.first_exposures_wcpm_pricing_test` | Via `STATSIG_STABLE_ID` or `DISTINCT_ID` → `user_id` in the exposures table | N:1 | Requires identity resolution; `STATSIG_STABLE_ID` field has ~99% fill on purchase events but varies by event type |

**Canonical pattern for "raw-Mixpanel attributes at merged-user grain":** see `knowledge/query-patterns/merged_user_attribute_fold.sql`. Full lineage `mixpanel.export → fct_events → dim_session_mapping → fct_sessions` with per-user `BOOLOR_AGG` / `MAX_BY` fold (no fan-out). Use this pattern whenever you need raw-only columns (`mp_reserved_browser`, `mp_reserved_device`, `user_agent`, `mp_lib`, screen dims, scroll/click-position, `mp_reserved_initial_referrer`) attached to a merged user identity.

## Grain & identity

- **Grain:** one row per Mixpanel event as replicated by Stitch. A single user action may produce multiple rows if Mixpanel fires duplicate events (observed: 5 raw rows for a single `'Purchased Add-on'` action for one user in the WCPM audit, compressed to 1 row after fct_events dedup via QUALIFY window).
- **Primary key:** `__SDC_PRIMARY_KEY` (Stitch surrogate, NOT NULL). This is the `unique_key` in `fct_events`.
- **Distinct-user column:** `DISTINCT_ID` — Mixpanel's identity identifier. For analytics requiring application user_id, coalesce: `COALESCE(USER_ID, MP_RESERVED_USER_ID, MP_RESERVED_DISTINCT_ID_BEFORE_IDENTITY)`. For Statsig experiment joins, use `STATSIG_STABLE_ID`.
- **Dedup note:** `fct_events` deduplicates using `QUALIFY ROW_NUMBER() OVER(PARTITION BY DISTINCT_ID, time, event, COALESCE(song_id, SOUND_EFFECT_ID, 'no_song_id') ORDER BY _SDC_RECEIVED_AT ASC) = 1`. The raw table itself is not deduplicated.

## Typical usage patterns

- **Date scoping:** mandatory for any non-metadata query. 2.18B rows total, ~233.5 GiB. With a 30-day date filter on `TIME`, expect tens of millions of rows. Use `TIME::date >= '<start_date>' AND TIME::date < '<end_date>'`.
- **WCPM add-on purchase queries:** `WHERE event = 'Purchased Add-on' AND current_addons ILIKE '%warner%'` — filters to WCPM add-on purchases. Do not use `current_plan_id IN ('wcpm-monthly', 'wcpm-yearly')` — the WCPM product is an add-on, not a base plan (q2 in WCPM audit confirmed 0 rows with that filter vs. 23 with the `current_addons ILIKE '%warner%'` filter).
- **Event-type exclusions applied in fct_events:** `'Called API Endpoint'`, `'$identify'`, `'$create_alias'`, `'$mp_session_record'`, `'$mp_page_leave'`, `'$mp_dead_click'`. Raw queries against this table will include all of these unless explicitly excluded.
- **Bot/internal host exclusions applied in fct_events but NOT in this raw table:** IP-address-format hosts (`104.131.162.177`, etc.), `app-web.soundstripe.com`, `nxcpower.com`, external event sources (`event_source IN ('twitch', 'adobe express')`), and the project-overtake anonymous sessions (`time < 2025-07-27 AND event_source = 'web'`). Raw queries must re-apply these if comparability with fct_events is needed.
- **Canonical queries:** `analysis/experimentation/2026-04-18-wcpm-test-audit/console.sql` — q0–q23a; comprehensive query set for WCPM add-on purchase analysis against this table. Reference for field usage patterns and join logic.
- **Rows/day estimate:** at 2.18B rows and multi-year history, approximately 1–3M events/day depending on period (volume has grown over time).

## Known pitfalls

1. **Stitch replication ordering vs. event TIME (OPEN — Finding 4, WCPM audit 2026-04-18).** Stitch replicates using `_SDC_BATCHED_AT` / `_SDC_RECEIVED_AT`, not `TIME`. An event can have `TIME = 2026-03-22 19:53:40` but arrive in Stitch on `2026-03-23 ~15:19`. Downstream incremental dbt models that use `event_ts >= max(event_ts)::date from this` as their watermark will permanently skip that row once their watermark advances past `2026-03-22`. Confirmed concrete instance: `distinct_id = '$device:1939e3fa043955-…'`, `__sdc_primary_key = 'a7a9fe2a-2c96-4101-a041-bd6d40fdc329'` — present in `fct_events`, absent from `statsig_clickstream_events_etl_output`. Source: `project_statsig_model_late_arrival_open.md`, `analysis/experimentation/2026-04-18-wcpm-test-audit/findings.md` Finding 4. **Affects any metric powered by `statsig_clickstream_events_etl_output` — directional undercount is permanent for affected rows.**

2. **Autocapture spatial-property collapse since 2026-02-25 (OPEN — pricing URLs, possibly platform-wide).** `MP_RESERVED_MAX_SCROLL_PERCENTAGE` on `$mp_page_leave` events dropped from 100% fill to 1.7% on 2026-02-25 and to 0% from 2026-02-26 onward on pricing URLs. `MP_RESERVED_PAGEY` / `MP_RESERVED_PAGEHEIGHT` on click events dropped similarly. Leading hypothesis: the 2026-02-24 pricing-page banner-shrink deploy migrated Mixpanel from autocapture-heavy mode to Session Replay, moving spatial scalars into replay recordings (not warehouse-replicated). Unconfirmed by engineering as of 2026-04-27. **Scroll-depth and click-position analytics for pricing pages (and possibly all pages) from 2026-02-25 onward are not recoverable from warehouse data.** Source: `project_mixpanel_autocapture_collapse_open.md`, `analysis/experimentation/2026-04-23-pricing-page-scroll-depth/findings.md`.

3. **`CURRENT_PLAN_ID` uses string `'None'` for no-plan, not SQL NULL.** The value `'None'` (string) appears in `CURRENT_PLAN_ID` when no plan is active. Downstream models filter `!= 'None'`. A `WHERE current_plan_id IS NOT NULL` filter will NOT exclude these rows — they will pass and look like valid plan-holding users.

4. **`page_category` classifier broken post-domain-consolidation (OPEN).** The `stg_events.sql` model's `page_category` CASE statement uses exact `host` + `path` matching (`host = 'www.soundstripe.com'` and `path = 'pricing'`). After the March 2026 domain consolidation (www+app → soundstripe.com via Fastly), pricing/checkout/signup/sign_in paths moved under `/library/` on the unified domain, breaking the exact-match classifier. This affects `stg_events` not the raw table, but any analysis relying on `page_category` derived from this raw table via the same logic will produce near-zero counts for these pages from 2026-03-17 onward. Source: `project_page_category_classifier_broken_open.md`.

5. **Mixpanel weekly-bucket UX quirk.** When Mixpanel UI reports a weekly bucket (e.g., week of 2026-03-09), it includes ALL events from that calendar week regardless of the filter's start date. If the filter starts 2026-03-13, the week-of-03-09 bucket will still include events from 2026-03-09 through 2026-03-12. This inflates the first bucket in any Mixpanel-exported report. Raw warehouse queries filtered on `TIME >= '2026-03-13'` will correctly exclude those events. Source: `analysis/experimentation/2026-04-18-wcpm-test-audit/findings.md` Finding 3 (−4 reconciliation item).

6. **491 columns, all TEXT except TIME and Stitch metadata.** Mixpanel's column-per-property schema grows every time a new event property is added. Columns are sparse — most properties are NULL on most events. No VARIANT/OBJECT consolidation; each property is its own column. Queries using `SELECT *` on large date ranges will be slow and wide; always enumerate columns. `CONVERT___TEST__*` and `CONVERT___*` columns (A/B test properties from a Convert.com integration) are numerous and typically NULL except during specific test windows.

7. **`STATSTIG_STABLE_ID` (typo) vs. `STATSIG_STABLE_ID` (correct).** Both columns exist in the schema (ordinals 369 and 370 respectively). The typo column (`STATSTIG_STABLE_ID`) appears to be a legacy or parallel write path. For Statsig joins, use `STATSIG_STABLE_ID`.

8. **`project-overtake` session contamination pre-2025-07-27.** Events with `event_source = 'web'` before `2025-07-27` include duplicate/anonymous sessions from a period when distinct_ids were not properly reconciled between React and the Overtake project. `fct_events` excludes these rows. Raw queries spanning that period will include them unless the same predicate is applied.

## Cost profile (from query_history)

- **Query history rows available:** 3 (metadata/schema queries only — all against `information_schema`, not row-scanning the table itself)
- **P50 elapsed (metadata queries):** 826ms
- **P95 elapsed (metadata queries):** 1,564ms
- **Bytes scanned (metadata queries):** 544–13,632 bytes (schema lookups, no data scanned)
- **Estimated cost for date-scoped aggregate on X-Small warehouse:** approximately $0.01–$0.03 for a 30-day window aggregate. Full-table scan without date predicate: **do not run** — 233.5 GiB is approximately $0.70–$1.00 on X-Small.
- **Avoid:** `SELECT *` row-returning queries without `LIMIT`; full-table scans without `TIME::date` predicate; any query that joins to `fct_events` on unbounded time ranges (fan-out risk from Stitch duplicate rows).
- **Required:** every query must include a `TIME::date` range predicate OR be an explicit all-time aggregate with a comment justifying the full scan.

## Prior analyses referencing this table

- [analysis/experimentation/2026-04-18-wcpm-test-audit/](../../../analysis/experimentation/2026-04-18-wcpm-test-audit/) — Mixpanel vs. Statsig reconciliation for WCPM pricing test; 23 add-on purchasers identified using `event = 'Purchased Add-on' AND current_addons ILIKE '%warner%'`; confirmed late-arrival drop (Finding 4) and identifier-mapping exclusion (Finding 6); q0–q23a in `console.sql`
- [analysis/experimentation/2026-04-23-pricing-page-scroll-depth/](../../../analysis/experimentation/2026-04-23-pricing-page-scroll-depth/) — Autocapture spatial-property collapse investigation; confirmed `MP_RESERVED_MAX_SCROLL_PERCENTAGE` and `MP_RESERVED_PAGEY/PAGEHEIGHT` stopped populating on pricing URLs 2026-02-25; D9, D11, D13 in `diagnose/discovery.sql`
- [analysis/data-health/2026-04-24-domain-consolidation-impact/](../../../analysis/data-health/2026-04-24-domain-consolidation-impact/) — Domain consolidation artifact session investigation; referenced raw Mixpanel for `MP_RESERVED_CURRENT_URL` / host breakdowns
- [analysis/data-health/2026-04-27-domain-consolidation-non-customer/](../../../analysis/data-health/2026-04-27-domain-consolidation-non-customer/) — Non-customer domain consolidation analysis; queries reference raw Mixpanel for URL/host patterns

## LookML semantics (if applicable)

No LookML view sources directly from `pc_stitch_db.mixpanel.export`. LookML reporting consumes the downstream transformed tables:

- `soundstripe_prod.CORE.FCT_EVENTS` — primary LookML surface; accessed through `fct_events` view and its explores in `General.model.lkml`
- `soundstripe_prod.CORE.FCT_SUBSCRIBER_ACTIVITY_MIXPANEL` — subscriber-level activity rollup sourced indirectly from Mixpanel events; view in `context/lookml/views/Mixpanel/fct_subscriber_activity_mixpanel.view.lkml`
- `context/lookml/views/_TEMP_VIEWS/wcpm_engagement.view.lkml` — temporary view for WCPM engagement analysis

For WCPM-specific reporting, the `WCPM_PRICING_VARIANT` dimension and `STATSIG_STABLE_ID` are the key linkage columns between this raw source and the Statsig experiment tables.
