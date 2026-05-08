# Enterprise Activity → HubSpot Companies (Polytomic sync)

**Status:** drafted — ready for promotion via dbt Cloud web IDE
**Asana ticket:** TBD (sales/CS request — no specific ticket cited; pre-existing deferred work from Geoff Aoyagi pre-departure)
**dbt PR target:** `dbt-transformations` repo, base `main`, branch `develop_dab`

## What this is

Wires the deferred Polytomic sync for
`marts/enterprise/fct_enterprise_user_activity_for_scoring` (PR #719,
merged but never connected to HubSpot). Phase A only — covers the
Chargebee-billed enterprise customers (~483 active HubSpot Companies,
≈48% of won enterprise customer base); non-Chargebee enterprise
customers (~225 companies, 22% of won enterprise base) are deferred to
Phase B (identity-bridge work).

## Geoff's "missing object-specific join key" — recovered

The merged model outputs `(CUSTOMER_ID, SUBSCRIPTION_ID)` — both
Chargebee IDs. HubSpot Company has no Soundstripe-side custom
property to upsert against, so Polytomic had no Company-side join key.
The fix surfaces `companyid` (HubSpot's native object_id) into the
model output by joining to `finance.dim_enterprise_deals` on
`chargebee_customer_id`. See `findings.md` for the full diagnosis and
coverage numbers.

## Files

- `findings.md` — diagnosis of Geoff's deferral + Phase A solution +
  Phase B scope.
- `runbook.md` — step-by-step promotion + Polytomic configuration.
- `dbt-updates/fct_enterprise_user_activity_for_scoring.sql` — modified
  model with the `companyid` join.
- `dbt-updates/_enterprise.yml` — new schema.yml with description and
  tests.
- `commit-message.txt` — for the dbt PR.
- `pr-description.md` — for the dbt PR body.
- `verify/sanity_checks.sql` — v01-v05 post-build checks.

## Coverage (validated 2026-05-05)

| Metric | Value |
|---|---:|
| HubSpot Companies in model output | 483 |
| Distinct Chargebee customers represented | 489 |
| Distinct Soundstripe users active in 61-day window | 1,076 |
| Total event rows feeding the model | 371,595 |

## Decisions for Devon before activation

1. HubSpot Company custom property names — proposed in `runbook.md`
   step 3; sales/RevOps owns creation.
2. Fan-out review — see `verify/v03`. A few Chargebee customers map to
   multiple HubSpot Companies (max 17, avg 1.32). Confirm broadcast
   behavior is what AM/CS want for those cases.
3. Phase B prioritization — when to scope the identity-bridge work for
   the ~5,500 non-Chargebee enterprise deals.

## Status log

- 2026-05-05 — Submodule pointer bumped (`9bb586c` → `504f24d`) so the
  merged model is visible in d7dev. Drafts of model + yml + verify SQL
  + runbook + commit/PR docs prepared. Not yet promoted to `develop_dab`.
