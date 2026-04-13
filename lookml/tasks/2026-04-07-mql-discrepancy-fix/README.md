# MQL Discrepancy — LookML Changes
- **Status:** draft
- **Date:** 2026-04-07
- **PR:** pending
- **Views touched:** fct_sessions (sql_table_name change + new measures)
- **Source:** analysis/data-health/2026-04-07-mql-discrepancy/

## Context

Points fct_sessions.view.lkml at the new fct_sessions_enriched table and adds
reconciled MQL dimensions/measures under "MQL (Reconciled)" group label. Old
Mixpanel-only MQL measures are hidden after validation.

## Files
- `fct_sessions_view_changes.lkml` — documented changes to fct_sessions.view.lkml
