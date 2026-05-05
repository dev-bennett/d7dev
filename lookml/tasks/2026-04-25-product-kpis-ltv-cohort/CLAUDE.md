# Product KPIs Dashboard — LTV by Cohort

@../CLAUDE.md

LookML task delivering two new tiles for Looker dashboard 19 (Product KPIs):

1. Current 1-yr LTV by cohort (plan_type + billing_period_unit), self-serve only including Business, excluding Twitch.
2. Same metric over time (cohort signup month).

## Asana
[Task 1212712551977630 — Add LTV and LTV over time by cohort to Product KPIs dash in Looker](https://app.asana.com/1/411777761188590/project/1205525083743256/task/1212712551977630)
Submitter: Meredith Knott · Assignee: Devon Bennett · Due: 2026-02-20.

## Files
- `README.md` — scope, status, assumptions, owners
- `lkml/views/fct_ltv_subscription_projections.view.lkml` — new view wrapping `FINANCE.FCT_LTV_SUBSCRIPTION_PROJECTIONS`
- `lkml/explores/ltv_subscription_projections.explore.fragment.lkml` — explore block to insert into a model file
- `dashboard-tile-spec.md` — tile-by-tile spec (visualization, dimensions, filters)
- `promotion-guide.md` — Looker IDE promotion checklist + dashboard editing steps
- `verify/sanity_checks.sql` — three SQL queries to run via `/sql` after calibration
- `commit-message.md` — Looker repo commit message
- `pr-description.md` — Looker repo PR description

## Promotion path
LookML files prepared here. Devon promotes view + explore via the Looker IDE on a dev branch and adds the two tiles to Dashboard 19 in the Looker UI (the dashboard is user-defined, not a LookML dashboard). See `feedback_lookml_promotion_workflow`.

## Pre-step
`finance.fct_ltv_subscription_projections` has no calibration artifact. Before running `verify/sanity_checks.sql`, run `/calibrate finance.fct_ltv_subscription_projections` per the first-touch rule in `.claude/rules/snowflake-mcp.md`.
