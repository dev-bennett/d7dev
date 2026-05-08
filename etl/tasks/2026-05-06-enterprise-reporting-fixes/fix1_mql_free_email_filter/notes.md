# Fix 1 Notes — MQL Free-Email Filter

## What changes

Add a `free_email_contacts` CTE at the top of `dim_mql_mapping.sql` that pulls all members of HubSpot list 4459 (`[MASTER] ALL Contacts w/ Free Email Domain List`, ~1.4M members) from `hubspot_platform_data.v2_daily.list_memberships`. Filter `forms_submitted_hubspot.CANONICAL_VID NOT IN (free_email_contacts)`.

Net effect: form submissions whose contact is a free-email-domain contact are dropped from the entire model — so they're not MQLs, not deal-attributable, not in any tier.

## Why

HubSpot's MQL view 19857810 (which Ryan's HubSpot tile uses) applies "list 4459 NOT IN" as filter 1. Looker's `dim_mql_mapping.mqls = COUNT(DISTINCT email)` doesn't apply that filter, so it counts free-email contacts that HubSpot intentionally excludes. From the 2026-05-05 reconciliation: 312 of 329 Looker-only MQLs (95%) at hubspot_uid grain were list-4459 members.

## Expected impact

| Metric | Before | After |
|---|---|---|
| `dim_mql_mapping` row count YTD-2026 | 727 (hubspot_uid grain; 758 at email grain) | ~470 |
| Looker MQL YTD tile | 758 | ~470 |
| Looker MQL deals YTD tile (variance 4) | 365 | ~337 (variance 3 propagation) |

## Source reference choice

The CTE references `hubspot_platform_data.v2_daily.list_memberships` directly rather than via `{{ source(...) }}`. Reason: there is no existing dbt source defined for `hubspot_platform_data` in the current `_sources/` configuration. Two options:

1. **Direct reference (used here):** simpler, immediate, no other repo changes needed. Bypasses dbt's source-graph layer for this one table.
2. **Add a dbt source:** create `_sources/_sources_hubspot_platform_data.yml` with a `hubspot_platform_data` source pointing at `v2_daily`, list `list_memberships` (and any other tables you'll consume from HPD long-term), then change the CTE to use `{{ source('hubspot_platform_data', 'list_memberships') }}`.

Recommend option 2 if Fix 2 lands in the same PR — it's about to add a second HPD-sourced model (`stg_deals`), so the source definition would pay back for both. If sequenced separately, option 1 is fine for Fix 1 alone.

## Coordination with `etl/tasks/2026-04-07-mql-discrepancy-fix/`

That task ALSO modifies `dim_mql_mapping.sql` for four coverage fixes (pricing-page event, base_url normalization, tier-2 window 300s, /api URL pattern). The two tasks are independent at the line level (this fix touches the `forms_submitted_hubspot` CTE; the MQL discrepancy fix touches `enterprise_url_patterns`, `form_events_mixpanel`, and `tier2_page_activity`).

Stacking order options:
- **Option A — bundle in one PR:** apply both sets of edits to a single working copy of `dim_mql_mapping.sql`, ship one PR. Lowest review overhead.
- **Option B — discrepancy fix first, then this on top:** apply the four coverage fixes, merge, then rebase this filter on the new HEAD.
- **Option C — this first, then discrepancy fix on top:** apply this filter, merge, then add the four coverage fixes on top.

All three result in the same final state. Option A is the most efficient if Devon is the only reviewer.

## Verification

Dev (after `dbt run --select dim_mql_mapping --full-refresh`):

```sql
-- Count drops from 727 hubspot_uid grain to ~470
SELECT COUNT(DISTINCT hubspot_uid) AS n
FROM soundstripe_dev.marketing.dim_mql_mapping
WHERE submission_ts >= '2026-01-01';

-- No remaining list-4459 members in the model
SELECT COUNT(*) AS leaked_free_email
FROM soundstripe_dev.marketing.dim_mql_mapping m
JOIN hubspot_platform_data.v2_daily.list_memberships lm
  ON TRY_CAST(m.hubspot_uid AS NUMBER) = lm.objectid
 AND lm.listid = 4459
WHERE m.submission_ts >= '2026-01-01';
-- Expect 0
```

Prod (after merge):
- Re-run `analysis/adhoc/2026-05-05-enterprise-reporting-comparison/console.sql` q03 against `soundstripe_prod.marketing.dim_mql_mapping`. Should drop from 758 → ~470.
- Re-run q04. Should drop from 365 → ~337.
- The HubSpot side (q07) should stay at 470 (no change, that side was already filtered).

## Risk

Low. Pure filter addition; no schema change, no column additions, no downstream column references broken. Worst case is the count drops too aggressively — debugging path is to check `hubspot_platform_data.v2_daily.list_memberships WHERE listid=4459` row count (~1.4M expected; if 0 or wildly different, the source itself is the issue).
