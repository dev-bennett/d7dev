# Q4: Gap Reconciliation

@../CLAUDE.md

Reconcile the remaining gap between HubSpot and Mixpanel MQL counts. Two vectors:
1. What HubSpot form names are driving the increase? Are there new forms beyond the 5 known enterprise forms?
2. Are captured Mixpanel events being lost at the fct_sessions aggregation layer?

## Table References

- `soundstripe_prod.hubspot.hubspot_forms` -- HubSpot form submissions
- `soundstripe_prod.staging.stg_contacts_2` -- HubSpot contacts
- `soundstripe_prod.core.fct_sessions` -- Mixpanel session MQL flags
- `soundstripe_prod.core.fct_events` -- Mixpanel events (post-staging)
