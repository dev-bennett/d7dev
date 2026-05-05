# Product KPIs — LTV by Cohort (Asana 1212712551977630)

**Status:** verified — calibration + verify SQL executed 2026-04-25; ready for Looker IDE promotion pending Devon's review of the self-serve definition refinement (see Verification below).

**Asana:** https://app.asana.com/1/411777761188590/project/1205525083743256/task/1212712551977630
**Submitter:** Meredith Knott · **Assignee:** Devon Bennett · **Original due:** 2026-02-20

## Scope

Two new tiles on Looker dashboard 19 (Product KPIs):

1. **Current 1-yr LTV by cohort** — cohort = `plan_type` with `billing_period_unit` (e.g., `pro year`, `business month`); transactional source. Self-serve only including Business; exclude Twitch.
2. **1-yr LTV over time for the same cohorts** — cohort signup-month time series.

## Source

- dbt model: `soundstripe_prod.finance.fct_ltv_subscription_projections` (`context/dbt/models/marts/finance/fct_ltv_subscription_projections.sql`).
- Subscription grain. Unions actuals (`dim_ltv_subscriber_payments`) and projections (`dim_ltv_subscriber_projections_monthly`).
- Key columns: `subscription_id`, `plan_type`, `billing_period_unit`, `sub_start_date`, `months_into_subscription`, `total_amount_paid`, `value_type`.

## Assumptions (verified 2026-04-25)

| # | Assumption | Verification |
|---|---|---|
| 1 | **Self-serve = `plan_type IN ('business', 'creator', 'pro', 'pro-plus')`** — positive list, four current self-serve tiers | Initial draft used a negative list (`NOT IN ('enterprise', 'twitch-pro')`). q1 surfaced two unexpected plan types (`subaccounts` 358 subs deprecated 2020; `straynote-billing` 47 subs partner integration) that the negative list would have included. Updated to positive list 2026-04-25. |
| 2 | 1-yr LTV = sum of `total_amount_paid` where `months_into_subscription <= 12` | q3 confirms invoice + projection rows total 2,376,777 (matches calibration). For cohorts <12 months old, the projection rows are model-based; for mature cohorts, all 12 months are actual invoice rows. |
| 3 | Cohort label = `plan_type \|\| ' ' \|\| billing_period_unit` | q1 surfaced 11 self-serve cohort cells (no `business month`; `pro-plus quarter` only 6 subs). |
| 4 | Time axis = `sub_start_date` truncated to month | q1 confirms `sub_start_date` ranges from 2016 to 2026-04-25; no nulls, no future dates. |
| 5 | Dashboard 19 is user-defined; tiles added in Looker UI | Confirmed via LookML file search — no `*.dashboard.lookml` for Product KPIs. |
| 6 | Realized-revenue methodology (not forward-looking expected value) | q2 ratio analysis: annual cohorts run ~1.3-1.55× the GM benchmark (gross > GM, expected); monthly cohorts run ~0.7-0.85× (gross < GM, expected once you account for the assumption table's forward-looking retention model). Different methodology, not a measure bug. |

## Files

| Path | Purpose |
|---|---|
| `lkml/views/fct_ltv_subscription_projections.view.lkml` | Wraps the FINANCE table; cohort dimensions + 1-yr LTV measures |
| `lkml/explores/ltv_subscription_projections.explore.fragment.lkml` | Explore block to insert into a model file |
| `dashboard-tile-spec.md` | Tile-by-tile spec for Devon to apply in Looker UI |
| `promotion-guide.md` | End-to-end Looker IDE + dashboard editing checklist |
| `verify/sanity_checks.sql` | q1 cohort coverage, q2 LTV reconciliation, q3 date-range bounds |
| `commit-message.md` | Commit message for the Looker repo PR |
| `pr-description.md` | PR description for the Looker repo PR |

## Verification (2026-04-25)

Calibration: `knowledge/data-dictionary/calibration/finance__fct_ltv_subscription_projections.md` (2,376,777 rows / 21 cols / 74 MB / full rebuild — no late-arrival risk).

Verify SQL: `verify/sanity_checks.sql` executed via MCP.

| Query | Result | Action taken |
|---|---|---|
| q1 (cohort row counts) | 16 plan_type × billing cells; 4 self-serve tiers cover the 5 highest-volume cells. **Surprise**: `subaccounts` (358 subs, deprecated) and `straynote-billing` (47 subs) appeared. | Updated `is_self_serve` to positive list — see Assumption 1. |
| q2 (per-cohort sanity vs `subscription_ltv_assumptions`) | All 11 self-serve cohort cells return non-null per-sub LTV in plausible USD ranges. Annual-cohort gross-to-GM ratio 1.3-1.55 (expected); monthly-cohort ratio 0.7-0.85 (expected — see Assumption 6). | None — passes. |
| q3 (value_type + cohort age distribution) | invoice 1.78M rows / 245K subs; projected 0.60M rows / 19K subs. Projections present beyond month 12 for in-flight cohorts. | None — passes. |

Three calibrated gotchas captured in the calibration artifact (mix of actuals + projections, row grain ≠ subscription count, attribution carries `fct_sessions` contamination zones). The dashboard tile spec relies on `is_self_serve = yes` + `is_twitch = no` filters which sidestep the contamination caveat for self-serve cohorts.

Open soft-warn: `core.fct_kpis_self_service` is fact-named but tiny (36 rows / 20KB / dim-grain in practice) — referenced in an earlier draft of q2 but removed; no calibration created. Promotion candidate at session end.

## Owners
- Submitter: Meredith Knott
- Builder: Devon Bennett
- Reviewers (suggested): Meredith for tile spec sign-off; Finance team if LTV definition needs cross-check
