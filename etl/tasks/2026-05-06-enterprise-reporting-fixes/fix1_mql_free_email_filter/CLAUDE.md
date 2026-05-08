# Fix 1 — MQL Free-Email Filter

@../CLAUDE.md

## Purpose

Apply HubSpot list 4459 (`[MASTER] ALL Contacts w/ Free Email Domain List`) exclusion to `models/marts/marketing/dim_mql_mapping.sql`. Closes variance 3 from the 2026-05-05 enterprise reporting reconciliation.

## Files

- `dim_mql_mapping.sql` — drop-in replacement, post-fix
- `notes.md` — change rationale + verification queries

## Table References

- `soundstripe_prod.marketing.dim_mql_mapping` (this model's output)
- `hubspot_platform_data.v2_daily.list_memberships` (the new join source for list 4459 exclusion)
