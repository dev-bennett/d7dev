---
table: _external_statsig.statsig_clickstream_events_etl_output
last_calibrated: 2026-04-27
schema_hash: 94edc2176ec7c0ead2caccaac36f1bd69d7f279698507f7b32fe231f5ff82068
dbt_model: marts/_external_statsig/statsig_clickstream_events_etl_output.sql
row_count: 213738784
bytes_gib: 17.43
col_count: 64
---

# _external_statsig.statsig_clickstream_events_etl_output — Calibration

## Purpose (business meaning)

The Statsig outcome-metrics table. It is the row-level event stream that Statsig Pulse reads to compute experiment metrics — subscriptions, sign-ups, purchases, engagement events, and derived revenue values — for every exposed user in every experiment. Built incrementally from `core.fct_events`, it pre-computes 30+ binary and numeric outcome columns so that Pulse can aggregate them without joining back to the full warehouse event table. It is also the primary table queried in SQL-side Statsig experiment audits (e.g., the WCPM pricing test audit). At 213M rows and 17.4 GiB it is a BLOCK-tier table; every query against it requires a date-scoped predicate.

## Lineage

- **dbt model:** `context/dbt/models/marts/_external_statsig/statsig_clickstream_events_etl_output.sql`
- **Upstream sources:**
  - `ref("fct_events")` — primary source; one row per deduplicated Mixpanel event
  - `ref("subscription_periods")` — joined twice: once on `created subscription` events (for LTV lookup chain), once on `Purchased Add-on` events (for add-on invoice join)
  - `ref("subscription_ltv_assumptions")` — LTV coefficients keyed on plan_type × billing_interval
  - `ref("dim_session_mapping")` — bridge table; resolves `distinct_id` and `session_id` from the events side to the sessions-side identity
  - `source("mixpanel", "export")` — `pc_stitch_db.mixpanel.export`; joined on `__sdc_primary_key` to retrieve `current_addons` for add-on purchase rows
  - `finance.dim_invoice_line_items` — inline CTE `wcpm_daily_invoice`; resolves WCPM add-on MRR amount keyed on `subscription_id` × `invoice_date`
- **dbt tags:** none declared in model config
- **Materialization:** `incremental`, `on_schema_change='sync_all_columns'`, `unique_key='__sdc_primary_key'`
- **Incremental watermark behavior:** CRITICAL — see Known Pitfalls §1. The predicate filters `fct_events` (the source) by `event_ts::date >= max(event_ts)::date from this`. Any fct_events row whose `event_ts` is older than the model's current watermark is permanently excluded from subsequent runs.

## Columns (PK + top 15 most used)

Full schema: 64 columns. Run `SELECT column_name, data_type FROM soundstripe_prod.information_schema.columns WHERE table_schema = '_EXTERNAL_STATSIG' AND table_name = 'STATSIG_CLICKSTREAM_EVENTS_ETL_OUTPUT' ORDER BY ordinal_position` or see `information_schema.columns`.

| Column | Type | Source | Description | Known nulls / gotchas |
|---|---|---|---|---|
| `__sdc_primary_key` | TEXT | `fct_events.__sdc_primary_key` | Unique event key (Stitch-generated). Unique key for the incremental model | All nullable per schema; in practice always populated for valid events |
| `event_ts` | TIMESTAMP_NTZ | `fct_events.event_ts` + 1 min offset | Event timestamp. **Shifted forward 1 minute** by the model (`dateadd('minutes', 1, a.event_ts)`) to handle cases where Statsig fires an exposure event after the Mixpanel event | The 1-minute shift means `event_ts` in this table is NOT identical to `fct_events.event_ts`; do not use for exact-match joins back to fct_events on timestamp |
| `distinct_id` | TEXT | `COALESCE(dim_session_mapping.distinct_id, fct_events.distinct_id)` | Mixpanel user identifier, with sessions-side identity preferred via `dim_session_mapping` | NULL for anonymous pre-identity events |
| `statsig_stable_id` | TEXT | `fct_events.statsig_stable_id` | Statsig's stable device/browser identifier. Primary identity column for Statsig Pulse joins | Post-consolidation sprawl (March 2026+): a single user_id can have multiple stable_ids; Statsig Pulse's 1:1 enforcement drops ~13.5% of exposed logged-in users in affected experiments — see Known Pitfalls §2 |
| `session_id` | TEXT | `COALESCE(dim_session_mapping.session_id, fct_events.session_id)` | Session identifier, sessions-side preferred | Used by LookML `sessions` and `subscribes` measures (count_distinct on session_id) |
| `event` | TEXT | `fct_events.event` | Raw Mixpanel event name (e.g., `'created subscription'`, `'Purchased Add-on'`) | Outcome columns below are derived from this; query the outcome columns rather than filtering on `event` where possible |
| `page_category` | TEXT | `fct_events.page_category` | Classifier applied in `stg_events.sql` | **Near-zero for pricing/checkout/signup/sign_in from 2026-03-17** due to domain consolidation moving paths under `/library/`. OPEN issue: `project_page_category_classifier_broken_open.md` |
| `channel` | TEXT | `fct_events.channel` | Last-touch attribution channel | Inherits fct_events limitations; raw `channel` gives cleaner SEO reads vs `last_channel_non_direct` in fct_sessions |
| `current_subscription_id` | TEXT | `fct_events.current_subscription_id` | Subscription ID at event time | Used in `created_subscription` and add-on purchase joins; NULL for non-subscriber events |
| `current_account_id` | TEXT | `fct_events.current_account_id` | Account ID at event time | NULL for anonymous events |
| `signed_up` | NUMBER | derived | 1 when `event = 'signed up'`, else 0 | Always 0 or 1 (never NULL) per CASE WHEN … ELSE 0 pattern |
| `created_subscription` | NUMBER | derived | 1 when `event = 'created subscription'`, else 0 | Always 0 or 1 |
| `add_on_purchase_total` | NUMBER | derived | 1 when `event = 'Purchased Add-on'`, else NULL | NULL (not 0) when event is not add-on — use `NVL(add_on_purchase_total, 0)` in aggregations |
| `pricing_page_cta_value` | NUMBER | hardcoded lookup | Expected click value for pricing-page CTA events, by plan. Coefficients from Notion analysis (2026-04 pricing-page expected click value). Default 0 for non-matching events | Hardcoded coefficients — stale if conversion rates change. Values as of model creation: Creator Monthly $35.25, Creator Yearly $22.06, Pro Monthly $64.20, Pro Yearly $37.37 |
| `ltv_1_yr_gm` / `ltv_3_yr_gm` / `ltv_5_yr_gm` | NUMBER | `subscription_ltv_assumptions` | Gross-margin LTV coefficients populated only for `created subscription` rows with a matched plan_type × billing_interval | NULL on all non-`created_subscription` rows; also NULL when plan_type or billing_interval doesn't match `subscription_ltv_assumptions` keys |

**Dropped from upstream `fct_events`:** `user_agent`, `ip`, `mp_lib`, `screen_*`, `initial_referrer`, `insert_id`. If you need these columns, query `core.fct_events` or `pc_stitch_db.mixpanel.export` directly.

**Added vs. `fct_events`:** 30+ pre-computed binary/numeric outcome columns (enterprise form flags, sign-up, subscription, purchase, engagement, LTV, add-on metrics), `pricing_page_cta_value` (hardcoded), add-on MRR from the `wcpm_daily_invoice` CTE.

## Canonical joins

| To table | On | Cardinality | Notes |
|---|---|---|---|
| `_external_statsig.exposures` | `exposures.stable_id = statsig_clickstream.statsig_stable_id` AND `exposures.user_id` agreement | N:M | **Primary Statsig Pulse pattern.** Join to a first-exposure CTE (`ROW_NUMBER() OVER (PARTITION BY user_id, experiment_id ORDER BY timestamp) = 1`) to get one exposure per user. Then inner join to the clickstream on `statsig_stable_id` and `event_ts > first_exposure_ts`. Do not join on stable_id alone — post-consolidation sprawl makes it N:M |
| `_external_statsig.first_exposures_<experiment>` | `first_exposures.user_id = exposures.user_id` (via distinct_id mapping) | M:1 | Statsig-generated first-exposure table per experiment. Canonically what Pulse uses. Missing rows here (never-exposed pattern) are an expected outcome for users who purchase without hitting the exposure trigger |
| `core.dim_session_mapping` | (already applied inside the model via the `dim_session_mapping` LEFT JOIN) | — | Already resolved in the model — do not re-join `dim_session_mapping` when querying this table; `distinct_id` and `session_id` are already coalesced to sessions-side identity |
| `core.fct_events` | `statsig_clickstream.__sdc_primary_key = fct_events.__sdc_primary_key` | 1:1 (subset) | Use for retrieving columns dropped from this model (user_agent, ip, etc.). **Important:** this table is a strict subset of fct_events — rows dropped by the incremental predicate are absent here but present in fct_events |

## Grain & identity

- **Grain:** one row per deduplicated Mixpanel event (`__sdc_primary_key`), inherited directly from `fct_events`
- **Primary key:** `__sdc_primary_key` (Stitch-assigned UUID)
- **Distinct-user column for Statsig Pulse:** `statsig_stable_id` — this is what Statsig's SDK stamps on events and what Pulse uses to link exposures to outcomes. `distinct_id` is the Mixpanel identity; use it for Mixpanel-side comparisons
- **History window:** model populated from `event_ts::date >= '2024-12-01'` (hard-coded floor in the WHERE clause). Events before 2024-12-01 are not in this table

## Typical usage patterns

- **Date scoping:** always required. Typical experiment windows are 30–90 days. Rows/day ≈ 700K (213M rows ÷ ~305 days from 2024-12-01 to 2026-04-27). Scanning a 30-day experiment window touches ~21M rows
- **Standard experiment attribution pattern:**
  ```sql
  -- 1. Build first-exposure cohort from exposures table
  WITH first_exp AS (
      SELECT user_id, stable_id, group_name, MIN(timestamp) AS first_exposure_ts
      FROM _external_statsig.exposures
      WHERE experiment_id = '<experiment_slug>'
        AND user_id IS NOT NULL
        AND timestamp BETWEEN '<start>' AND '<end>'
      GROUP BY user_id, stable_id, group_name
  )
  -- 2. Join to clickstream for outcome metrics
  SELECT
      fe.group_name
      ,SUM(e.created_subscription)        AS subscriptions
      ,SUM(e.signed_up)                   AS sign_ups
      ,SUM(e.enterprise_form_submissions) AS mqls
      ,COUNT(DISTINCT e.session_id)       AS sessions
  FROM first_exp fe
  INNER JOIN _external_statsig.statsig_clickstream_events_etl_output e
      ON e.statsig_stable_id = fe.stable_id
      AND e.event_ts > fe.first_exposure_ts
      AND e.event_ts::date BETWEEN '<start>' AND '<end>'
  GROUP BY fe.group_name
  ```
- **Common filters:** `event_ts::date BETWEEN '<start>' AND '<end>'`, `statsig_stable_id = '<id>'`, `event = '<event_name>'`
- **Canonical query patterns:** none yet promoted to `knowledge/query-patterns/`; the pattern above is from `analysis/experimentation/2026-04-18-wcpm-test-audit/console.sql` (q12–q14)

## Known pitfalls

### 1. Incremental predicate permanently drops late-arriving rows (OPEN — STRUCTURAL)

Source: `project_statsig_model_late_arrival_open.md`, confirmed 2026-04-18 in `analysis/experimentation/2026-04-18-wcpm-test-audit/findings.md` Finding 4.

The model's incremental predicate filters the SOURCE (`fct_events`) before writing:

```sql
{% if is_incremental() %}
    and event_ts::date >= (select coalesce(max(event_ts), '1900-01-01')::date from {{ this }} )
{% endif %}
```

Any `fct_events` row whose `event_ts` is older than the model's current `max(event_ts)` watermark is permanently excluded on every subsequent incremental run. This is not a lag window — there is no lookback. Once the watermark advances past a date, that date is closed.

**Concrete evidence:** One `Purchased Add-on` event (PK `a7a9fe2a-2c96-4101-a041-bd6d40fdc329`, `event_ts` 2026-03-22 19:53:39) is present in `fct_events` but absent from this table. The raw Mixpanel event fired on 03-22; it arrived in Stitch on 03-23 ~15:19 UTC, after the model's watermark had advanced past 03-22. The row is orphaned — 3,051 other events for the same user exist in this table, but not this one.

**Proposed fix (not yet implemented):** Widen the lookback window by N days to tolerate typical Stitch replication lag:

```sql
{% if is_incremental() %}
    and event_ts::date >= dateadd(day, -N, (select coalesce(max(event_ts), '1900-01-01')::date from {{ this }} ))
{% endif %}
```

N should cover typical Stitch replication lag (estimated 3–7 days). The fix requires a `--full-refresh` or a scoped backfill to recover already-orphaned rows. Until fixed, treat any small discrepancy between Mixpanel event counts and this table's event counts as potentially caused by this pattern.

### 2. Statsig 1:1 mapping exclusion from Pulse (OPEN — STRUCTURAL)

Source: `project_wcpm_1to1_mapping_exclusion.md`, confirmed 2026-04-20.

Statsig Pulse enforces a 1:1 mapping between `user_id` and `stable_id`. Post-consolidation (domain consolidation March 2026, www+app → soundstripe.com via Fastly) stable_id sprawl means a single `user_id` can accumulate multiple `stable_id` values. Statsig Pulse drops such users from experiment results entirely. In `wcpm_pricing_test`, approximately 13.5% of the 20,072 exposed logged-in `user_ids` carry multi-arm exposures and are excluded from Pulse.

This issue affects the EXPOSURES table and Statsig's own Pulse output — not this clickstream table directly. However, when replicating Pulse metrics by joining exposures → this table, the same 1:1 enforcement must be applied manually to match Pulse's counts. Failing to apply it produces metrics that are ~13.5% higher than Pulse reports.

**Mitigation:** Use `_external_statsig.first_exposures_<experiment>` as the exposure source (Statsig has already applied 1:1 enforcement there), not raw `_external_statsig.exposures`. See `_external_statsig__exposures.md` Known Pitfalls §1 for the cross-reference.

### 3. event_ts is shifted +1 minute vs. fct_events

The SELECT applies `dateadd('minutes', 1, a.event_ts) as event_ts`. The model comment explains this handles cases where Statsig fires an exposure event after the Mixpanel event. Consequence: timestamp-based exact joins back to `fct_events` on `event_ts` will not match. Join on `__sdc_primary_key` instead.

### 4. page_category near-zero post-domain-consolidation

Source: `project_page_category_classifier_broken_open.md`.

`stg_events.sql` uses an exact-match classifier that breaks for pricing/checkout/signup/sign_in pages from 2026-03-17 onward, because the domain consolidation moved those paths under `/library/`. `page_category` values for these high-value pages are near-zero from 2026-03-17 forward. Do not use `page_category` as a filter for pricing or checkout funnel analyses on data after that date without confirming the values are populated.

### 5. Hardcoded pricing_page_cta_value coefficients

The `pricing_page_cta_value` column uses hardcoded expected-value coefficients from a 2026-04 analysis. These will go stale if conversion rates change. Verify against the source analysis before citing this column as a current expected-value figure.

### 6. No data before 2024-12-01

The WHERE clause has a hard floor: `event_ts::date >= '2024-12-01'`. Queries spanning earlier dates will return zero rows for that period with no warning. There is also a commented-out `event_ts::date >= '2026-03-01'` line used in dev builds — do not uncomment in production queries.

## Cost profile (from query_history)

Query history has 3 matching rows (borderline for P50/P95 reliability; treat as directional):

- **P50 elapsed:** 776ms
- **P95 elapsed:** 1,080ms
- **Bytes scanned (typical):** ~2,416 bytes (calibration queries were `information_schema` lookups, not table scans)

For actual table scans (experiment attribution joins):

- **30-day date-scoped aggregate on a single experiment:** estimate ~1–5 GB bytes scanned, 5–30 seconds elapsed on DATA_SCIENCE X-Small
- **Full-table scan:** ~17.4 GiB — avoid. A full-table scan on DATA_SCIENCE X-Small will approach or exceed the 2-minute ceiling
- **Avoid:** unbounded queries (no `event_ts` predicate), `SELECT *` row-returning queries, joining to `fct_events` (1.29B rows) without tight mutual date scoping on both sides

## Prior analyses referencing this table

- [`analysis/experimentation/2026-04-18-wcpm-test-audit/`](/Users/dev/PycharmProjects/d7dev/analysis/experimentation/2026-04-18-wcpm-test-audit/) — primary reference; 23-query audit reconciling Mixpanel vs. Statsig add-on purchase counts for `wcpm_pricing_test`; source of Findings 4 (late-arrival drop) and 6 (1:1 mapping exclusion)
- [`analysis/data-health/2026-04-18-wcpm-audit-session-retrospective.md`](/Users/dev/PycharmProjects/d7dev/analysis/data-health/2026-04-18-wcpm-audit-session-retrospective.md) — session retrospective from the WCPM audit; captures patterns and lessons applied to this calibration

## LookML semantics

View: `statsig_clickstream_events_etl_output` at `context/lookml/views/Statsig/statsig_clickstream_events_etl_output.view.lkml`

**Key measures (business purpose):**

| Measure | Type | Business purpose |
|---|---|---|
| `unique_visitors` | count_distinct on `statsig_stable_id` | Exposed unique visitors for experiment-level conversion rate denominators |
| `sessions` | count_distinct on `session_id` | Session count; denominator for `session_conv_rate` |
| `subscribes` | count_distinct sessions where `created_subscription > 0` | New subscriptions as a Pulse outcome metric |
| `sign_ups` | count_distinct sessions where `signed_up > 0` | New sign-ups as a Pulse outcome metric |
| `MQLs` | count_distinct sessions where enterprise form flags > 0 | Qualified enterprise leads; combines `enterprise_form_submissions`, `enterprise_landing_form_submissions`, `enterprise_schedule_demo` |
| `session_conv_rate` | `(MQLs + subscribes + transactions) / sessions` | Composite session-level conversion rate; denominator is sessions (not visitors) |
| `1yr_ltv_assumed` | SUM of `ltv_1_yr_gm` | Projected 1-year gross-margin LTV summed across `created_subscription` rows with matched plan assumptions |
| `total_revenue` | MQL_value_assumed + license revenue + 1yr_ltv_assumed | Composite estimated revenue; MQL component uses hardcoded $0.05 × $6,000 assumption — verify before citing |

**Key dimensions for experiment slicing:** `statsig_stable_id`, `event_ts_date`, `event`, `channel`, `device`, `country`, `page_category`
