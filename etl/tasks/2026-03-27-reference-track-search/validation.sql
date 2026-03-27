-- =============================================================================
-- Reference Track Search: Post-Deploy Validation
-- Purpose: Confirm new columns are populated correctly after backfill
-- Author: d7admin
-- Date: 2026-03-27
-- Dependencies: core.fct_events (after model change + backfill)
-- =============================================================================

-- QUERY A: Verify new columns are populated for Reference Track Search events
-- Expected: non-zero counts for the relevant properties per event type
SELECT
    event
    ,COUNT(*) AS total_events
    ,COUNT(spotify_track_id) AS has_spotify_track_id
    ,COUNT(spotify_id) AS has_spotify_id
    ,COUNT(ref_track_results_count) AS has_results_count
    ,COUNT(ref_track_title) AS has_track_title
    ,COUNT(ref_track_error_message) AS has_error_message
    ,COUNT(ref_track_signup_trigger) AS has_trigger
    ,COUNT(search_type) AS has_search_type
FROM core.fct_events
WHERE event IN (
    'Executed Reference Track Search'
    ,'Reference Track Search Sign Up Modal Opened'
    ,'Reference Track Search Error'
    ,'Reference Track Search Closed'
    ,'Executed Agent Search'
)
GROUP BY 1
ORDER BY 1;


-- QUERY B: Verify no regression -- new columns should be NULL for non-RTS events
-- Expected: 0 rows (no unrelated events should have these properties populated)
SELECT
    event
    ,COUNT(*) AS total
FROM core.fct_events
WHERE event NOT IN (
    'Executed Reference Track Search'
    ,'Reference Track Search Sign Up Modal Opened'
    ,'Reference Track Search Error'
    ,'Reference Track Search Closed'
    ,'Executed Agent Search'
)
    AND (
        spotify_track_id IS NOT NULL
        OR ref_track_results_count IS NOT NULL
        OR ref_track_error_message IS NOT NULL
        OR ref_track_signup_trigger IS NOT NULL
    )
GROUP BY 1
ORDER BY 2 DESC;


-- QUERY C: Daily volume check -- confirm events are flowing at expected rates
SELECT
    event
    ,event_ts::date AS event_date
    ,COUNT(*) AS daily_count
FROM core.fct_events
WHERE event IN (
    'Executed Reference Track Search'
    ,'Reference Track Search Sign Up Modal Opened'
    ,'Reference Track Search Error'
    ,'Reference Track Search Closed'
)
    AND event_ts::date >= '2026-03-01'
GROUP BY 1, 2
ORDER BY 1, 2;


-- QUERY D: Spot-check sample rows for data quality
-- Verify: spotify_track_id is 22-char alphanumeric, results_count matches results array length
SELECT
    event_ts
    ,event
    ,spotify_track_id
    ,LENGTH(spotify_track_id) AS spotify_id_length
    ,ref_track_results_count
    ,ref_track_title
    ,ref_track_error_message
    ,ref_track_signup_trigger
    ,search_type
FROM core.fct_events
WHERE event IN (
    'Executed Reference Track Search'
    ,'Reference Track Search Error'
    ,'Reference Track Search Sign Up Modal Opened'
)
ORDER BY event_ts DESC
LIMIT 10;
