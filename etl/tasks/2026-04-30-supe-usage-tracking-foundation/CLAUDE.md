@../CLAUDE.md

# 2026-04-30 — Supe Usage Tracking Foundation

ETL task workspace for AJ Robertson's PR #4147 — five new Supe enterprise-API
usage-tracking tables plus column additions on `contracts` and `supe_searches`.

## Status

**Deployed 2026-04-30 AM.** AJ has merged PR #4147 and seeded a few rows of
test data. Schema-review gate is now open. Stitch pickup status TBC — verify
the tables exist in the warehouse before downstream dbt source registration.
Customer traffic still pending Amazon activation; volume will be near-zero
until then.

## Files

- `README.md` — task context, scope, AJ's Slack message verbatim, downstream work plan
