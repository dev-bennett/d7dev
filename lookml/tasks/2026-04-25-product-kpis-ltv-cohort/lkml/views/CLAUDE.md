# Views

@../CLAUDE.md

LookML view files for this task. Target Looker repo path: `views/Finance/`.

## Files
- `fct_ltv_subscription_projections.view.lkml` — wraps `FINANCE.FCT_LTV_SUBSCRIPTION_PROJECTIONS` (dbt model `context/dbt/models/marts/finance/fct_ltv_subscription_projections.sql`). Subscription-grain LTV with plan_type + billing_period_unit cohort, 1-yr LTV measure.
