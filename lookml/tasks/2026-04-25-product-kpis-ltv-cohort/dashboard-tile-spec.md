# Dashboard Tile Spec — Product KPIs Dashboard 19

Two new tiles for the user-defined Looker dashboard at https://soundstripe.cloud.looker.com/dashboards/19. Both use the new explore `fct_ltv_subscription_projections` (LTV by Cohort).

## Default explore filters

Both tiles inherit the explore's `always_filter`:
- `is_self_serve` = yes
- `is_twitch` = no

This produces the "self-serve only, including Business, excluding Twitch" cohort scope from the Asana brief.

## Tile 1 — Current 1-Yr LTV by Cohort

| Property | Value |
|---|---|
| Title | "Current 1-Yr LTV by Cohort" |
| Visualization | `looker_column` (vertical bar) |
| Dimension | `fct_ltv_subscription_projections.plan_cohort` |
| Measure | `fct_ltv_subscription_projections.ltv_1_yr_per_subscription` |
| Filters | `sub_start_date_month` ≥ 24 months ago AND ≤ 12 months ago (so each cohort has matured ≥12 months) |
| Sort | descending by measure |
| Y-axis | min 0; format USD; auto title |
| Data labels | on |

**Why the date filter:** A cohort's "1-year LTV" is only fully realized 12 months after signup. The 24-month-to-12-month-ago window picks cohorts whose first 12 months are complete (no projection rows leaking in for incomplete cohorts).

## Tile 2 — 1-Yr LTV Over Time by Cohort

| Property | Value |
|---|---|
| Title | "1-Yr LTV Over Time by Cohort" |
| Visualization | `looker_line` |
| Dimension | `fct_ltv_subscription_projections.sub_start_date_month` |
| Pivot | `fct_ltv_subscription_projections.plan_cohort` |
| Measure | `fct_ltv_subscription_projections.ltv_1_yr_per_subscription` |
| Filters | `sub_start_date_month` ≥ 24 months ago |
| Sort | ascending by month |
| Y-axis | min 0; format USD; auto title |
| Show null points | off |

**Why no upper-bound date filter:** Recent cohorts (<12 months old) will reflect a mix of actual + projected revenue per the dbt model's design. Showing the trend without artificially clipping recent months keeps the chart interpretable as the model intends.

**Caveat to note inline on the dashboard:** "Recent cohort months blend actual and projected revenue; cohorts older than 12 months are entirely actual."

## Layout suggestion

Place both tiles in a new row near the existing LTV scorecards on Dashboard 19. Tile 1 (column) on the left, Tile 2 (line) on the right. Width 12 columns total (6 + 6) to match newspaper-layout convention.

## Filter behavior on the dashboard

Dashboard 19 already exposes `Date Trunc`, `Session Started At Date`, and `Subscriber Category` filters. None apply to these tiles directly (the new explore doesn't expose those fields). Two options:
1. Leave the new tiles independent of the dashboard's existing filters. Simplest.
2. Add a `Cohort Start Month` filter to the dashboard that maps to `sub_start_date_month` — only if Meredith asks for it.

Recommendation: ship with option 1; revisit if the dashboard owner wants linked filters.
