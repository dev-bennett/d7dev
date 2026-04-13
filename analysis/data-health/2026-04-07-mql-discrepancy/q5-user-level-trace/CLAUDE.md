# Q5: User-Level Clickstream Trace

@../CLAUDE.md

For HubSpot MQL contacts that DON'T appear in the Mixpanel MQL count, trace their full clickstream in raw Mixpanel data around the HubSpot form submission timestamp.

Identity resolution chain:
- HubSpot email → stg_contacts_2 (canonical_vid, soundstripe_user_id)
- soundstripe_user_id → fct_events.user_id (direct match)
- canonical_vid → pc_stitch_db.soundstripe.users.hubspot_contact_vid → users.id → fct_events.user_id

## Table References

- `soundstripe_prod.hubspot.hubspot_forms` -- HubSpot form submissions
- `soundstripe_prod.staging.stg_contacts_2` -- Identity link (canonical_vid, soundstripe_user_id)
- `pc_stitch_db.soundstripe.users` -- Soundstripe user table (hubspot_contact_vid link)
- `soundstripe_prod.core.fct_events` -- Mixpanel events (post-staging, identity-resolved)
