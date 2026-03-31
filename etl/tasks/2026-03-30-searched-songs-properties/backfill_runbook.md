# Backfill Runbook: Searched Songs Properties

- **Date:** 2026-03-30
- **Model:** fct_events (marts/core)
- **New columns:** search_has_vocals, search_result_count, is_supe_search
- **Backfill from:** 2026-03-25 (one day before go-live)

## Prerequisites

1. Schema check queries in `schema_check/schema_check.sql` confirm:
   - All three columns exist in `pc_stitch_db.mixpanel.export`
   - Data is populating for Searched Songs events since 2026-03-26
2. Draft `fct_events.sql` reviewed and promoted to dbt repo

## Execution

### Step 1: Run backfill

fct_events uses `sync_all_columns`, so the new columns will be added via ALTER TABLE automatically. The `backfill_from` variable overrides the default 1-day incremental lookback.

```bash
dbt run --select fct_events --vars '{"backfill_from": "2026-03-25"}'
```

This reprocesses ~5 days of data. The MERGE on `__sdc_primary_key` updates existing rows in place with the new column values.

### Step 2: Validate

Run the validation queries in `validation/validation.sql`:
- Query A: Verify new columns populated for Searched Songs events
- Query B: Verify no regression (columns NULL for unrelated events)
- Query C: Value distribution sanity check

### Step 3: Verify downstream

Check that downstream models are not broken:
- `dim_mixpanel_feature_events` -- already uses HAS_VOCALS in filter_json, should be unaffected
- `fct_sessions_build` -- no new dependencies yet (future scope)

## Rollback

If issues arise, the new columns can be dropped:

```sql
ALTER TABLE analytics.core.fct_events DROP COLUMN search_has_vocals;
ALTER TABLE analytics.core.fct_events DROP COLUMN search_result_count;
ALTER TABLE analytics.core.fct_events DROP COLUMN is_supe_search;
```

Then revert the fct_events.sql change in the dbt repo.
