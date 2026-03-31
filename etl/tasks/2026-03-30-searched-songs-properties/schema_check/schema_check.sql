-- Searched Songs Properties: Stitch Schema Verification
-- Author: d7admin
-- Date: 2026-03-30
-- Purpose: Verify Has Vocals, Result Count, and Supe columns exist and are populating
--          in the Stitch Mixpanel export after engineering's Searched Songs PR.
-- Dependencies: pc_stitch_db.mixpanel.export

-- Query A: Verify columns exist and check data types
SELECT
    column_name
    ,data_type
    ,is_nullable
FROM pc_stitch_db.information_schema.columns
WHERE table_schema = 'MIXPANEL'
    AND table_name = 'EXPORT'
    AND column_name IN ('HAS_VOCALS', 'RESULT_COUNT', 'SUPE')
ORDER BY column_name;


-- Query B: Sample Searched Songs events with new properties (last 7 days)
SELECT
    event
    ,time::date AS event_date
    ,HAS_VOCALS
    ,RESULT_COUNT
    ,SUPE
FROM pc_stitch_db.mixpanel.export
WHERE event = 'Searched Songs'
    AND time::date >= DATEADD('days', -7, CURRENT_DATE)
    AND (RESULT_COUNT IS NOT NULL OR SUPE IS NOT NULL)
LIMIT 20;


-- Query C: Daily population rates since go-live
SELECT
    time::date AS event_date
    ,COUNT(*) AS total_searched_songs
    ,COUNT(HAS_VOCALS) AS has_has_vocals
    ,COUNT(RESULT_COUNT) AS has_result_count
    ,COUNT(SUPE) AS has_supe
    ,ROUND(has_result_count / NULLIF(total_searched_songs, 0) * 100, 1) AS pct_result_count
    ,ROUND(has_supe / NULLIF(total_searched_songs, 0) * 100, 1) AS pct_supe
FROM pc_stitch_db.mixpanel.export
WHERE event = 'Searched Songs'
    AND time::date >= '2026-03-26'
GROUP BY 1
ORDER BY 1;


-- Query D: HAS_VOCALS value distribution (check for array vs scalar format)
-- Older events may have array-style values like '["Vocals"]'; new events should have scalar "Vocals"
SELECT
    HAS_VOCALS
    ,COUNT(*) AS cnt
    ,MIN(time::date) AS earliest
    ,MAX(time::date) AS latest
FROM pc_stitch_db.mixpanel.export
WHERE event = 'Searched Songs'
    AND HAS_VOCALS IS NOT NULL
    AND time::date >= '2026-03-01'
GROUP BY 1
ORDER BY 2 DESC
LIMIT 20;
