---
table: soundstripe_prod.core.dim_daily_kpis
last_calibrated: 2026-04-24
schema_hash: b4a51e8906382c617e78536f355b62b4de606100269ff0c822696e5fd9e9a97d
dbt_model: marts/core/dim_daily_kpis.sql
row_count: 3752
bytes_gib: 0.000436
col_count: 81
---

# core.dim_daily_kpis — Calibration

## Purpose (business meaning)

One row per calendar day. The canonical pre-aggregated daily KPI table covering all primary business metrics: subscriber counts and MRR/ARR, website traffic (visitors, sessions) by attribution channel, ad spend by channel, enterprise pipeline, single-song and marketplace revenue, and YoY lag columns for the same metrics. Serves as the authoritative answer for "what happened on date X" at the day grain across the entire funnel — from ad impression through subscription. Used in weekly reporting, XmR control charts, and as the Identity Check anchor for fct_sessions-derived metrics.

No description present in dbt `schema.yml` (no `.yml` file found in `context/dbt/models/marts/core/`). Description above derived from model SQL structure and LookML view usage.

## Lineage

- **dbt model:** `context/dbt/models/marts/core/dim_daily_kpis.sql`
- **Upstream sources (via `ref()`):**
  - `ref('subscription_periods')` — spine: active subscriber periods define the date range
  - `ref('all_days')` — date scaffold; INNER JOIN against subscription_periods creates one row per active-subscriber-day, then groups to calendar day
  - `ref('fct_ad_performance')` — LEFT JOIN: ad spend/impressions/clicks by channel and marketing_test_ind
  - `ref('fct_sessions')` — LEFT JOINs twice: once for subscription attribution (channel-split), once for visitor/session/enterprise_form counts
  - `ref('dim_enterprise_deals')` — LEFT JOIN: enterprise MRR from won deals, spread daily via all_days
  - `ref('dim_deals')` — LEFT JOIN: enterprise bookings (new, renewal, sublicensing, custom sync) by close_date
  - `ref('dim_transaction_line_items')` — LEFT JOIN: single-song, SFX, market revenue by event_ts date
- **dbt tags:** none confirmed (no schema.yml in model directory)
- **Materialization:** table (no incremental config block in model SQL; full rebuild on each run)
- **Incremental watermark behavior:** N/A — full table rebuild. No late-arrival risk from this model's own logic. Late-arrival risk exists in upstream sources (fct_sessions, fct_ad_performance).

## Columns (primary + frequently used)

Table has 81 columns. Listing PK + top frequently used. Full schema: `SELECT column_name, data_type FROM soundstripe_prod.information_schema.columns WHERE table_schema = 'CORE' AND table_name = 'DIM_DAILY_KPIS' ORDER BY ordinal_position`.

| Column | Type | Source | Description | Known nulls / gotchas |
|---|---|---|---|---|
| `date` | DATE | `subscription_periods` + `all_days` | Calendar date. **Primary key** | Never NULL; spine is subscription_periods × all_days (non-enterprise, non-straynote plans). Earliest date = first active subscription start |
| `visitors` | NUMBER | `fct_sessions.distinct_id` | Count of distinct visitors (distinct_id) across all sessions for the day | NULL for days with no sessions in fct_sessions. Includes `marketing_test_ind = 0` and `1`. See `core_visitors` for test-excluded count |
| `sessions` | NUMBER | `fct_sessions.session_id` | Count of distinct sessions for the day | Same caveats as visitors. Direct from `sessions` CTE |
| `core_visitors` | NUMBER | `fct_sessions.distinct_id WHERE marketing_test_ind = 0` | Visitors excluding marketing-test traffic | Preferred for conversion-rate denominators in production reporting |
| `enterprise_form_submissions` | NUMBER | `fct_sessions` enterprise form flags | Count of sessions with any enterprise landing/schedule-demo form submission | Counts sessions, not individual form submissions. Affected by MQL undercount (see pitfalls) |
| `direct_subscriptions` | NUMBER | `fct_sessions.last_channel_non_direct = 'Direct'` | Subscriptions attributed to Direct channel via non-direct-last-touch logic | Attribution field is `last_channel_non_direct`, NOT `last_channel`. See pitfall #1 |
| `paid_search_subscriptions` | NUMBER | `fct_sessions.last_channel_non_direct = 'Paid Search'` | Subscriptions attributed to Paid Search | Same attribution rule as direct_subscriptions |
| `organic_search_subscriptions` | NUMBER | `fct_sessions.last_channel_non_direct = 'Organic Search'` | Subscriptions attributed to Organic Search | Same attribution rule |
| `mrr` | NUMBER | `subscription_periods.monthly_amount` summed | MRR from self-service subscriptions (enterprise excluded) | Excludes `plan_type IN ('straynote-billing','enterprise')`. Enterprise has separate `enterprise_mrr` column |
| `enterprise_mrr` | FLOAT | `dim_enterprise_deals` + hardcoded patch | MRR from won enterprise deals spread across active days | **Has hardcoded +$9,500/month patch for Getty deal effective 2024-02-01** (line 186). Any YoY or period comparison crossing 2024-02-01 will step on this boundary |
| `ly_visitors` | NUMBER | `LAG(visitors, 365) OVER (ORDER BY date)` | Visitors exactly 365 calendar days prior | NULL for the first 365 rows of the series. NOT a trailing-period average — single-day 365-day lag |
| `ly_mrr` | NUMBER | `LAG(mrr, 365) OVER (ORDER BY date)` | MRR exactly 365 calendar days prior | Same NULL behavior. 365-day lag is **calendar days**, not business days or same-weekday. Week-of-year shifts create noise |
| `net_chg_mrr` | NUMBER | `mrr - LAG(mrr, 1) OVER (ORDER BY date)` | Day-over-day MRR change | Day-over-day, not month-over-month. Very noisy at daily grain |
| `spend` | FLOAT | `fct_ad_performance` (all channels) | Total ad spend across all channels and marketing_test_ind | NULL if no fct_ad_performance rows for the day (LEFT JOIN) |
| `single_song_rev` | FLOAT | `dim_transaction_line_items WHERE item_type = 'song license'` | Single-song license revenue for the day | NULL if no transactions. Joined by `event_ts::date` on the transaction table |

### YoY lag column semantics

All `ly_*` columns use `LAG(metric, 365) OVER (ORDER BY date)`. This is a strict 365-day calendar offset: day N looks back to day N-365. It is NOT a same-weekday-prior-year or rolling-365-average approach. Implications:
- NULL for the first 365 rows of the time series
- Leap-year years shift day-of-week alignment between current and prior year by 1–2 days
- Week-of-year "comparison" via these columns requires awareness that Jan 1 in one year may be a different day-of-week than Jan 1 in the prior year

### Subscription-count columns

`new_subscribers`, `reactivated_subscribers`, `churned_subscribers`, and `net_chg_active_subscribers` are computed inside the `subscriptions` CTE using window functions (`new_subscribers + reactivated_subscribers + churned_subscribers as net_chg_active_subscribers`). This means `net_chg_active_subscribers` references CTE-local aliases, not final column names — it is computed before the outer SELECT adds `net_chg_mrr`. The CTE also uses `ORDER BY 1` inside the subscription CTE (Snowflake allows this in CTEs; it does not affect the final row order of the table).

## Canonical joins

This table is typically used standalone at the day grain. Joining it back to fct_sessions or fct_events is unusual (it was built to avoid that). When a cross-table check is needed:

| To table | On | Cardinality | Notes |
|---|---|---|---|
| `core.fct_sessions` | `dim_daily_kpis.date = fct_sessions.session_started_at::date` | 1:N (daily vs. session-grain) | Use for Identity Checks only — verify that `SUM(fct_sessions.created_subscription GROUP BY date) = dim_daily_kpis.mixpanel_subscriptions`. Attribution columns split differently; see pitfall #1 |
| `core.fct_ad_performance` | `dim_daily_kpis.date = fct_ad_performance.date` | 1:N | Source for spend/impressions/clicks columns; LEFT JOIN in model |
| `core.dim_transaction_line_items` | `dim_daily_kpis.date = dim_transaction_line_items.event_ts::date` | 1:N | Source for single_song_rev, sfx_rev, market_rev |

## Grain & identity

- **Grain:** one row per calendar day
- **Primary key:** `date` — confirmed unique by construction (subscription_periods × all_days spine with GROUP BY date, then all other CTEs joined on date)
- **Spine source:** `subscription_periods` INNER JOIN `all_days`. The table's earliest row corresponds to the earliest active subscription start date in `subscription_periods` for non-enterprise, non-straynote plans. Days with no active subscribers do NOT appear — the spine is subscriber-driven, not a pure calendar scaffold
- **Distinct-user column:** N/A — pre-aggregated; `visitors` is a count of `distinct_id`, not a list

## Typical usage patterns

- **Date scoping:** full table is 3,752 rows (~10+ years of daily history). No date-scope predicate is required for cost reasons — scanning the full table is negligible (458 KB). Scoping by date is still recommended for analytical clarity
- **Common filters:** `date >= DATEADD('day', -90, CURRENT_DATE)` for rolling window reports; `date BETWEEN '2025-01-01' AND CURRENT_DATE` for YTD
- **Common aggregations:** `DATE_TRUNC('week', date)` to roll up to weekly grain; `SUM(visitors)` / `SUM(core_visitors)` / `SUM(direct_subscriptions)` across a window
- **Identity Check pattern:** `SELECT date, visitors, sessions, core_visitors FROM dim_daily_kpis WHERE date BETWEEN X AND Y` vs. corresponding `fct_sessions` aggregation — use this to validate that a new fct_sessions query produces matching totals before branching into segmentation
- **Canonical queries:** check `knowledge/query-patterns/_index.md` — XmR baseline queries at `analysis/data-health/2026-04-03-xmr-scratch-work/` pull from this table for visitors, mrr, subscribers, and spend metrics

## Known pitfalls

1. **Channel attribution uses `last_channel_non_direct`, not `last_channel` (CRITICAL for Identity Checks).** The `attribution` CTE groups `fct_sessions.last_channel_non_direct` — this is Soundstripe's non-direct-last-touch channel model. If you query `fct_sessions.last_channel` or `fct_sessions.channel` directly to reproduce `direct_subscriptions`, you will get a different number. Any Identity Check that compares `dim_daily_kpis.direct_subscriptions` against `fct_sessions` must use `last_channel_non_direct`, not `channel` or `last_channel`. The exact filter: `WHERE last_channel_non_direct = 'Direct' AND marketing_test_ind = 0`.

2. **Direct traffic contamination window 2026-03-05 through 2026-03-25.** Domain consolidation (www + app → soundstripe.com via Fastly) triggered ~200K artifact sessions during this window via pre-render cache clears and Google sitemap recrawl. `visitors`, `sessions`, `direct_subscriptions`, and `core_visitors` are inflated for this period; conversion rates (subscriptions/visitors) are correspondingly depressed. The table contains these artifacts as-is — there is no flag column. Any analysis using a window that crosses 2026-03-05 to 2026-03-25 must exclude or annotate this range. See memory `project_domain_consolidation.md`.

3. **`enterprise_mrr` has a hardcoded +$9,500/month patch effective 2024-02-01 (Getty deal).** Line 186 of the dbt model: `enterprise_mrr + case when a.date >= '2024-02-01' then 9500 else 0 end as enterprise_mrr`. This is a patched constant, not a subscription-period entry. Any YoY comparison where one window falls before 2024-02-01 and the other after will include a $9,500/month step in the delta. The patch is invisible unless you read the model source.

4. **Spine is subscriber-driven, not a pure calendar scaffold.** The table uses `subscription_periods INNER JOIN all_days` as its spine. Days with zero active subscribers will not appear. In practice, there are always active subscribers, so this is unlikely to cause gaps in the observable history — but it means the table's earliest row is driven by the earliest subscription start date, not an arbitrary date anchor. Do not assume the table starts at a specific calendar date without checking `MIN(date)`.

5. **YoY lag columns are 365-day calendar offsets, not same-weekday prior year.** See column notes above. Comparing `visitors` vs. `ly_visitors` across a leap year or a week boundary creates apparent week-day misalignment. For stakeholder YoY comparisons, aggregate to weekly or monthly grain before applying the `ly_*` column, or use `WHERE date = some_date AND ly_date = some_date` cross-joins rather than the lag column directly.

6. **`enterprise_form_submissions` counts sessions with any enterprise form flag, not individual form submissions.** A single session with multiple form submissions counts as 1. This aligns with "enterprise lead entered the funnel" semantics, but differs from a raw form-event count. The MQL discrepancy investigation (see `analysis/data-health/2026-04-07-mql-discrepancy/`) found that some enterprise form paths (`/brand-solutions/`, `/agency-solutions/`) were being under-counted upstream; the column may still undercount if those paths were not yet fully patched in `fct_sessions`. See memory `project_mql_discrepancy.md`.

## Cost profile (from query_history; 10 recent queries against this table)

- **P50 elapsed:** ~1,080 ms
- **P95 elapsed:** ~6,000 ms (range observed: 582 ms – 9,099 ms; high end reflects multi-join queries that scan upstream fact tables through this table's CTEs — applies to analytical queries that re-join against fct_sessions or fct_ad_performance, not to queries against the pre-built table itself)
- **Bytes scanned (P50):** ~0.17 MB (pre-aggregated table is 458 KB; most queries scan it nearly in full)
- **Bytes scanned (P95):** ~1.4 GB (outliers reflect queries that joined through to upstream fact tables)
- **Cost posture:** negligible for direct queries against this table. Expensive only if used as a driver to re-join back into fct_sessions or fct_events (which defeats the purpose of the pre-aggregation)
- **No date-scope requirement** — 458 KB total; scanning the whole table costs less than $0.001

## Prior analyses referencing this table

- `/Users/dev/PycharmProjects/d7dev/analysis/data-health/2026-04-03-xmr-scratch-work/` — XmR control chart baseline work; queries for visitors, mrr, spend, subscribers, conversions all sourced from dim_daily_kpis
- `/Users/dev/PycharmProjects/d7dev/analysis/data-health/2026-04-07-mql-discrepancy/` — MQL discrepancy investigation; enterprise_form_submissions from this table was the observed signal; root cause traced to fct_sessions upstream
- `/Users/dev/PycharmProjects/d7dev/analysis/data-health/2026-04-24-session-retrospective.md` — named this table as one of 4 pending calibration artifacts; confirmed as target for upcoming domain consolidation impact analysis
- Direct traffic spike investigations (`analysis/data-health/2026-04-01-*/`, `analysis/data-health/2026-04-17-*/`) — use this table's `visitors` and `direct_subscriptions` as the observable signal

## LookML semantics

Three views wrap this table:

**`context/lookml/views/General/dim_daily_kpis.view.lkml`** — the canonical Looker view. All 81 columns exposed as dimensions (no measures beyond a raw `count`). Key dimensions used in dashboards and scheduled reports:
- `date` dimension_group (raw, date, week, month, quarter, year; `convert_tz: no`)
- `ly_date` dimension_group — companion to `date` for YoY tiles
- `visitors`, `core_visitors`, `sessions` — traffic volume
- `direct_subscriptions`, `paid_search_subscriptions`, `organic_search_subscriptions` — channel-split acquisition
- `mrr`, `arr`, `enterprise_mrr` — revenue state
- `spend`, `core_spend`, `paid_search_spend` — media investment
- All columns are exposed as dimensions, not measures. Downstream Looker measures (SUM, AVG) are defined in derived views or in the explore itself

**`context/lookml/views/_Custom_Views/dim_daily_kpis_with_forecast.view.lkml`** — derived table (`SELECT * FROM dim_daily_kpis`) with a `date_trunc` parameter (day/week/month/quarter/year) and all metrics redefined as `type: sum` measures. Used for dashboards requiring dynamic date truncation. Key measures: `active_subscribers`, `mrr`, `arr`, `new_subscribers`, `visitors`, `sessions`, `direct_subscriptions`, `paid_search_subscriptions`, `spend`.

**`context/lookml/views/_Custom_Views/daily_slack_report.view.lkml`** — does not directly query `dim_daily_kpis`; builds a one-row daily snapshot from `subscription_periods` and other upstream tables directly. References `${dim_daily_kpis.SQL_TABLE_NAME}` indirectly via derived table inheritance.
