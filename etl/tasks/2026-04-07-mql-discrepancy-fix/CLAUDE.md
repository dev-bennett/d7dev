# MQL Discrepancy Fix — ETL Task

@../CLAUDE.md

## Status

Complete (2026-05-07). Will re-open if Devon's morning verification finds issues. See README.md "Closeout" section for the deploy/revert/redeploy story.

## Purpose

Draft dbt model changes to fix the MQL discrepancy identified in
`analysis/data-health/2026-04-07-mql-discrepancy/`. Two models touched:

1. `fct_sessions_build.sql` — `backfill_from` var (Change 1B). Original `enterprise_schedule_demo` filter retained — the proposed expansion was reverted on 2026-05-07.
2. `dim_mql_mapping.sql` — tiered HubSpot-to-Mixpanel session matching, plus four coverage edits (pricing-page event, /api CTA event, base_url normalization, tier-2 300s window, expanded enterprise_url_patterns).

## Table References

- `soundstripe_prod.core.fct_events` -- Mixpanel events
- `soundstripe_prod.core.fct_sessions` -- Session-level aggregation
- `soundstripe_prod.core.dim_session_mapping` -- Event-to-session mapping
- `soundstripe_prod.hubspot.hubspot_forms` -- HubSpot form submissions
- `soundstripe_prod.staging.stg_contacts_2` -- HubSpot contacts
- `pc_stitch_db.soundstripe.users` -- Soundstripe user table
