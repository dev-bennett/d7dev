-- Investigate: Stitch duplicate rows in user_notifications
-- Author: d7admin
-- Date: 2026-04-02


--qa  Are there duplicate IDs in the raw source?
SELECT
    COUNT(*) AS total_rows
    , COUNT(DISTINCT id) AS distinct_ids
    , COUNT(*) - COUNT(DISTINCT id) AS duplicate_rows
FROM pc_stitch_db.soundstripe.user_notifications
;


--qb  Sample duplicates: show both versions of a row
SELECT *
FROM pc_stitch_db.soundstripe.user_notifications
WHERE id IN (
    SELECT id
    FROM pc_stitch_db.soundstripe.user_notifications
    GROUP BY id
    HAVING COUNT(*) > 1
)
ORDER BY id, _sdc_received_at
LIMIT 20
;


--qc  For duplicates: does one version have read_at and the other not?
SELECT
    id
    , COUNT(*) AS row_count
    , SUM(CASE WHEN read_at IS NOT NULL THEN 1 ELSE 0 END) AS versions_with_read
    , SUM(CASE WHEN read_at IS NULL THEN 1 ELSE 0 END) AS versions_without_read
    , MIN(_sdc_received_at) AS first_synced
    , MAX(_sdc_received_at) AS last_synced
FROM pc_stitch_db.soundstripe.user_notifications
GROUP BY id
HAVING COUNT(*) > 1
LIMIT 20
;


--qd  What warehouse/role does dbt use vs your current session?
SELECT
    CURRENT_WAREHOUSE() AS current_warehouse
    , CURRENT_ROLE() AS current_role
    , CURRENT_DATABASE() AS current_database
    , CURRENT_SCHEMA() AS current_schema
;
