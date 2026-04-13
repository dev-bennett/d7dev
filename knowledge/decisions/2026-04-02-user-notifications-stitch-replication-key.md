# Stitch Replication Key: user_notifications

- **Date:** 2026-04-02
- **Status:** Pending
- **Author:** d7admin

## Context

The `user_notifications` table in Stitch (Soundstripe integration) uses key-based incremental replication with `id` as the replication key. This means Stitch only extracts rows where `id` is greater than the last synced value. Once a notification row is inserted and synced, Stitch never revisits it.

When a user reads a notification, the app updates the existing row: `read_at` and `updated_at` are set. Because Stitch never re-extracts the row, these updates are not replicated to Snowflake. The result is that `read_at` is NULL for virtually all automated and targeted notifications delivered after Stitch's initial sync (approximately November 2025).

Generic notifications are unaffected because they are read almost immediately after creation -- `read_at` is already populated when Stitch first sees the row.

## Evidence

- Pre-Nov 2025 automated read rate: 13.68%. Post-Nov: 0.01%.
- Pre-Nov 2025 targeted read rate: 11.41%. Post-Nov: 0.00%.
- Generic read rate stable at ~98% across both periods.
- Raw source tables confirm the same pattern (not a dbt transform issue).
- The ~59 post-Nov reads that do exist were likely synced in the same Stitch batch as the original insert.
- QF sample shows the app correctly writes `read_at` and `updated_at` on read events.

## Decision

Change the replication key for `user_notifications` from `id` to `updated_at`.

## Rationale

- `updated_at` advances whenever the row changes (read, or any other update)
- Stitch will re-extract rows where `updated_at > last_bookmark`, capturing `read_at` updates
- `id` is monotonically increasing and only captures inserts -- it cannot detect updates

## Action Required

1. In Stitch UI: Soundstripe integration → `user_notifications` → change replication key from `id` to `updated_at`
2. Reset the replication bookmark to trigger a historical re-sync (backfills missed `read_at` values for Nov 2025+ rows)
3. After re-sync completes, validate with:
   ```sql
   SELECT
       DATE_TRUNC('month', created_at)::DATE AS delivery_month
       , ROUND(100.0 * SUM(CASE WHEN read_at IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS read_rate_pct
   FROM pc_stitch_db.soundstripe.user_notifications
   WHERE cms_entry_id IN (
           SELECT id FROM pc_stitch_db.soundstripe.cms_entries
           WHERE content_type_id = 12
       )
   GROUP BY 1
   ORDER BY 1;
   ```
   Post-Nov months should show non-trivial read rates after backfill.

## Consequences

- Stitch extraction volume will increase: every read event causes `updated_at` to advance, so the row will be re-extracted on the next sync
- This is the correct behavior -- we need these updates
- Same replication key issue may apply to other Soundstripe tables where rows are updated after creation (cms_entries, cms_field_values) -- worth auditing

## Related

- Diagnostic queries: `etl/tasks/2026-04-02-in-app-notifications-build-out/exploration/read_rate_diagnostic/`
- Notification pipeline: `etl/tasks/2026-04-02-in-app-notifications-build-out/`
