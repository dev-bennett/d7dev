---
table: core.fct_kpis_enterprise
last_calibrated: 2026-05-04
schema_hash: 9261b1882c3b3f299b15f29133556c94895a61ecd74bfed8e9f7cb3da6f5f608
dbt_model: marts/core/fct_kpis_enterprise.sql
row_count: 36
bytes_gib: 0.000034
col_count: 50
---

# core.fct_kpis_enterprise — Calibration

## Purpose (business meaning)

Monthly-grain aggregate fact table for Enterprise sales KPIs. One row per calendar month
(from 2024-01-01 through the current year) regardless of whether any activity occurred in that
month. Covers the full Enterprise funnel: leads by type (MQL, PQL, DTC, other), deal creation,
demo-stage entries, active pipeline snapshot, and closed-won results for new deals plus
renewal outcomes. The row spine is generated synthetically via `SEQ4()`, so months with zero
activity appear with all-zero metrics rather than being absent. No dbt schema.yml description
found; purpose derived from model SQL and LookML explore label "KPI Reporting for Enterprise
(Monthly)".

This table is **not event-grain**. Do not apply `LIMIT`, date-range bounds, or per-row filters
the way you would with `fct_events` or `fct_sessions`. The full 36-row result set is the
intended output for time-series analysis.

## Lineage

- **dbt model:** `context/dbt/models/marts/core/fct_kpis_enterprise.sql`
- **Upstream refs:**
  - `{{ ref("dim_enterprise_leads") }}` — lead-level grain; source of all lead counts and lead-attributed deal metrics
  - `{{ ref("dim_enterprise_deals") }}` — deal-level grain; pre-filtered to `PIPELINE_NAME IN ('Enterprise Pipeline', 'Renewal Pipeline')` inside this model
  - `{{ ref("hubspot_deals_exploded_for_trend") }}` — stage-by-day exploded deal history; used for pipeline snapshot and demo-stage entry detection
  - `{{ ref("hubspot_deal_pipeline_stages") }}` — stage transition events; used for renewal won/lost counts
  - `soundstripe_dev.hubspot.hubspot_pipeline_history` — **hardcoded raw source** (not via `source()`) used for demo-stage entry detection; violates dbt convention and may drift if schema changes
- **dbt tags:** none found in schema.yml
- **Materialization:** no `{{ config(...) }}` block in the model file; defaults to `view` per dbt project config. Confirm in dbt Cloud if a project-level override applies to marts/core

## Columns (primary + frequently used)

| Column | Type | Source | Description | Known nulls / gotchas |
|---|---|---|---|---|
| `event_month` | DATE | `DATE_TRUNC('month', ...)` on spine | PK; first day of calendar month; generated for all months 2024-01 through current year | Never null; synthetic spine means all months present |
| `mqls` | NUMBER | `dim_enterprise_leads.lead_grouping = 'mql'` | Count of distinct MQL leads with lead start in that month | NVL(0) applied; null-safe |
| `pqls` | NUMBER | `dim_enterprise_leads.lead_grouping = 'pql'` | Count of distinct PQL leads | NVL(0) applied |
| `dtc_leads` | NUMBER | `dim_enterprise_leads.lead_grouping = 'dtc'` | Count of distinct DTC leads | NVL(0) applied |
| `total_leads` | NUMBER | all lead_grouping values | Sum of all lead types | NVL(0) applied |
| `won_deal_amount` | FLOAT | `SUM(dim_enterprise_deals.amount)` | Total ARR for closed-won new deals; see filter chain in pitfalls | NVL(0) applied; FLOAT precision |
| `closed_won_deals` | NUMBER | `COUNT(1)` | Count of closed-won new deals | NVL(0) applied |
| `avg_days_to_close` | NUMBER | `AVG(DATEDIFF('days', CREATEDATE, CLOSEDATE))` | Average cycle time for closed-won new deals in month | 0 when no deals (NVL applied); not weighted by deal size |
| `pipeline_deals` | NUMBER | stage_number BETWEEN 2 AND 5 | Deals active in pipeline stages 2–5 as of that month | Snapshot logic via QUALIFY; stage 1 (initial) excluded |
| `pipeline_amount` | FLOAT | SUM(amount) for stage 2–5 deals | Total ARR value of active pipeline | NVL(0) applied |
| `renewal_deals_won` | NUMBER | `hubspot_deal_pipeline_stages` stage ILIKE '%won%' | Count of renewal deals reaching won stage | Renewal Pipeline only; distinct from new-deal closed won |
| `renewal_deals_won_amount` | FLOAT | SUM(amount) for renewal won | ARR value of won renewals | NVL(0) applied |
| `demo_stage` | NUMBER | `hubspot_pipeline_history` stage_number = 2 | Deals entering demo stage (stage 2) for first time | Enterprise Pipeline only; Renewal Pipeline excluded from demo count |

Full schema: 50 columns. Per-lead-type breakdowns exist for every headline metric (pql\_, mql\_, dtc\_, other\_ prefix variants). See `information_schema.columns` for the complete list.

## Canonical joins

| To table | On | Cardinality | Notes |
|---|---|---|---|
| `dim_monthly_forecast` | `event_month = dim_monthly_forecast.event_month AND forecast_name = '2026 Budget'` | 1:1 | Looker explore join; left outer; forecast rows may not cover all historical months |

No other joins documented in LookML explores or prior analyses. This table is typically queried
standalone — the monthly grain is self-contained.

## Grain & identity

- **Grain:** one row per calendar month; synthetic spine from 2024-01-01 through current year
- **Primary key:** `event_month` (DATE, first of month)
- **No user-level identifier.** This is a pre-aggregated mart; individual leads and deals are
  resolved upstream in `dim_enterprise_leads` and `dim_enterprise_deals`.
- **Row count:** 36 rows as of 2026-05-04 (covers 2024-01 through 2026-12 approximate)

## Typical usage patterns

- **Date scoping:** not required and not recommended. The table is 36 rows total. Pull all rows
  and filter in the query layer or Looker explore. Cost is negligible (36 KB bytes scanned typical).
- **Common filters:** none at the table level; Looker `dim_monthly_forecast` join filters to
  `forecast_name = '2026 Budget'` automatically in the explore.
- **Lead-type breakdown:** all per-type columns (pql\_, mql\_, dtc\_, other\_) are pre-computed
  columns. Do not attempt to re-aggregate from this table using filters — the breakdowns are
  baked in at model build time.
- **Dynamic measures in LookML:** the `dynamic_*` measures in the view accept a `lead_type`
  parameter from `dim_monthly_forecast` to switch between per-type and total values at query
  time.

## Known pitfalls

1. **`won_deal_amount` triple filter chain.** The column is computed in the `closed_deals` CTE
   with three sequential filters applied before aggregation:
   - `PIPELINE_NAME IN ('Enterprise Pipeline', 'Renewal Pipeline')` — applied in the `deals` CTE
     (model-level, upstream of all CTEs)
   - `DEAL_GROUPING ILIKE '%new deal'` — applied in `closed_deals` CTE
   - `STAGE_CATEGORY = 'won'` — applied in `closed_deals` CTE
   Bucketed by `DATE_TRUNC('month', CLOSEDATE)`. **Reconciling this against an external sales
   tracker or finance report requires applying all three filters in the same order.** Omitting
   any one of them (especially the `%new deal` grouping filter) will produce a different total.
   Renewal-pipeline deals are included in the upstream `deals` CTE but then excluded by
   `%new deal` — so `won_deal_amount` contains only new-deal closed-won, not renewals. Renewal
   ARR is captured separately in `renewal_deals_won_amount`.

2. **`closed_won_deals` uses `COUNT(1)`, not `COUNT(DISTINCT deal_id)`.** If the upstream
   `dim_enterprise_deals` table contains duplicate deal rows, `closed_won_deals` will
   overcount. Cross-check against Hubspot directly when deal counts look high.

3. **Demo-stage count excludes Renewal Pipeline.** The `demo_entry_by_deal` CTE explicitly
   filters `a.pipeline_name = 'Enterprise Pipeline'`, so `demo_stage` and all `*_demos` columns
   only reflect Enterprise Pipeline deals. Renewal Pipeline deals that reach stage 2 are not
   counted here.

4. **Hardcoded `soundstripe_dev` reference.** The `demo_entry_by_deal` CTE uses
   `soundstripe_dev.hubspot.hubspot_pipeline_history` directly (not via `ref()` or `source()`).
   This is a raw Stitch table in the dev database, meaning: (a) if run against the prod target
   this CTE reads from the dev Stitch replica, and (b) any schema change to that raw table
   will break the model silently at compile time.

5. **Synthetic month spine starts 2024-01-01.** Months before 2024-01 are not present in the
   output. If any upstream data has a `CLOSEDATE` or `lead_start_ts` before 2024-01-01, those
   rows contribute to upstream dims but are dropped from this fact table.

6. **`avg_days_to_close` NVL to 0.** Months with no closed deals return 0, not NULL.
   Averaging `avg_days_to_close` across months with a simple `AVG()` will be biased downward
   by zero-deal months. Weight by `closed_won_deals` or filter to months where
   `closed_won_deals > 0`.

## Cost profile (from query_history)

3 historical executions found (at threshold for cost stats):

- **P50 elapsed:** ~1,068 ms
- **P95 elapsed:** ~1,956 ms
- **Bytes scanned (typical):** 1.6 KB (entire table is ~36 KB; scans are negligible)
- **Avoid:** no pathological query shapes known; table is tiny. Full scans are effectively free.

## Prior analyses referencing this table

- [analysis/enterprise/tasks/2026-05-04-enterprise-sourav-question/](../../../analysis/enterprise/tasks/2026-05-04-enterprise-sourav-question/) — enterprise KPI question; first documented use of this table

## LookML semantics

View: `fct_kpis_enterprise` (`context/lookml/views/Finance/fct_kpis_enterprise.view.lkml`)
Explore: `fct_kpis_enterprise` in `General.model.lkml`, label "KPI Reporting for Enterprise (Monthly)", group "KPI Dashboards". Joined to `dim_monthly_forecast` (left outer, 1:1 on event_month + forecast_name = '2026 Budget').

Key measures and their SQL mapping to underlying columns:

| LookML measure | Group label | Maps to column | Format |
|---|---|---|---|
| `closed_won_arr` | Won Deal Amount | `won_deal_amount` | \$#,##0 |
| `closed_won_deals` | (ungrouped) | `closed_won_deals` | #,##0 |
| `closed_won_avg_arr` | Closed Won Avg ARR | `DIV0(won_deal_amount, closed_won_deals)` | \$#,##0 |
| `mqls` | Leads | `mqls` | #,##0 |
| `pqls` | Leads | `pqls` | #,##0 |
| `total_leads` | Leads | `total_leads` | #,##0 |
| `deals_created` | Deals Created | `deals_created` | #,##0 |
| `lead_to_deal_create` | Lead to Deal Create Rate | `DIV0(deals_created, total_leads)` | 0.00% |
| `demo_stage` | Demos | `demo_stage` | #,##0 |
| `demo_per_lead` | Demo per Lead | `DIV0(demo_stage, total_leads)` | 0.00% |
| `pipeline_deals` | (ungrouped) | `pipeline_deals` | #,##0 |
| `pipeline_amount` | (ungrouped) | `pipeline_amount` | \$#,##0 |
| `renewal_deals_won` | Renewals | `renewal_deals_won` | #,##0 |
| `renewal_deals_won_amount` | Renewals | `renewal_deals_won_amount` | \$#,##0 |
| `renewal_deals_lost` | Renewals | `renewal_deals_lost` | #,##0 |

All measures have per-lead-type variants (pql\_, mql\_, dtc\_, other\_ prefix) and a `dynamic_*`
variant that switches based on the `dim_monthly_forecast.lead_type` parameter. The `abm` lead
type has no column in the table and returns `SUM(0)` for all dynamic measures — it is a
placeholder only.
