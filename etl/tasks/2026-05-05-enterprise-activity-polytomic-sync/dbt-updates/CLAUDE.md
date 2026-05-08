# dbt-updates

@../CLAUDE.md

Drafts of the dbt model + schema.yml changes Devon will paste into the
dbt Cloud web IDE on `develop_dab`. Files here are NOT live — they're
the proposed source ready for promotion.

## Files
- `fct_enterprise_user_activity_for_scoring.sql` — modified model;
  surfaces `companyid` so Polytomic can sync to HubSpot Companies on
  the native object_id.
- `_enterprise.yml` — new schema.yml entry covering this model
  (description, tests, column docs). No prior yml exists for the model.
