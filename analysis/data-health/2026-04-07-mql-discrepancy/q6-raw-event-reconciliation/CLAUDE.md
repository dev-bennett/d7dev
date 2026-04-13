# Q6: Raw Event Reconciliation — First Principles

@../CLAUDE.md

For HubSpot MQLs that are "missing" from the Mixpanel pipeline, search the RAW Mixpanel export for ANY events near the HubSpot submission timestamp + URL, regardless of identity. This tests whether the events exist under anonymous device IDs that the identity chain hasn't merged.

Also tests the dim_mql_mapping secondary match logic (time + URL, no VID) to determine why it fails.

## Table References

- `soundstripe_prod.hubspot.hubspot_forms` -- HubSpot form submissions
- `soundstripe_prod.staging.stg_contacts_2` -- HubSpot contacts
- `pc_stitch_db.mixpanel.export` -- Raw Mixpanel events (pre-pipeline)
- `soundstripe_prod.core.fct_events` -- Post-pipeline events
- `soundstripe_prod.transformations.distinct_id_mapping` -- Identity consolidation
