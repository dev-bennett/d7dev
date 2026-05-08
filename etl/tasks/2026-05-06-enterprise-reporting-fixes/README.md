# Enterprise Reporting Fixes
- **Status:** ready to deploy
- **Date opened:** 2026-05-06
- **Source:** `analysis/adhoc/2026-05-05-enterprise-reporting-comparison/findings.md`
- **Stakeholders:** Ryan Severns (RevOps), Dave Kart
- **Owner:** Devon (deploys later this week)

## Context

Two engineering changes that close variance 3 (MQL counts) and variance 5 (April deal counts) from the 2026-05-05 reconciliation. Each is independently deployable; bundling is also fine.

## Items

### Fix 1 — MQL free-email filter on `dim_mql_mapping`

- **Variance:** Looker MQL YTD = 758, HubSpot MQL YTD = 470. Gap = 288 contacts.
- **Mechanism:** HubSpot view 19857810 excludes contacts in list 4459 (`[MASTER] ALL Contacts w/ Free Email Domain List`, 1.4M members). Looker's `dim_mql_mapping.mqls = COUNT(DISTINCT email)` doesn't apply that filter. Of 329 Looker-only MQLs at hubspot_uid grain, 312 (95%) are list-4459 members.
- **Change:** Add a list-4459 exclusion CTE to `models/marts/marketing/dim_mql_mapping.sql` and filter the final population.
- **Expected impact:** Looker MQL YTD drops from 758 to ~470. MQL deals (variance 4) propagates from 365 to ~337.
- **Files:** `fix1_mql_free_email_filter/dim_mql_mapping.sql` (drop-in), `fix1_mql_free_email_filter/notes.md`.
- **Risk:** Low. Pure filter addition; no schema change. Coordinate ordering with `etl/tasks/2026-04-07-mql-discrepancy-fix/` (also touches dim_mql_mapping) — both can stack in one PR or sequence.

### Fix 2 — `stg_deals` data source swap to `hubspot_platform_data`

- **Variance:** Looker April-2026 deals = 155, HubSpot UI = 131. Gap = 24 ghost April deals (345 lifetime).
- **Mechanism:** Stitch's HubSpot tap doesn't reliably catch soft-delete/archive events. Records that get deleted or archived in HubSpot stop receiving Stitch updates, but `isdeleted` doesn't flip — they linger as ghost rows. `hubspot_platform_data.v2_daily.objects_deals` is HubSpot's authoritative share and reflects deletion.
- **Change:** Rewrite `models/staging/hubspot/stg_deals.sql` to source from `hubspot_platform_data.v2_daily.objects_deals` instead of `{{ source('crm', 'deals') }}` (Stitch).
- **Expected impact:** Looker April-2026 deals drops from 155 to ~131. The 24 ghost April deals (Columbia University, North Carolina Zoo, Cloud Software Group, etc. — full list in findings.md §Variance 5) drop out of `dim_enterprise_deals`.
- **Files:** `fix2_deals_source_swap_to_hpd/stg_deals.sql` (drop-in), `fix2_deals_source_swap_to_hpd/notes.md`.
- **Risk:** Higher than fix 1. HPD's `OBJECTS_DEALS` is 894 flat columns (`PROPERTY_DEALNAME`, `PROPERTY_AMOUNT`, etc.) vs. Stitch's 4 base columns + JSON `properties` blob. The rewrite is a column-mapping migration, not a 1-line source swap. Downstream `stg_deals_event_log.sql` consumes `properties_versions` from stg_deals — that field has no direct equivalent in HPD; that downstream model needs separate consideration (covered in `notes.md`).

## Deployment

dbt commands only update `soundstripe_dev`. Production updates via PR merge to `main`.

For each fix:

1. **Dev:** Apply the file change on `develop_dab` (in dbt Cloud web IDE), build + verify in `soundstripe_dev`.
2. **PR:** `develop_dab` → `main`. Use the per-fix `notes.md` for the PR body.
3. **Merge:** Once CI passes.
4. **QA against `soundstripe_prod`:**
   - Fix 1: re-run `analysis/adhoc/2026-05-05-enterprise-reporting-comparison/console.sql` q03 (Looker MQL YTD); should drop from 758 to ~470.
   - Fix 2: re-run `console.sql` q05 (Looker Apr-2026 deals); should drop from 155 to ~131.

Bundling into a single PR is fine; they touch independent files. If sequenced, do fix 1 first (lower risk).
