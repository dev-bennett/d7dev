-- PURPOSE:       Row count, date range, and primary-key null rate for a table. Run before writing queries against an unfamiliar table.
-- TABLES:        <any>
-- PARAMETERS:    :schema (e.g. 'CORE'), :table (e.g. 'FCT_EVENTS'), :pk_column (e.g. '__sdc_primary_key'), :ts_column (e.g. 'event_ts')
-- PRIOR USES:    Pre-flight pattern — generalized from schema_check/ subdirectories across etl/tasks/ (multiple)
-- RATE BLOCK:    n/a (diagnostic, not analytical)
-- LAST UPDATED:  2026-04-24

-- Fill in :schema, :table, :pk_column, :ts_column before running.
-- Keep under LIMIT 100 even though the result is a single row by construction.

SELECT
    COUNT(*)                                                         AS row_count
  , SUM(IFF(:pk_column IS NULL, 1, 0))                               AS pk_null_count
  , SUM(IFF(:pk_column IS NULL, 1, 0)) / NULLIF(COUNT(*), 0)         AS pk_null_rate
  , MIN(:ts_column)                                                  AS min_ts
  , MAX(:ts_column)                                                  AS max_ts
  , DATEDIFF('day', MIN(:ts_column), MAX(:ts_column))                AS span_days
FROM soundstripe_prod.:schema.:table
WHERE :ts_column >= DATEADD('day', -90, CURRENT_DATE())
LIMIT 100;

-- Variant: unbounded full-table snapshot. Use only if you've confirmed the table is small (< 10M rows)
--   or you need the full history. Otherwise stick to the 90-day scope above.
