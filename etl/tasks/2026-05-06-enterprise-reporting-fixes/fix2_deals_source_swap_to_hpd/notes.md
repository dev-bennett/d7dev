# Fix 2 Notes — Deals Source Swap to HPD

## What changes

Replace `models/staging/hubspot/stg_deals.sql` so it reads from `hubspot_platform_data.v2_daily.objects_deals` instead of `{{ source('crm', 'deals') }}` (Stitch ETL of `pc_stitch_db.hubspot_new.deals`).

This is **not** a 1-line source swap. The two sources have fundamentally different schemas:

| Aspect | Stitch (current) | HPD (new) |
|---|---|---|
| Row count behavior | Retains ghost records when HubSpot soft-deletes/archives a deal (Stitch tap doesn't catch these reliably) | Ghost records absent — HubSpot's authoritative share excludes deletions |
| Property access | `properties:dealname:value::varchar` (JSON parsing) | `PROPERTY_DEALNAME` (flat column, already typed) |
| Column count | 4 base + JSON blob | 894 flat columns |
| Property history | `properties_versions` ARRAY on each row (LATERAL FLATTEN downstream) | Separate table `OBJECT_PROPERTIES_HISTORY` (888M rows, filterable to objecttypeid='0-3') |
| Company association | `associations:associatedCompanyIds[0]` (first element of array) | Separate join: `ASSOCIATIONS_DEALS_TO_COMPANIES` with `ISMAINASSOCIATIONDEFINITION` flag |
| Soft-delete flag | `isdeleted` column (unreliable) | None — deletions absent from the table |

## Why

Variance 5 from the 2026-05-05 reconciliation: 24 ghost deals in April 2026 (Columbia University, North Carolina Zoo, Cloud Software Group, etc.) make Looker over-count by 18% (155 vs 131). Lifetime gap: 345 ghost deals. HPD is HubSpot's authoritative source and doesn't have this problem.

## Expected impact

| Metric | Before | After |
|---|---|---|
| Looker April-2026 deals tile (variance 5) | 155 | ~131 |
| `dim_enterprise_deals` lifetime row count | full Stitch history | -345 (ghost-record cleanup) |
| Column types | mostly TEXT (JSON parse output) | mostly properly-typed (NUMBER, TIMESTAMP_NTZ, DATE) — small downstream casting work may apply |

## Downstream impact (READ THIS BEFORE MERGING)

### `stg_deals_event_log.sql` — must be rewritten in this PR

Current implementation:

```sql
from {{ ref("stg_deals") }}, lateral flatten(properties_versions)
```

This consumes the `properties_versions` ARRAY that the new `stg_deals` no longer emits. The model breaks on merge.

**Recommended replacement:**

```sql
-- New stg_deals_event_log.sql sourcing from HPD's object-properties-history layer
{{ config(materialized='view') }}

select
     objectid::string                                  as dealid
    ,name                                              as property_name
    ,value                                             as property_value
    ,timestamp                                         as property_changed_at
    ,source_type                                       as change_source_type
    ,source_id                                         as change_source_id
from hubspot_platform_data.v2_daily.object_properties_history
where objecttypeid = '0-3'  -- deals
```

(Verify column names against HPD's `OBJECT_PROPERTIES_HISTORY` schema — those above are the standard HubSpot data-share shape; small renames possible.)

This is a separate file change; include it in the same PR so CI catches the breakage immediately if the downstream consumer's column expectations differ.

### Other downstream consumers

Before merging, check what else consumes `stg_deals.properties` or `stg_deals.properties_versions`:

```bash
grep -rn "properties_versions\|stg_deals\.properties[^_]" context/dbt/models/
```

The two known consumers as of 2026-05-06 are `stg_deals_event_log` (above) and the `stg_deals` model itself (which won't have this issue post-fix). If grep surfaces others, plan for them.

## Open considerations

### `hs_date_entered_1796976` reference in HEAD

The current `stg_deals.sql` uses `coalesce(properties:hs_date_entered_1796976:value, properties:hs_date_entered_8070190:value)` for `demo_completed_date`. HPD's column inventory has `PROPERTY_HS_V2_DATE_ENTERED_8070190` but no `_1796976` variant. The 1796976 stage-id may be obsolete (legacy pipeline) or it may have been renamed in HPD. Three options:

1. **Drop the coalesce, use 8070190 only** (current draft choice) — assumes 1796976 is legacy and no live rows depend on it.
2. **Search OBJECT_PROPERTIES_HISTORY** for any historical use of property_name='hs_date_entered_1796976' to confirm it's truly obsolete before dropping.
3. **Add a coalesce fallback** to a different HPD column if the search finds an active rename.

Path 2 is the conservative choice; 1 is the YAGNI choice.

### `stage_entered_ts` semantics narrowing

Stitch's `properties:dealstage:timestamp` returned the timestamp the CURRENT stage was entered (at row update time). HPD's `PROPERTY_HS_V2_DATE_ENTERED_CURRENT_STAGE` is the closest equivalent and the draft uses it. Verify any downstream model that reads `stg_deals.stage_entered_ts` and reasons about historical stage transitions — it was probably already only the current stage anyway, but worth a once-over.

### Source declaration in dbt

The draft uses a direct table reference (`hubspot_platform_data.v2_daily.objects_deals`). For long-term cleanliness, add a dbt source `hubspot_platform_data` in `_sources/_sources_hubspot_platform_data.yml` listing `objects_deals`, `associations_deals_to_companies`, `object_properties_history`, and `list_memberships` (the last one needed for Fix 1). Then change the draft's `from` clause to `{{ source('hubspot_platform_data', 'objects_deals') }}`.

## Verification

Dev (after `dbt run --select stg_deals --full-refresh`):

```sql
-- Spot-check that ghost deals are gone
SELECT COUNT(*)
FROM soundstripe_dev.staging.stg_deals
WHERE dealid IN (
    -- The 24 April-2026 ghost dealids from findings.md §Variance 5:
    '58637753513','58862785806','58867113020','58879287417','58894151011',
    '59078156835','59102434125','59122920248','59164291435','59164555896',
    '59179036166','59183719472','59231558944','59244713508','59320251754',
    '59366526851','59366720678','59394385208','59417817610','59435921280',
    '59678845368','59775224492','59814943088','59850186000'
);
-- Expect 0 (all 24 deleted-in-HubSpot ghost deals absent from HPD)

-- Active deals still present
SELECT COUNT(*)
FROM soundstripe_dev.staging.stg_deals
WHERE createdate >= '2026-04-01' AND createdate < '2026-05-01';
-- Expect ~131 (matching HubSpot's UI tile)
```

Then `dbt run --select +dim_enterprise_deals` to rebuild downstream and re-run `analysis/adhoc/2026-05-05-enterprise-reporting-comparison/console.sql` q05:

```sql
SELECT SUM(deals_created)
FROM soundstripe_dev.core.fct_kpis_enterprise
WHERE event_month = '2026-04-01';
-- Expect ~131 (was 155)
```

Prod: same checks against `soundstripe_prod` after merge.

## Risk

- **Medium-high.** This change touches a foundational staging model with multiple downstream consumers. The properties_versions removal is a breaking change for `stg_deals_event_log.sql`.
- **Mitigation:** Bundle the `stg_deals_event_log.sql` rewrite in the same PR. Run `dbt build --select +stg_deals` in dev to surface any other downstream breakage before opening the PR.
- **Rollback path:** Revert the PR. Stitch's `pc_stitch_db.hubspot_new.deals` keeps updating regardless, so reverting restores the prior (with-ghosts) source state without data loss.
