# Fix 2 — Deals Source Swap to HPD

@../CLAUDE.md

## Purpose

Switch `models/staging/hubspot/stg_deals.sql` source from `{{ source('crm', 'deals') }}` (Stitch ETL of `pc_stitch_db.hubspot_new.deals`) to `hubspot_platform_data.v2_daily.objects_deals` (HubSpot's authoritative Operations Hub data share). Closes variance 5 from the 2026-05-05 enterprise reporting reconciliation.

## Files

- `stg_deals.sql` — drop-in replacement, mapped to HPD column shape
- `notes.md` — change rationale, downstream impact (especially `stg_deals_event_log.sql`), open considerations

## Table References

- `hubspot_platform_data.v2_daily.objects_deals` (894 flat columns, replaces Stitch's JSON-properties shape)
- `hubspot_platform_data.v2_daily.associations_deals_to_companies` (replaces `associations:associatedCompanyIds[0]`)

## Risk

Higher than Fix 1. Read `notes.md` end-to-end before merging; the downstream `stg_deals_event_log.sql` has a non-trivial dependency on `properties_versions` that doesn't translate directly.
