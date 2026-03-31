-- Searched Songs Properties: Post-Deploy Validation
-- Author: d7admin
-- Date: 2026-03-30
-- Purpose: Verify search_has_vocals, search_result_count, and is_supe_search
--          are correctly populated in fct_events after backfill.
-- Dependencies: core.fct_events

-- Query A: Verify new columns populated for Searched Songs events
SELECT
    search_has_vocals
    ,search_result_count
    ,is_supe_search
    ,COUNT(*) AS event_count
FROM core.fct_events
WHERE event = 'Searched Songs'
    AND event_ts::date >= '2026-03-26'
GROUP BY 1, 2, 3
ORDER BY 4 DESC
LIMIT 20;


-- Query B: No regression -- new columns should be NULL for non-Searched Songs events
-- Expect zero rows. If rows appear, investigate cross-event property leakage.
SELECT
    event
    ,COUNT(search_has_vocals) AS has_vocals_count
    ,COUNT(search_result_count) AS result_count_count
    ,COUNT(is_supe_search) AS supe_count
FROM core.fct_events
WHERE event != 'Searched Songs'
    AND event_ts::date >= '2026-03-26'
GROUP BY 1
HAVING COUNT(search_result_count) > 0
    OR COUNT(is_supe_search) > 0
ORDER BY 2 DESC
LIMIT 10;


-- Query C: Value distribution and sanity check
-- search_has_vocals should only contain "All", "Vocals", "Instrumental", or NULL
-- search_result_count should be non-negative integers
-- is_supe_search should be true/false/NULL
SELECT
    search_has_vocals
    ,COUNT(*) AS events
    ,AVG(search_result_count) AS avg_results
    ,MIN(search_result_count) AS min_results
    ,MAX(search_result_count) AS max_results
    ,SUM(CASE WHEN is_supe_search = TRUE THEN 1 ELSE 0 END) AS supe_searches
    ,SUM(CASE WHEN is_supe_search = FALSE THEN 1 ELSE 0 END) AS non_supe_searches
    ,SUM(CASE WHEN is_supe_search IS NULL THEN 1 ELSE 0 END) AS null_supe
FROM core.fct_events
WHERE event = 'Searched Songs'
    AND event_ts::date >= '2026-03-26'
GROUP BY 1
ORDER BY 2 DESC;


-- Query D: Daily volume trend -- confirm no gaps or anomalies
SELECT
    event_ts::date AS event_date
    ,COUNT(*) AS total_searched_songs
    ,COUNT(search_has_vocals) AS has_vocals_populated
    ,COUNT(search_result_count) AS result_count_populated
    ,COUNT(is_supe_search) AS supe_populated
    ,ROUND(has_vocals_populated / NULLIF(total_searched_songs, 0) * 100, 1) AS pct_has_vocals
    ,ROUND(result_count_populated / NULLIF(total_searched_songs, 0) * 100, 1) AS pct_result_count
    ,ROUND(supe_populated / NULLIF(total_searched_songs, 0) * 100, 1) AS pct_supe
FROM core.fct_events
WHERE event = 'Searched Songs'
    AND event_ts::date >= '2026-03-26'
GROUP BY 1
ORDER BY 1;
