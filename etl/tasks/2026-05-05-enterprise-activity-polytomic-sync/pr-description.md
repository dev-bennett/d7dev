# Surface `companyid` on `fct_enterprise_user_activity_for_scoring`

## Summary

The enterprise-activity scoring model was merged to `main` ahead of its
Polytomic sync. Sync activation has been blocked because the model
output (`CUSTOMER_ID`, `SUBSCRIPTION_ID`) holds Chargebee identifiers
and HubSpot has no Soundstripe-side custom property on the Company
object to upsert against. AM and CS need account-level engagement
metrics on HubSpot Companies — Contact-grain syncing on
`chargebee_customer_id` is grain-mismatched.

This PR refactors the model to join `subscriber_activity` to
`finance.dim_enterprise_deals` on `chargebee_customer_id` and regroups
the engagement counters at `companyid` grain. Polytomic now has a
native HubSpot object_id to upsert against — no HubSpot custom
property required for the join itself.

Also adds `models/marts/enterprise/_enterprise.yml` documenting both
this model and the parent `subscriber_activity` (no prior yml entry
existed for either).

## Coverage

- 483 HubSpot Companies receive engagement counters (validated against
  live `transformations.subscriber_activity` 2026-05-05).
- ≈48% of the ~1,004 won enterprise customer base in
  `dim_enterprise_deals`.
- Window: days 32-61 ('prior_30') vs days 1-31 ('last_30').
- Phase A scope: Chargebee-billed enterprise customers only. The ~225
  won enterprise customers that have never been Chargebee-billed
  (22% of won enterprise base) require a separate
  `soundstripe_account_id` identity bridge — Phase B, out of scope here.

## Test plan

- [ ] `dbt run -s subscriber_activity fct_enterprise_user_activity_for_scoring`
      builds clean on `develop_dab`.
- [ ] `dbt test -s fct_enterprise_user_activity_for_scoring` passes
      (not_null + unique on `companyid`; relationships test if
      configured).
- [ ] `verify/sanity_checks.sql` v01-v05 pass on the dev build:
      grain (one row per `companyid`, no nulls, no dups), relationships
      (every output row maps to a deal), fan-out distribution looks
      sensible, coverage ≈ 483 companies, output schema matches expected
      column list.
- [ ] Polytomic dry-run preview against the prod table shows ~483
      Companies receiving updates and no orphan records.
- [ ] After Polytomic sync activation, spot-check 3 enterprise companies
      in HubSpot UI; values match warehouse.

## Out of scope

- Polytomic sync configuration (separate workstream).
- HubSpot Company custom property creation (Sales/RevOps owns).
- Phase B: identity bridge for non-Chargebee enterprise deals.
- Resolution of the fan-out cases (a few Chargebee customers map to
  multiple HubSpot Companies — surfaced via `chargebee_customer_count`
  column for sales-ops review).
