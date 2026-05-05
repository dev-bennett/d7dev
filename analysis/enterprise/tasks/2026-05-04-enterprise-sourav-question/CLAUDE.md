# 2026-05-04 — Enterprise Sourav Question

@../../CLAUDE.md

## Scope

Reconcile the April 2026 enterprise closed-won total between two sources:

- **Looker tile / `console.sql`** — sources `core.fct_kpis_enterprise.won_deal_amount`, `event_month = 2026-04-01`
- **`tracker.csv`** — internal sales tracker provided by Sourav (17 rows, mix of `New` / `Upsell - DTC`, `Enterprise Plan` / `Sublicensing`)

Goal: identify, per tracker row, whether and how it lands in `won_deal_amount`, and what filter / value mismatch produces the headline gap.

## Conventions for this directory

- Tracker rows are exogenous data. Label any tracker-derived total as `analyst-derived from tracker.csv` per `feedback_chart_series_must_be_apples_to_apples`. The dashboard's view is `won_deal_amount`; the tracker is a separate source, not a dashboard series.
- `console.sql` holds labeled q-blocks. q01 = original Looker SQL the user pasted; q02+ are reconciliation queries.
- `reconciliation.csv` = per-tracker-row warehouse match + classification.
- `findings.md` = stakeholder-facing answer. Sourav reads it. Apply §10 writing scrub + verbatim pass + workflow-seat scan before delivery.

## Source tables

Calibration artifacts at `knowledge/data-dictionary/calibration/`:

- `core.fct_kpis_enterprise` (calibrated 2026-05-04) — monthly aggregate fact, 36 rows. The Looker tile / `console.sql` reads `won_deal_amount` from here.
- `finance.dim_enterprise_deals` (calibrated 2026-05-04) — deal-level mart, 6,706 rows. **Schema is `FINANCE`, not `CORE`** — the dbt `ref()` resolves to `soundstripe_prod.finance.dim_enterprise_deals`. All q03+ deal-level pulls hit this table.
- `finance.dim_monthly_forecast` — small dim, used for forecast comparison in the Looker tile; not relevant to the reconciliation.

## Domain enumerations (live, 2026-05-04)

- `pipeline_name`: Enterprise Pipeline (4,477), Renewal Pipeline (1,528), API & Partnerships (699), ARCHIVE (1), NULL (1)
- `deal_grouping`: enterprise new deal (4,475), enterprise renewal (1,306), sublicensing new deal (703), sublicensing renewal (222)
- `stage_category`: lost (4,188), won (1,721), in progress (796), NULL (1)

Sublicensing rows (Queensberry, Wevi.ai in tracker) likely live in `API & Partnerships` pipeline → excluded from `won_deal_amount` by filter (1).

## Filter logic for `won_deal_amount` (read from `context/dbt/models/marts/core/fct_kpis_enterprise.sql`)

`won_deal_amount` aggregates `finance.dim_enterprise_deals.amount` for rows satisfying:

1. `pipeline_name in ('Enterprise Pipeline', 'Renewal Pipeline')`
2. `deal_grouping ilike '%new deal'` (excludes renewals)
3. `stage_category = 'won'`

Bucketed by `date_trunc('month', closedate)`.
