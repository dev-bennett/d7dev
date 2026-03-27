# Backfill Runbook: Reference Track Search Columns in fct_events

## Why a backfill is needed

`fct_events` is incremental with `unique_key = '__sdc_primary_key'` and a 1-day lookback. Reference Track Search events have been landing since 2026-02-18, but the new columns (spotify_track_id, ref_track_results_count, etc.) weren't selected. Those rows exist in the production table with NULLs where the new data should be.

A normal incremental run only reprocesses the last day. We need to reprocess from 2026-02-18 forward so the merge updates those rows with the new column values.

## Prerequisites

- [ ] fct_events changes committed to `develop_dab` branch in dbt-transformations
- [ ] Tested in dev target (`dbt run --select fct_events --target dev`)
- [ ] PR merged to main
- [ ] `on_schema_change='sync_all_columns'` is set (already in config)

## Workflow

### Phase 1: Develop and test (in `develop_dab`)

```bash
git checkout develop_dab
# Apply the fct_events.sql changes (new columns + backfill_from var)
dbt run --select fct_events --target dev
```

This builds a fresh table in your dev schema — not incremental against prod.
Use this to confirm the SQL compiles and the new columns appear correctly.
The backfill_from var is irrelevant here since dev builds from scratch.

### Phase 2: Merge to main

Open PR from `develop_dab` to `main`, review, merge.

### Phase 3: Backfill production (from main)

```bash
git checkout main
git pull
dbt run --select fct_events --vars '{"backfill_from": "2026-02-17"}'
```

This single command does everything:
- `sync_all_columns` adds the new columns to the prod table (ALTER TABLE)
- `backfill_from` overrides the 1-day lookback to reprocess from 2026-02-17
- The MERGE on `__sdc_primary_key` updates existing rows in place
- New columns get populated; all other columns remain unchanged
- Rows before 2026-02-17 keep NULLs (correct — feature didn't exist)

Using 2026-02-17 (one day before first event on 2026-02-18) to ensure the full window is captured.

**Expected duration:** ~5 weeks of data at current event rates. Significantly faster than a full refresh.

### Phase 4: Verify

Run the validation queries from `validation.sql` against the production schema:

```sql
-- Quick check: do Reference Track Search events have non-null new columns?
SELECT event, COUNT(*), COUNT(spotify_track_id), COUNT(ref_track_results_count)
FROM core.fct_events
WHERE event = 'Executed Reference Track Search'
GROUP BY 1;
```

Expected: `COUNT(spotify_track_id)` and `COUNT(ref_track_results_count)` should be close to `COUNT(*)`.

### Phase 5: Confirm downstream models

The downstream incremental models (`fct_sessions_build`, `fct_sessions_product_engagement_build`) don't need changes yet — they don't reference the new columns. But if you later add session-level metrics for reference track search, you'd backfill those the same way.

## What NOT to do

- **Don't use `--full-refresh`** unless absolutely necessary. It drops and rebuilds the entire fct_events table from scratch, which is expensive and forces downstream models to rebuild too.
- **Don't delete rows manually** from the target table. The MERGE handles updates in place.
- **Don't run the backfill from a feature branch.** The backfill targets the production incremental table and must run from main after merge.

## The `backfill_from` var

Leave it in the model permanently. It's reusable for future backfills — it only activates when explicitly passed via `--vars` and has no effect on normal runs.

## Rollback

The backfill only updates existing rows (via MERGE on primary key). No rows are deleted. A normal incremental run without the var resumes standard 1-day lookback behavior. The new columns will just have NULLs for the backfill window if you need to re-run.
