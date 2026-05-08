# Runbook — Promote and activate the enterprise-activity Polytomic sync

## Pre-flight (one-time)

- d7dev `context/dbt` submodule pointer is current with `origin/main`
  (verified 2026-05-05; bumped from `9bb586c` → `504f24d`).
- `transformations.subscriber_activity` and
  `marts/enterprise/fct_enterprise_user_activity_for_scoring` are
  already on `origin/main` (PR #718/#719).

## Step 1 — Promote dbt changes via dbt Cloud web IDE

dbt Cloud → web IDE → branch `develop_dab`.

1. Replace `models/marts/enterprise/fct_enterprise_user_activity_for_scoring.sql`
   with the version at
   `etl/tasks/2026-05-05-enterprise-activity-polytomic-sync/dbt-updates/fct_enterprise_user_activity_for_scoring.sql`.
2. Add `models/marts/enterprise/_enterprise.yml` (new file) with the
   contents from `dbt-updates/_enterprise.yml`. If a file with that name
   already exists, merge the `models:` entries.
3. In the web IDE: `dbt run -s subscriber_activity fct_enterprise_user_activity_for_scoring`
   then `dbt test -s fct_enterprise_user_activity_for_scoring`. Fix any
   failures before proceeding.
4. Run `verify/sanity_checks.sql` (substituting `{{database}}` =
   `soundstripe_dev`, `{{schema}}` = the dev schema produced by your
   target — usually `core` or `marts_enterprise`). Confirm:
   - v01 dup_companyid_rows = 0; null_companyid_rows = 0
   - v02 unmatched_rows = 0
   - v03 fan-out distribution looks sensible (no single company at
     chargebee_customer_count > ~3 without explanation)
   - v04 coverage approximately matches pre-merge audit (483 companies)
5. Commit on `develop_dab`. Open PR with base = `main`. Use
   `pr-description.md` for the PR body. Request review per usual.

## Step 2 — Bump d7dev's submodule pointer (post-merge)

After PR merges to `dbt-transformations:main`, sync d7dev's submodule
reference (already done speculatively in this task — but re-run to pick
up the merge commit):

```
cd /Users/dev/PycharmProjects/d7dev
git submodule update --remote context/dbt
git add context/dbt && git -m "Bump dbt submodule to current main (PR <#> merged)"
```

## Step 3 — Create HubSpot Company custom properties

Sales/RevOps owns this in HubSpot UI. Create as type Number:

- `ss_active_users`
- `ss_sessions_last_30`
- `ss_sessions_prior_30`
- `ss_song_downloads_last_30`
- `ss_song_downloads_prior_30`
- `ss_projects_created_last_30`
- `ss_projects_created_prior_30`

Optional Number:
- `ss_chargebee_customer_count` (diagnostic — surfaces fan-out cases)

Group: Sales / Account Health (or whatever HubSpot already uses for
similar custom property groups).

## Step 4 — Configure Polytomic sync

Polytomic UI:

- **Source:** Snowflake — `soundstripe_prod.<schema>.fct_enterprise_user_activity_for_scoring`
- **Target:** HubSpot Companies
- **Sync mode:** Update (upsert allowed if Polytomic supports
  create-when-missing — but the model only contains existing companies
  from `dim_enterprise_deals`, so create cases shouldn't occur)
- **Identity / upsert key:** `companyid` → HubSpot Company object_id
- **Field mapping:**
  - `active_users` → `ss_active_users`
  - `sessions_last_30` → `ss_sessions_last_30`
  - `sessions_prior_30` → `ss_sessions_prior_30`
  - `song_downloads_last_30` → `ss_song_downloads_last_30`
  - `song_downloads_prior_30` → `ss_song_downloads_prior_30`
  - `projects_created_last_30` → `ss_projects_created_last_30`
  - `projects_created_prior_30` → `ss_projects_created_prior_30`
  - `chargebee_customer_count` → `ss_chargebee_customer_count` (optional)
- **Frequency:** Daily (matches the dbt model build cadence; finer
  cadence not needed for AM/CS use case)
- **Dry-run / preview:** Polytomic should show 483 records affected;
  inspect 3 sample rows; confirm field types and nullability.

## Step 5 — UAT and activation

1. Activate the sync (one cycle).
2. In HubSpot UI, open 3 enterprise companies that the verify queries
   identified as having activity. Confirm the `ss_*` properties are
   populated and match the warehouse values.
3. Loop in Sales/CS: ask one AM and one CSM to confirm the new fields
   are visible in their views and triggerable in HubSpot workflows.
4. If Sales/CS approve, leave on. If not, pause and iterate on field
   names/granularity.

## Rollback

- Polytomic sync: pause from the Polytomic UI; HubSpot custom property
  values stop updating (existing values stay in place, which is fine).
- dbt model: revert the PR. Submodule bump and yml additions are
  forward-compatible — the original model will still build.
- HubSpot custom properties: leave in place (cheap to keep, expensive
  to recreate if reactivated later).
