---
table: finance.dim_enterprise_deals
last_calibrated: 2026-05-04
schema_hash: 24e933a1014bb4c214bfe387eb4aa73e45214d4214b718c8f501164c8e355993
dbt_model: marts/finance/dim_enterprise_deals.sql
row_count: 6706
bytes_gib: unknown (information_schema.tables returned null; table exists and is queryable)
col_count: 47
---

# finance.dim_enterprise_deals — Calibration

## Purpose (business meaning)

Deal-level mart for all enterprise and sublicensing pipeline activity. Each row is one deal stage-snapshot from HubSpot, scoped to four `deal_grouping` values: `enterprise new deal`, `enterprise renewal`, `sublicensing new deal`, `sublicensing renewal`. The model corrects HubSpot's raw subscription end-date using `recurring_revenue_inactive_ts`, upgrade/expansion logic, and lead-order window functions to produce `sub_end_date` (the authoritative contract end date) and `mrr` (annualized `amount / 12`). This table is the primary input to `fct_kpis_enterprise` and drives the `won_deal_amount` metric on the Enterprise KPIs dashboard.

## Lineage

- **dbt model:** `context/dbt/models/marts/finance/dim_enterprise_deals.sql`
- **Upstream dbt refs:**
  - `ref("dim_deals")` — parent mart at `marts/finance/dim_deals.sql`; itself refs `ref("stg_deals")` (HubSpot CRM raw) and `ref("stg_pipelines")` (pipeline/stage metadata)
- **dbt tags:** none declared in model file
- **Materialization:** not specified in model file (inherits project default — assumed `table`; verify in `dbt_project.yml`)
- **Scope filter:** model filters `dim_deals` to `deal_grouping IN ('enterprise new deal','enterprise renewal','sublicensing new deal','sublicensing renewal')`. Deals outside these four values do not appear in this table

## Columns (primary + most-used)

| Column | Type | Source | Description | Known nulls / gotchas |
|---|---|---|---|---|
| `dealid` | NUMBER | `stg_deals` | Primary key. HubSpot deal ID | NOT NULL; only FK in LookML view |
| `companyid` | NUMBER | `stg_deals` | HubSpot company ID — joins to company-level tables | Nullable |
| `dealname` | TEXT | `stg_deals` | Free-text deal name entered in HubSpot | Often includes company name; no separate company-name column in this table — see Joins for company lookup |
| `amount` | FLOAT | `stg_deals` | Total contract value (ACV) in USD | Nullable; used as `won_deal_amount` in `fct_kpis_enterprise` |
| `closedate` | TIMESTAMP_NTZ | `stg_deals` | HubSpot close date; used as the period-bucket anchor in `fct_kpis_enterprise` | Nullable; scope to `DATE_TRUNC('month', closedate)` for monthly KPI matching |
| `pipeline_name` | TEXT | `stg_pipelines` | Human-readable pipeline label | See domain enumeration below; 1 NULL row; 1 ARCHIVE row |
| `deal_grouping` | TEXT | `dim_deals` (computed) | Derived classification: see domain enumeration | NOT NULL; 4 values only |
| `stage_category` | TEXT | `stg_pipelines` | Abstracted stage bucket | See domain enumeration below; 1 NULL row |
| `stage_name` | TEXT | `stg_pipelines` | Raw HubSpot stage name | More granular than `stage_category` |
| `sub_start_date` | TIMESTAMP_NTZ | `stg_deals` | Contract start (original HubSpot value; preserved as `hubspot_sub_start_date`) | Nullable |
| `sub_end_date` | TIMESTAMP_NTZ | model logic | **Corrected** contract end date — model overrides HubSpot's raw value using `recurring_revenue_inactive_ts` and lead-order window | This is NOT the raw HubSpot value; use `hubspot_sub_end_date` if you need the original |
| `mrr` | FLOAT | computed | `amount / 12` | Only populated for won deals that went through `revised_sub_end_date` CTE; NULL for non-won rows |
| `primary_deal_line` | BOOLEAN | model logic | TRUE = the highest-`amount` deal per `(companyid, sub_start_date)` for won deals; de-duplication flag | NULL for non-won rows; filter `primary_deal_line = TRUE` when computing active contract MRR to avoid double-counting |
| `merged_deal_flag` | BOOLEAN | `dim_deals` | TRUE if this deal was merged into another in HubSpot | `current_deal_id` holds the surviving deal's ID |

Full schema: 47 columns. Run `SELECT column_name, data_type FROM soundstripe_prod.information_schema.columns WHERE table_schema='FINANCE' AND table_name='DIM_ENTERPRISE_DEALS' ORDER BY ordinal_position` for the complete list.

## Domain enumerations (verified 2026-05-04)

### `pipeline_name` (5 distinct values)

| pipeline_name | n |
|---|---|
| Enterprise Pipeline | 4,477 |
| Renewal Pipeline | 1,528 |
| API & Partnerships | 699 |
| ARCHIVE: Partnership/Custom Opportunity | 1 |
| NULL | 1 |

`fct_kpis_enterprise` filters to `pipeline_name IN ('Enterprise Pipeline', 'Renewal Pipeline')` — excludes API & Partnerships and the two edge rows.

### `deal_grouping` (4 distinct values — NOT NULL)

| deal_grouping | n |
|---|---|
| enterprise new deal | 4,475 |
| enterprise renewal | 1,306 |
| sublicensing new deal | 703 |
| sublicensing renewal | 222 |

`won_deal_amount` in `fct_kpis_enterprise` uses `deal_grouping ILIKE '%new deal'` — matches `enterprise new deal` and `sublicensing new deal`. Renewals are reported separately via the `renewals` CTE.

### `stage_category` (4 distinct values)

| stage_category | n |
|---|---|
| lost | 4,188 |
| won | 1,721 |
| in progress | 796 |
| NULL | 1 |

`won_deal_amount` requires `stage_category = 'won'` (exact match, case-sensitive). Renewals use a separate `hubspot_deal_pipeline_stages` ref — they do NOT flow through `stage_category = 'won'` in the same CTE.

## Canonical joins

| To table | On | Cardinality | Notes |
|---|---|---|---|
| `core.dim_enterprise_leads` | `dim_enterprise_deals.dealid = dim_enterprise_leads.deal_id` | N:1 (leads → deals) | Used in `fct_kpis_enterprise` to attribute deals back to lead source. Not all deals have a matching lead |
| HubSpot companies (raw or dbt staging) | `dim_enterprise_deals.companyid = <companies>.companyid` | N:1 | `dealname` frequently embeds company name but is freetext; for structured company lookup join to `stg_companies` or Stitch raw `pc_stitch_db.hubspot.companies`. No pre-built join in this mart |
| `core.hubspot_deals_exploded_for_trend` | `dim_enterprise_deals.dealid = hubspot_deals_exploded_for_trend.deal_id` | 1:N (one deal → many stage-month rows) | Used in `fct_kpis_enterprise` for pipeline stage history |
| `core.hubspot_deal_pipeline_stages` | `dim_enterprise_deals.dealid = hubspot_deal_pipeline_stages.deal_id` | 1:N | Used in `fct_kpis_enterprise` renewals CTE only |

## Grain & identity

- **Grain:** one row per HubSpot deal (all stages, all pipeline outcomes). The model does NOT explode by stage — each deal appears once at its current/final state
- **Primary key:** `dealid`
- **Dedup note:** multiple deals can share `(companyid, sub_start_date)` for won rows. Use `primary_deal_line = TRUE` to deduplicate to one contract line per company-period when computing MRR or active contract counts

## `won_deal_amount` filter chain (critical for reconciliation)

`fct_kpis_enterprise.won_deal_amount` aggregates `SUM(amount)` from this table with exactly three predicates applied at the `deals` CTE level:

1. `pipeline_name IN ('Enterprise Pipeline', 'Renewal Pipeline')`
2. `deal_grouping ILIKE '%new deal'` — matches `enterprise new deal` and `sublicensing new deal`; excludes renewals
3. `stage_category = 'won'`

Bucketed by `DATE_TRUNC('month', closedate)`.

A deal in the external tracker will appear in `won_deal_amount` if and only if it satisfies all three predicates AND its `closedate` falls within the target month. Deals in `API & Partnerships` pipeline are excluded by predicate 1. Renewal deals are excluded by predicate 2.

## Typical usage patterns

- **Common filter for closed-won new deals:** `pipeline_name IN ('Enterprise Pipeline', 'Renewal Pipeline') AND deal_grouping ILIKE '%new deal' AND stage_category = 'won'`
- **Close-date scoping:** always scope via `DATE_TRUNC('month', closedate)` to match `fct_kpis_enterprise` buckets. `closedate` is TIMESTAMP_NTZ — cast or truncate before comparing to date literals
- **Company name lookup:** `dealname` is freetext and frequently contains the company name, but use `companyid` for structured joins
- **Contract MRR:** filter `primary_deal_line = TRUE` before summing `mrr` to avoid double-counting on companies with multiple deal lines in the same start-date window
- **Canonical queries:** none yet in `knowledge/query-patterns/`; first-use queries live in `analysis/enterprise/tasks/2026-05-04-enterprise-sourav-question/console.sql`

## Known pitfalls

1. **`sub_end_date` is NOT the raw HubSpot value.** The model applies multi-step correction logic (upgrade/expansion detection, `recurring_revenue_inactive_ts`, lead-order window). Use `hubspot_sub_end_date` for the original. The corrected `sub_end_date` is what drives contract period calculations in the MRR stack.

2. **`primary_deal_line` is NULL for non-won deals.** The dedup flag is only set in the `won_enterprise_initial_dupes` CTE (filtered to `stage_category = 'won'`). Filtering `primary_deal_line = TRUE` on a population that includes non-won deals silently drops them. Confirm your population before applying this filter.

3. **`mrr` is NULL for non-won deals.** Computed as `amount / 12` in the final SELECT via a LEFT JOIN to `revised_sub_end_date`, which itself filters to `stage_category = 'won'`. Non-won rows LEFT JOIN to NULL and get NULL mrr.

4. **`deal_grouping ILIKE '%new deal'` includes sublicensing.** The `fct_kpis_enterprise` `won_deal_amount` CTE matches both `enterprise new deal` and `sublicensing new deal`. If the reconciliation target is enterprise-only, add `pipeline_name = 'Enterprise Pipeline'` explicitly.

5. **1 NULL `pipeline_name` row and 1 NULL `stage_category` row exist.** These are edge-case HubSpot data quality issues. Exact-match filters will silently exclude them. Use `IS NULL` checks if completeness matters.

6. **No direct company-name column.** `dealname` is freetext; company lookup requires joining to HubSpot companies via `companyid`. There is no pre-built company-name column in this mart.

7. **`closedate` is TIMESTAMP_NTZ, not DATE.** Comparisons to date literals without truncation or casting will behave unexpectedly in Snowflake equality checks.

## Cost profile (from query_history — 9 sessions in RESULT_LIMIT=100)

- **P50 elapsed:** ~1,919 ms
- **P95 elapsed:** ~2,825 ms
- **Bytes scanned (typical full-table):** ~246 MB (257–267 MB for full scans; near-zero for metadata-only queries)
- **Row count:** 6,706 — no date-scope required; full-table scans are cheap. LIMIT not required for aggregate queries

## Prior analyses referencing this table

- [analysis/enterprise/tasks/2026-05-04-enterprise-sourav-question/](../../../analysis/enterprise/tasks/2026-05-04-enterprise-sourav-question/) — April 2026 closed-won reconciliation between Looker `won_deal_amount` and Sourav's internal sales tracker

## LookML semantics

- **View:** `dim_enterprise_deals` (`context/lookml/views/Enterprise_and_Custom_Sync/dim_enterprise_deals.view.lkml`), `sql_table_name: "FINANCE"."DIM_ENTERPRISE_DEALS"`
- **Primary key:** `dealid`
- **Key measures:**
  - `value_deals_closed_won` — `SUM(amount WHERE stage_category='won')` — total bookings for won deals
  - `new_enterprise_deals_closed_won_value` — `SUM(DISTINCT amount WHERE stage_category='won' AND deal_grouping='enterprise new deal')` — note `SUM(DISTINCT ...)` anti-pattern; may miscount on duplicate amounts
  - `total_mrr` — `SUM(mrr)` — sum of `amount/12` across all rows (not filtered to won; apply stage filter in explore)
  - `total_bookings` — `SUM(amount)` — unfiltered; use with `stage_category` dimension filter
  - `deals_closed_won` / `deals_closed_lost` / `deals_in_progress` — `COUNT(DISTINCT dealid WHERE stage_category=...)` per status
- **Explores:** `dim_enterprise_deals` explore defined in `General.model.lkml`; also joined as a secondary view in the `dim_enterprise_leads` explore (`sql_on: dim_enterprise_leads.deal_id = dim_enterprise_deals.dealid`) and in a `partnerships_budgets_2026` explore (filtered to `pipeline_name = 'API & Partnerships'`)
- **Drill fields:** `dealid`, `dealname`, `amount`, `closedate_date`
