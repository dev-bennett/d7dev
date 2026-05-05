# Promotion Guide — LTV by Cohort

## Overview

Two LookML deliverables to add to the Looker repo (`SoundstripeEngineering/looker`):
1. New view `fct_ltv_subscription_projections.view.lkml`.
2. New explore `fct_ltv_subscription_projections` (block appended to `Models/Finance.model.lkml` or `Models/General.model.lkml`).

Plus two tiles to add directly to Dashboard 19 in the Looker UI (it is a user-defined dashboard, not a LookML dashboard).

## Step 0 — Calibration + verify SQL (executed 2026-04-25)

**Done.** Calibration artifact: `knowledge/data-dictionary/calibration/finance__fct_ltv_subscription_projections.md`. Verify SQL ran clean — see README "Verification" section for the q1/q2/q3 results table.

Re-run only if the source table or LookML view changes:

```
/calibrate --refresh finance.fct_ltv_subscription_projections
/sql verify/sanity_checks.sql
```

## Step 1 — Add view file (Looker IDE)

Create `views/Finance/fct_ltv_subscription_projections.view.lkml` in the Looker repo dev branch.

Source: `lkml/views/fct_ltv_subscription_projections.view.lkml` (this directory). Copy the full contents as-is.

No include changes needed — `Models/General.model.lkml` and `Models/Finance.model.lkml` already auto-discover via `include: "/**/*.view.lkml"`.

## Step 2 — Append explore block

Open `Models/Finance.model.lkml` (preferred — keeps the explore with the Finance schema view) and append the explore block from:

`lkml/explores/ltv_subscription_projections.explore.fragment.lkml`

Block contents:

```lookml
explore: fct_ltv_subscription_projections {
  label: "LTV by Cohort"
  group_label: "Finance"
  description: "Subscription-grain 1-yr LTV by plan_type + billing_period_unit cohort. Sourced from FINANCE.FCT_LTV_SUBSCRIPTION_PROJECTIONS (unions actuals + projections). Default-filtered to self-serve, excluding Twitch."

  always_filter: {
    filters: [fct_ltv_subscription_projections.is_self_serve: "yes",
              fct_ltv_subscription_projections.is_twitch: "no"]
  }
}
```

If `Finance.model.lkml` does not already include the new view (check the `include` lines at the top), no change is needed because the model uses recursive include patterns.

## Step 3 — Validate in Looker IDE

1. Save & validate the dev branch (Looker IDE → "Validate LookML" button).
2. Expected outcome: 0 errors, 0 warnings.
3. Open Explore → "LTV by Cohort". Run a test query:
   - Dimensions: `Plan + Billing` (`plan_cohort`)
   - Measure: `1-Yr LTV / Subscription` (`ltv_1_yr_per_subscription`)
   - Filter: `Sub Start Date Month` ≥ 24 months ago, ≤ 12 months ago
4. Confirm cohort cells appear with reasonable USD values (per `subscription_ltv_assumptions.sql` reference: ~$105 creator-year, ~$206 pro-year, ~$821 business-year — these are GM-adjusted and may differ from `total_amount_paid` totals; treat as order-of-magnitude reference).

## Step 4 — Add tiles to Dashboard 19 (Looker UI)

Dashboard 19 (Product KPIs) is user-defined; tile additions happen in the Looker UI, not via LookML.

1. Open https://soundstripe.cloud.looker.com/dashboards/19 → click "Edit Dashboard".
2. Click "Add Tile" → "Visualization".
3. Build Tile 1 per `dashboard-tile-spec.md` ("Current 1-Yr LTV by Cohort"). Save.
4. Build Tile 2 per `dashboard-tile-spec.md` ("1-Yr LTV Over Time by Cohort"). Save.
5. Layout: place the two tiles in a new row near existing LTV scorecards. 6 + 6 column widths.
6. Save dashboard. Inspect rendered values for sanity (no NULL cohort cells, no negative values).

## Step 5 — Commit and PR

Use the commit message and PR description from:
- `commit-message.md`
- `pr-description.md`

Open the PR against `master` (Looker repo default branch).

## Step 6 — Notify

After PR merges and dashboard tiles are live:
1. Comment on Asana ticket 1212712551977630 with: dashboard URL, brief summary of what was added, and the cohort/self-serve assumption for sign-off.
2. Mark task complete in Asana once Meredith confirms the metric matches her intent.

## Rollback

If the metric is wrong post-deploy:
1. Hide the new tiles via the dashboard editor (don't delete) so audit trail is preserved.
2. Revert the LookML PR or open a fix-forward PR adjusting the view's `is_self_serve` SQL or the measure filter.
