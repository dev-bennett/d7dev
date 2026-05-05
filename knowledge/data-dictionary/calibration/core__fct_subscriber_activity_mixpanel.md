---
table: soundstripe_prod.core.fct_subscriber_activity_mixpanel
last_calibrated: 2026-04-30
schema_hash: 0f8720c59a2a43cacc0392b026d77da4411c02b940555c705779d2033d3f54e9
dbt_model: marts/core/fct_subscriber_activity_mixpanel.sql
row_count: 11134411
bytes_gib: 0.538
col_count: 31
---

# soundstripe_prod.core.fct_subscriber_activity_mixpanel — Calibration

## Purpose (business meaning)

One row per subscriber × session. Joins every Soundstripe subscription period to every Mixpanel-derived session attributed to that subscription, enriching each session row with per-session engagement counts (downloads, plays, favorites, projects) and subscription metadata (plan, billing period, HubSpot company/deal linkage). Powers the subscriber engagement KPI tiles on Looker Dashboard 19 — tiles #7–#10 measuring song download rates and session frequency in the 0–7 day, 0–30 day, and 30–60 day windows since subscription start. All rows represent logged-in, subscribed users; anonymous/unsubscribed sessions are excluded by the join design (sessions are joined to subscriptions via `fct_sessions.CURRENT_SUBSCRIPTION_ID`).

No dbt description block was found in schema.yml (no schema.yml exists in `marts/core/`). Description derived from model SQL and LookML view.

## Lineage

- **dbt model:** `context/dbt/models/marts/core/fct_subscriber_activity_mixpanel.sql`
- **Upstream sources:**
  - `source("soundstripe", "subscriptions")` — raw Stitch source; subscription-to-account/user mapping
  - `ref("subscription_periods")` — Chargebee-derived subscription lifecycle rows with `start_date` / `end_date`
  - `ref("fct_sessions")` — session grain; joined on `fct_sessions.CURRENT_SUBSCRIPTION_ID = subscription.SOUNDSTRIPE_SUBSCRIPTION_ID`
  - `ref("fct_sessions_product_engagement")` — per-session aggregated engagement counts (downloads, plays, favorites, projects); materialized as `table`
  - `ref("distinct_song_plays")` — distinct song IDs played per session, bridged via `ref("dim_session_mapping")`
  - `ref("stg_contacts_2")` — HubSpot contact lookup for company linkage
  - `ref("hubspot_companies")` — company name
  - `ref("dim_enterprise_deals")` — deal IDs and owner IDs for enterprise accounts
  - `ref("hubspot_contacts_internal")` — deal owner emails
  - `ref("fct_customers")` — company-name fallback for deal linkage
- **dbt tags:** none declared
- **Materialization:** `table` — no `{{ config(...) }}` block present in model file; defaults to `table`. No incremental logic.
- **Incremental watermark behavior:** N/A — full rebuild on every dbt run. No late-arrival protection; any session row created or updated after a run completes will not appear until the next full rebuild.

## Columns (primary + frequently used)

| Column | Type | Source | Description | Known nulls / gotchas |
|---|---|---|---|---|
| `soundstripe_subscription_id` | NUMBER | `subscription_periods.soundstripe_subscription_id` | Internal Soundstripe subscription ID; de-facto composite PK element (with `session_id`) | All rows have a subscription. NULL sessions (no Mixpanel session match) produce one row per subscription with NULL session columns |
| `session_id` | TEXT | `fct_sessions.session_id` | Mixpanel session identifier; second PK element | NULL where subscription has no matching session in `fct_sessions`. NVL'd engagement counts will be 0 for these rows |
| `start_date` | TIMESTAMP_NTZ | `subscription_periods.created_at` cast via `subscription_periods` model | Subscription start timestamp (Chargebee `created_at`, not `date_from`). Used to compute days-since-subscription for all engagement-window metrics | Time zone is NTZ; Chargebee timestamps are UTC |
| `end_date` | TIMESTAMP_NTZ | `COALESCE(cancelled_at, current_term_end)` in `subscription_periods` | Subscription end timestamp. **Active subscriptions have `end_date` = `current_term_end` (next billing date), not NULL or open-ended.** This means `DATEDIFF('days', start_date, end_date)` is bounded for all rows including actives | Active sub `end_date` will advance each billing cycle; point-in-time snapshots of this column are not stable across rebuilds |
| `session_started_at` | TIMESTAMP_NTZ | `fct_sessions.session_started_at` | Session start timestamp; used for `DATEDIFF('days', start_date, session_started_at)` to place a session in an engagement window | NULL for subscription-only rows with no matched session |
| `downloaded_songs` | NUMBER | `fct_sessions_product_engagement.downloaded_songs` (SUM of event-level rows, NVL'd 0) | Count of song downloads in the session, not a flag. Aggregated from event-level rows in `fct_sessions_product_engagement` before joining here | 0 (not NULL) when no downloads; NVL applied in model |
| `downloaded_sfxs` | NUMBER | `fct_sessions_product_engagement.downloaded_sfxs` | Count of SFX downloads in the session | 0 when none |
| `downloaded_videos` | NUMBER | `fct_sessions_product_engagement.downloaded_videos` | Count of video downloads in the session | 0 when none |
| `distinct_song_plays` | NUMBER | `distinct_song_plays` ref via `dim_session_mapping` bridge | Count of distinct song IDs played in the session | 0 when none; uses `dim_session_mapping` bridge because `fct_events.session_id` and `fct_sessions.session_id` do not join directly |
| `plan_type` | TEXT | `subscription_periods.plan_type` | Subscription plan tier (personal, pro, pro-plus, enterprise, etc.) | NULL if plan type not set on Chargebee record |
| `billing_period_unit` | TEXT | `subscription_periods.billing_period_unit` | `month`, `year`, or `quarter` | NULL uncommon but possible for legacy records |
| `aise_engagment_flag` | BOOLEAN | `fct_sessions_product_engagement` | AI-assisted search engagement indicator for the session | Note the typo in column name: `AISE_ENGAGMENT_FLAG` (missing 'E' in ENGAGEMENT). This is the production column name |
| `adobe_engagement_flag` | BOOLEAN | `fct_sessions_product_engagement` | Adobe integration engagement indicator for the session | |

Full schema: run `information_schema.columns` query or see 31-column list confirmed 2026-04-28.

Columns not present that might be expected:
- No `distinct_id` (Mixpanel anonymous ID) — this table joins through `fct_sessions.CURRENT_SUBSCRIPTION_ID`, not through Mixpanel identity. Anonymous sessions are excluded by the JOIN design.
- No `page_category` — engagement is at session grain, not event grain. `page_category` issues (classifier broken post-2026-03-17) do not affect this table's download/play counts directly, but do affect the upstream `fct_sessions` attribution and any event-level breakdowns.
- `created_playlist_*` / `playlist_added_*` columns present in `fct_sessions_product_engagement` are **not carried into this table** — the `SELECT *` at the end of the model's `with_activity` CTE only brings through what was explicitly selected earlier. Those columns are in the intermediate, not the mart.

## Canonical joins

| To table | On | Cardinality | Notes |
|---|---|---|---|
| `core.fct_sessions` | `fct_sessions.CURRENT_SUBSCRIPTION_ID = fct_subscriber_activity_mixpanel.soundstripe_subscription_id` AND `fct_sessions.session_id = fct_subscriber_activity_mixpanel.session_id` | 1:1 (session grain already embedded) | Sessions already denormalized in; re-joining would fan out. Use this table directly for subscriber-session analytics |
| `core.dim_session_mapping` | Not needed from this table; already resolved in upstream `distinct_song_plays` CTE | N/A | Session ID mapping handled upstream |
| Raw `soundstripe.subscriptions` | `subscription.id = soundstripe_subscription_id` | N:1 | Subscription metadata already embedded; re-joining rarely needed |

## Grain & identity

- **Grain:** one row per (subscription × session). A subscription with 50 sessions has 50 rows. A subscription with zero matching sessions in `fct_sessions` has 1 row with NULL `session_id` and all engagement counts = 0.
- **Primary key:** (`soundstripe_subscription_id`, `session_id`) — not formally declared in dbt. NULL `session_id` rows are edge-case duplicates: if a subscription has no sessions, it produces exactly one NULL-session row.
- **Distinct-user column:** `soundstripe_subscription_id` for subscriber-level deduplication; `account_id` for account-level; `user_id` (TEXT, Chargebee UID) for user-level. `chargebee_subscription_id` is the Chargebee-side subscription key.

## Typical usage patterns

- **Date scoping:** Scope by `session_started_at` for time-series of engagement activity. Scope by `start_date` for subscription-cohort analyses (e.g., "subscribers who started in month M"). Not date-scoped by a watermark column — scan the full table when computing all-cohort metrics.
- **Engagement window filters:** Dashboard tiles apply `DATEDIFF('days', start_date, session_started_at) < N` to restrict sessions to the first N days of subscription. The `is_sub_30_to_60` dimension additionally requires `DATEDIFF('days', start_date, end_date) >= 60` to guard against right-censored subscriptions — subscriptions shorter than 60 days are excluded from the 30–60 day denominator.
- **Parameterized metric pattern:** `days_since_sub` Looker parameter (default: 7) drives `has_downloaded_songs_w_param` dimension, which in turn drives the rate measures in the "Parameterized Metric" group label. Dashboard tiles #7 and #8 use this parameter at N=7 and N=30 respectively.
- **Common filters:** `plan_type IN (...)` for plan-mix breakdowns; `billing_period_unit = 'year'` for annual vs monthly cohort comparisons; `start_date >= <cohort_start>` for recent-subscriber analyses.
- **Canonical queries:** None yet in `knowledge/query-patterns/` as of 2026-04-28 calibration.

## Known pitfalls

1. **Right-censoring on the most-recent cohort months (critical for this analysis).** The `is_sub_30_to_60` dimension uses `DATEDIFF('days', start_date, end_date) >= 60` as a right-censoring guard, but this only excludes subscriptions shorter than 60 days total — it does not exclude subscriptions that are still active but have not yet reached day 60 as of the query run date. A subscriber who started 2026-04-01 has `end_date` = current billing term end (2026-05-01 for monthly), so `end_date - start_date` = 30 days, and they ARE excluded from the 30–60 day denominator. However, the 0–30 day `Parameterized Metric` group uses `DATEDIFF('days', start_date, session_started_at) < 30` against `session_started_at` — there is no guard that the subscription has reached day 30. Any subscription that started in the last 30 days contributes sessions to the numerator but the denominator (`COUNT DISTINCT soundstripe_subscription_id`) includes ALL subscriptions, even those with partial observation windows. For a trailing-24-month monthly series, the most-recent 1–2 cohort-months (March–April 2026) will have **systematically lower download rates** for the 0–30 day and 30–60 day windows simply because those cohorts have not had time to complete the window. This is an observational artifact, not a behavioral change.

2. **`end_date` is not open-ended for active subscriptions.** Active subscriptions have `end_date` = `current_term_end` (the next scheduled billing or renewal date). This means `end_date` is typically 1 billing period (~30 days for monthly) in the future. Downstream metrics that rely on `end_date` as a termination signal (e.g., `is_sub_30_to_60` requiring `end_date - start_date >= 60`) will exclude all monthly subscribers who are currently in their first billing period, regardless of whether they will cancel. For annual subscribers, `end_date - start_date ≈ 365 days`, so they are rarely excluded by this guard. The plan/billing-period mix of the subscriber base directly affects which subscribers pass the 30–60 day guard.

3. **No incremental protection — full rebuild on every run.** This table has no `{{ config(materialized='incremental') }}` block. Every dbt run rebuilds the entire table from scratch. If `fct_sessions`, `fct_sessions_product_engagement`, or `subscription_periods` are themselves incremental and their watermarks are ahead of session creation (the late-arrival issue documented for statsig/fct_events), session rows that arrive late will be missing from this table until the next full rebuild. Additionally, because `subscription_periods.end_date = COALESCE(cancelled_at, current_term_end)`, a cancelled subscription's `end_date` changes on cancellation — meaning historical rows in this table change meaning when the table is rebuilt after a cancellation. This is a snapshot-at-rebuild table, not an immutable event table.

4. **Playlist columns from `fct_sessions_product_engagement` are dropped.** The `with_activity` CTE selects `c.DOWNLOADED_SONGS, c.DOWNLOADED_SFXS, c.DOWNLOADED_VIDEOS, c.FAVORITED_*, c.CREATED_PROJECTS, c.PROJECT_ADDED_*, c.AISE_ENGAGMENT_FLAG, c.ADOBE_ENGAGEMENT_FLAG` explicitly. The playlist columns (`created_playlist_*`, `playlist_added_*`, `played_songs`, `played_sfxs`, `licensed_songs`, `licensed_sfxs`) present in `fct_sessions_product_engagement` are **not selected** and are not in this table. If playlist or licensing engagement is needed, query `fct_sessions_product_engagement` directly.

5. **`AISE_ENGAGMENT_FLAG` column name typo.** The production column is spelled `AISE_ENGAGMENT_FLAG` (missing 'E' in ENGAGEMENT). LookML and any SQL querying this column must use the exact misspelled name.

6. **Mixpanel autocapture collapse (OPEN, 2026-02-25 onward).** The upstream `pc_stitch_db.mixpanel.export` table lost scroll percentage and click-position properties from 2026-02-25 forward on pricing URLs. This does not directly affect download/play counts in this table, but it means any engagement analysis that tries to correlate `fct_subscriber_activity_mixpanel` download behavior with scroll/click-position data from the same period is not possible from warehouse data. See `project_mixpanel_autocapture_collapse_open` memory entry.

## Cost profile (from query_history)

4 matching queries found in session history (insufficient for robust P50/P95; treat as indicative).

- **Elapsed range:** 610–1,188 ms
- **P50 elapsed (indicative):** ~903 ms
- **P95 elapsed (indicative):** ~1,188 ms
- **Bytes scanned (typical):** 528–1,472 bytes for targeted aggregates; 171,696 bytes for broader scans
- **Note:** At 11.1M rows / 538 MB, well-scoped aggregate queries run fast. The table is fully columnar; filtering on `start_date` or `session_started_at` with Snowflake clustering benefits from micro-partition pruning if present. No `LIMIT` needed for aggregate queries. Avoid `SELECT *` or row-returning queries without a `LIMIT 100` guard on this table.

## Prior analyses referencing this table

- [analysis/adhoc/2026-04-28-product-kpis/](../../../analysis/adhoc/2026-04-28-product-kpis/) — Product KPIs 24-month trend review; tiles #7–#10 use this table for subscriber engagement download rates (0–7d, 0–30d, 30–60d windows). First known analysis touching this table in the task workspace.

## LookML semantics

View: `fct_subscriber_activity_mixpanel` (`context/lookml/views/Mixpanel/fct_subscriber_activity_mixpanel.view.lkml`). Used in Dashboard 19 tiles #7–#10.

**Key measures:**

| Measure | Group | Business purpose |
|---|---|---|
| `song_downloading_subscriber_rate_param` | Parameterized Metric | % of subscribers (in cohort window) who downloaded at least one song within first N days. Denominator = `COUNT DISTINCT soundstripe_subscription_id`; numerator = distinct subs with `downloaded_songs > 0` AND `days_since_sub < param`. Dashboard tile #7 uses param=7, tile #8 uses param=30. |
| `engaged_subscriber_rate_30_to_60` | 30-60 Metric | % of 60-day-eligible subscribers (those whose subscription span ≥60 days) who had any session in days 30–59. Denominator = `subs_60_plus` (subs with `end_date - start_date >= 60`). Dashboard tile #9. |
| `sessions_per_engaged_subscriber_30_to_60` | 30-60 Metric | Sessions / engaged subscriber in the 30–60 day window. Numerator = `sessions` (filtered to `is_sub_30_to_60 = true`); denominator = `engaged_subscribers_30_to_60`. Dashboard tile #10. |
| `subscribers` | (base) | `COUNT DISTINCT soundstripe_subscription_id` — total distinct subscriptions in the filtered population. Used as denominator in all parameterized rate measures. |
| `songs_downloaded_by_subscriber_30_to_60` | 30-60 Metric | Total downloads / eligible subscriber in days 30–60. Diagnostic companion to the rate measures. |

**Key dimensions:**

| Dimension | Business purpose |
|---|---|
| `is_sub_30_to_60` | Boolean flag: session is in days 30–59 of subscription AND subscription lifespan ≥ 60 days. Central to tiles #9 and #10. Contains the right-censoring guard (`end_date - start_date >= 60`) but does NOT guard against current subs that haven't yet reached day 60 as of query run date |
| `has_downloaded_songs_w_param` | Boolean flag: session is within first N days AND has `downloaded_songs > 0`. Uses `days_since_sub` parameter |
| `dynamic_session_date` | Parameterized truncation of `session_started_at` (day/week/month/quarter/year); used for time-series tiles |
| `dynamic_sub_start_date` | Parameterized truncation of `start_date`; used to cohort subscribers by subscription start period |
| `session_overlaps_sub` | Used with `session_range` filter to find subscriptions active during a date window (subscription span overlaps the filter range) |

## Known pitfalls

### Tile-title vs. measure-denominator mismatch — `songs_downloaded_by_subscriber_param` (Dashboard 19, tile "Song Downloads per Downloading Subscriber: 0 - 30 Days")

The Looker tile titled "Song Downloads per Downloading Subscriber: 0 - 30 Days" uses the measure `songs_downloaded_by_subscriber_param`:

```lookml
measure: songs_downloaded_by_subscriber_param {
  sql: div0(${songs_downloaded_param}, ${subscribers}) ;;
}
```

The denominator `subscribers` is `COUNT DISTINCT soundstripe_subscription_id` — i.e., **all subscribers in the cohort**, downloaders or not. The title says "per Downloading Subscriber," which would imply the denominator should be the count of subs who actually downloaded.

The view *does* contain a measure that matches the title:

```lookml
measure: songs_downloading_subscribers_param {
  sql: count(distinct case when ${has_downloaded_songs_w_param} = true then ${soundstripe_subscription_id} end) ;;
}
```

Pairing the existing numerator (`songs_downloaded_param`) with `songs_downloading_subscribers_param` would yield "songs per subscriber who actually downloaded." The current pairing yields "downloads spread across the whole cohort, including non-downloaders."

**Resolution path (open):** either rename the tile to "Song Downloads per Subscriber: 0 - 30 Days" or swap the denominator. Documented in `analysis/adhoc/2026-04-28-product-kpis/findings.md` §6 (Dashboard hygiene). User decides which way to resolve.

**Surfaced:** 2026-04-30 during the Product KPIs corrections session. Verified against `context/lookml/views/Mixpanel/fct_subscriber_activity_mixpanel.view.lkml` lines 178–280.
