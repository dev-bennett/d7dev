# Phase A — Contacts-Shape Discovery

@../CLAUDE.md

Warehouse-level shape queries for `soundstripe_prod.hubspot.hubspot_contacts` (the mart model derived from `hubspot_objects_with_type` filtered to `object_type = 'CONTACT'`, sourcing from `hubspot_platform_data.object_with_object_properties`).

Complements the 50-row `q1.csv` sample with full-table distributions. Results feed the HubSpot contacts object KB article and the Phase C diagnostic queries (candidate score-field enumeration depends on A3/A6/A7/A8 distributions).

## Key schema note

PROPERTIES is a flat JSON object on this mart (`properties:key_name::type`), NOT the nested-with-`:value:` shape used in the staging model `stg_contacts.sql` (which reads from `crm.contacts`). Queries here use the flat form.

The top-level `SOUNDSTRIPE_INTERNAL_ACCOUNT` column is derived in the mart as `properties:hs_internal_user_id::integer IS NOT NULL`.

## Files

- `queries.sql` — A1 through A12
- `aN.csv` — one CSV per query (exported after running in Snowflake)
- `FINDINGS.md` — written after CSVs return, with Type Audits for rate queries
