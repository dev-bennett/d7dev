-- PURPOSE:       Confirm columns exist (and their data types) in a target table before referencing them. Guards feedback_verify_before_writing.
-- TABLES:        soundstripe_prod.information_schema.columns
-- PARAMETERS:    :schema (e.g. 'CORE'), :table (e.g. 'FCT_EVENTS'), :columns (comma-separated quoted list, e.g. 'EVENT_TS', 'SESSION_ID')
-- PRIOR USES:    Pattern repeats in every investigation (WCPM audit, pricing-page scroll-depth, direct-traffic-spike, ...)
-- RATE BLOCK:    n/a
-- LAST UPDATED:  2026-04-24

-- Quick form: list all columns for a table
SELECT
    column_name
  , data_type
  , is_nullable
  , ordinal_position
FROM soundstripe_prod.information_schema.columns
WHERE table_schema = :schema
  AND table_name = :table
ORDER BY ordinal_position
LIMIT 200;

-- Targeted form: check whether specific columns exist. Replace :columns with a literal quoted IN list.
-- Any column name not returned does not exist on the table — do NOT reference it in a query.
-- SELECT
--     column_name
--   , data_type
-- FROM soundstripe_prod.information_schema.columns
-- WHERE table_schema = :schema
--   AND table_name = :table
--   AND column_name IN (:columns)
-- ORDER BY column_name;
