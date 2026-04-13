# Q7: Closing the Remaining Gap

@../CLAUDE.md

Three strategies for the ~27 HubSpot MQLs with no form event match:
1. Session-level matching — users with page views on enterprise URLs but no form event
2. Email property matching — search raw Mixpanel export for email captured in event properties
3. HubSpot-native attribution — UTM data captured by HubSpot at form submission as fallback

## Table References

- `pc_stitch_db.mixpanel.export` -- Raw Mixpanel events
- `soundstripe_prod.hubspot.hubspot_forms` -- HubSpot submissions (has PAGE_URL with UTMs)
- `soundstripe_prod.staging.stg_contacts_2` -- HubSpot contacts (first_url, first_referrer)
- `soundstripe_prod.core.fct_events` -- Post-pipeline Mixpanel events
- `soundstripe_prod.core.fct_sessions` -- Session-level aggregation with UTMs
