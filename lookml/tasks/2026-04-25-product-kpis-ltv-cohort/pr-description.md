# Add LTV by Cohort view + explore (Product KPIs Dashboard)

## Summary

- Adds new view `fct_ltv_subscription_projections.view.lkml` (`views/Finance/`) wrapping `FINANCE.FCT_LTV_SUBSCRIPTION_PROJECTIONS`.
- Adds new explore `fct_ltv_subscription_projections` ("LTV by Cohort") to `Models/Finance.model.lkml`.
- Default-filtered to self-serve plans, excluding Twitch.

## Why

Asana ticket [1212712551977630](https://app.asana.com/1/411777761188590/project/1205525083743256/task/1212712551977630) (Meredith Knott) — Product KPIs dashboard 19 needs two LTV cohort tiles. The existing `fct_kpis_self_service` view aggregates LTV at event_month grain with no plan/billing dimension, so a cohort breakdown requires a new subscription-grain surface.

## What's in the view

- Cohort dimensions: `plan_type`, `billing_period_unit`, `plan_cohort` (concat label), `is_self_serve`, `is_twitch`.
- Subscription attributes: `value_type` (invoice / projected), `current_contract_state`, `plan_detail`, acquisition channel, user attributes.
- Time: `sub_start` and `sub_end` dimension groups.
- Measures (group "LTV"):
  - `subscription_count` — count_distinct on `subscription_id`.
  - `ltv_1_yr_total` — `SUM(total_amount_paid) WHERE months_into_subscription <= 12`.
  - `ltv_1_yr_per_subscription` — average LTV per subscription within filter.

## Source

`fct_ltv_subscription_projections` (dbt model at `models/marts/finance/fct_ltv_subscription_projections.sql`) unions actual invoice payments + monthly model-based projections. For mature cohorts (>12 months), the 1-yr LTV is fully actual; for in-flight cohorts it blends actual + projected.

## Self-serve filter

`is_self_serve = (plan_type IN ('business', 'creator', 'pro', 'pro-plus'))`. Positive list of the four current self-serve tiers. Excludes enterprise, twitch-pro, and the deprecated/partner plans `subaccounts` (358 subs, last 2020-03-31) and `straynote-billing` (47 subs).

The initial draft used a negative list (`NOT IN ('enterprise','twitch-pro')`) which would have silently included subaccounts and straynote-billing. Surfaced via q1 cohort coverage and corrected before promotion.

If self-serve is actually channel-based or HubSpot-enriched in your reading of the existing `fct_kpis_self_service` table, flag in review and we'll update the dimension SQL.

## Test plan

- [x] q1 — 16 plan_type × billing_period_unit cells in the warehouse; 11 in self-serve scope; surfaced 2 unexpected plan types (handled)
- [x] q2 — per-cohort 1-yr LTV in plausible USD range vs `subscription_ltv_assumptions.ltv_1_yr_gm` (annual ratios 1.3-1.55; monthly 0.7-0.85, expected given methodology difference)
- [x] q3 — `value_type` distribution: 1.78M invoice / 0.60M projected rows; projections concentrated in <12-month-old cohorts; `sub_start_date` bounded 2016-2026
- [x] Calibration artifact: `knowledge/data-dictionary/calibration/finance__fct_ltv_subscription_projections.md` (2.37M rows / 21 cols / 74 MB / full rebuild)
- [ ] LookML validator passes in Looker IDE
- [ ] Test query runs successfully on the new explore (Plan + Billing × 1-Yr LTV / Subscription)
- [ ] Two tiles added to Dashboard 19 (Looker UI), values within expected order of magnitude

## Out of scope

- 2-yr / 3-yr / 5-yr LTV (single-line follow-up if Meredith asks).
- Modifying `fct_kpis_self_service` measures.
- Joins to subscriber-attribute tables (current view exposes the in-table attributes; future tiles can extend via joins on demand).
