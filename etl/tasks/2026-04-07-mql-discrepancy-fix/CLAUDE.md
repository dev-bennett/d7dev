# MQL Discrepancy Fix — ETL Task

@../CLAUDE.md

## Purpose

Draft dbt model changes to fix the MQL discrepancy identified in
`analysis/data-health/2026-04-07-mql-discrepancy/`. Two models touched:

1. `fct_sessions_build.sql` — expand enterprise form event matching
2. `dim_mql_mapping.sql` — tiered HubSpot-to-Mixpanel session matching

## Table References

- `soundstripe_prod.core.fct_events` -- Mixpanel events
- `soundstripe_prod.core.fct_sessions` -- Session-level aggregation
- `soundstripe_prod.core.dim_session_mapping` -- Event-to-session mapping
- `soundstripe_prod.hubspot.hubspot_forms` -- HubSpot form submissions
- `soundstripe_prod.staging.stg_contacts_2` -- HubSpot contacts
- `pc_stitch_db.soundstripe.users` -- Soundstripe user table
