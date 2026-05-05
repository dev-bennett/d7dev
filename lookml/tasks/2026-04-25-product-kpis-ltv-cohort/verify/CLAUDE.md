# Verification SQL

@../CLAUDE.md

Sanity-check queries for the new LTV cohort view. Run via `/sql` after calibrating `finance.fct_ltv_subscription_projections`.

## Files
- `sanity_checks.sql` — three labeled queries (q1 cohort row counts, q2 LTV reconciliation vs `fct_kpis_self_service.ltv_1_yr`, q3 `sub_start_date` bounds).

## Pre-step
First-touch calibration per `.claude/rules/snowflake-mcp.md`:
```
/calibrate finance.fct_ltv_subscription_projections
```
