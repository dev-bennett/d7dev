# Q1: MQL Divergence Quantification

@../CLAUDE.md

Weekly side-by-side comparison of HubSpot vs Mixpanel MQL counts for the past 9 completed ISO weeks. Goal: pinpoint the exact ISO week divergence begins and quantify the widening gap.

## Table References

- `soundstripe_prod.hubspot.hubspot_forms` -- HubSpot form submissions
- `soundstripe_prod.staging.stg_contacts_2` -- HubSpot contacts (`became_mql` timestamp)
- `soundstripe_prod.core.fct_sessions` -- Mixpanel session-level MQL flags
