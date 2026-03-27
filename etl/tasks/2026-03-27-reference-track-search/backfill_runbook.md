# Backfill Runbook: Reference Track Search Columns in fct_events

## Why a backfill is needed

`fct_events` is incremental with `unique_key = '__sdc_primary_key'` and a 1-day lookback. Reference Track Search events have been landing since 2026-02-18, but the new columns (spotify_track_id, ref_track_results_count, etc.) weren't selected. Those rows exist in the table with NULLs where the new data should be.

A normal incremental run only reprocesses the last day. We need to reprocess from 2026-02-18 forward so the merge updates those rows with the new column values.

## Prerequisites

- [ ] Modified `fct_events.sql` is deployed (includes new columns + `backfill_from` var)
- [ ] `on_schema_change='sync_all_columns'` is set (it is — already in config)
- [ ] Confirm the `backfill_from` var is in the incremental block:

```sql
{% if is_incremental() %}
    {% if var('backfill_from', none) is not none %}
        and event_ts >= '{{ var("backfill_from") }}'::timestamp
    {% else %}
        and event_ts >= (select dateadd('days', -1, ...) from {{ this }} )
    {% endif %}
{% endif %}
```

## Execution steps

### Step 1: Deploy the model change (normal incremental run)

```bash
dbt run --select fct_events
```

This does two things:
- `sync_all_columns` adds the new columns to the target table (ALTER TABLE)
- Processes the last day of events with the new columns populated

After this, new events going forward will have the columns populated. But events from 2026-02-18 through yesterday still have NULLs.

### Step 2: Backfill from feature launch date

```bash
dbt run --select fct_events --vars '{"backfill_from": "2026-02-17"}'
```

Using 2026-02-17 (one day before first event) to ensure the full window is captured.

**What this does:**
- Reprocesses all events from 2026-02-17 forward
- The MERGE on `__sdc_primary_key` updates existing rows in place
- New columns get populated; all other columns remain unchanged
- Rows before 2026-02-17 keep NULLs (correct — feature didn't exist)

**Expected duration:** Depends on event volume. ~5 weeks of data at current rates (~100k+ events). Should be significantly faster than a full refresh.

### Step 3: Verify

Run the validation queries from `validation.sql` against the production schema:

```sql
-- Quick check: do Reference Track Search events have non-null new columns?
SELECT event, COUNT(*), COUNT(spotify_track_id), COUNT(ref_track_results_count)
FROM core.fct_events
WHERE event = 'Executed Reference Track Search'
GROUP BY 1;
```

Expected: `COUNT(spotify_track_id)` and `COUNT(ref_track_results_count)` should be close to `COUNT(*)`.

### Step 4: Verify downstream models rebuild correctly

The downstream incremental models (`fct_sessions_build`, `fct_sessions_product_engagement_build`) don't need changes yet — they don't reference the new columns. But if you later add session-level metrics for reference track search, you'd backfill those the same way.

## What NOT to do

- **Don't use `--full-refresh`** unless absolutely necessary. It drops and rebuilds the entire fct_events table from scratch, which is expensive and forces downstream models to rebuild too.
- **Don't delete rows manually** from the target table. The MERGE handles updates in place.
- **Don't forget to remove or keep the `backfill_from` var.** It's designed to be reusable — leave it in the model for future backfills. It only activates when explicitly passed via `--vars`.

## Rollback

If something goes wrong, the backfill only updates existing rows (via MERGE on primary key). No rows are deleted. A normal incremental run without the var will resume standard 1-day lookback behavior. The new columns will just have NULLs for the backfill window if you need to re-run.
