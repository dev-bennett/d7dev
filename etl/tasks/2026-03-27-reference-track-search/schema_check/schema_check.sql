-- =============================================================================
-- Reference Track Search: Stitch Schema Verification
-- Purpose: Confirm new Mixpanel event properties landed correctly in Snowflake
-- Author: d7admin
-- Date: 2026-03-27
-- Dependencies: pc_stitch_db.mixpanel.export
-- =============================================================================

-- QUERY A: Confirm events exist and check date range
-- Run this first to verify the feature is live and events are flowing
SELECT
    event
    ,COUNT(*) AS event_count
    ,MIN(time::timestamp) AS first_seen
    ,MAX(time::timestamp) AS last_seen
FROM pc_stitch_db.mixpanel.export
WHERE event IN (
    'Executed Reference Track Search'
    ,'Reference Track Search Sign Up Modal Opened'
    ,'Reference Track Search Error'
    ,'Reference Track Search Closed'
)
    AND time::date >= '2026-02-01'
GROUP BY 1
ORDER BY 1;


-- QUERY B: Discover exact column names for new properties
-- Stitch flattens Mixpanel event properties into top-level columns
-- Need to confirm naming convention and check for reserved word conflicts
SELECT
    column_name
    ,data_type
    ,is_nullable
FROM pc_stitch_db.information_schema.columns
WHERE table_schema = 'MIXPANEL'
    AND table_name = 'EXPORT'
    AND (
        column_name ILIKE '%spotify%'
        OR column_name ILIKE '%results_count%'
        OR column_name ILIKE '%track_title%'
        OR column_name ILIKE '%content_partners%'
        OR column_name ILIKE '%error_message%'
        OR column_name ILIKE '%trigger%'
        OR column_name ILIKE '%search_type%'
        OR column_name ILIKE '%input_value%'
    )
ORDER BY column_name;


-- QUERY C: Sample rows to verify data types and content
-- Especially important for content_partners (array) and results (array of objects)
SELECT
    event
    ,time::timestamp AS event_ts
    ,spotify_track_id           -- verify: STRING, 22-char alphanumeric
    ,spotify_id                 -- verify: separate column or same as spotify_track_id?
    ,results_count              -- verify: INTEGER
    ,track_title_display        -- verify: STRING, format "Artist - Title"
    ,content_partners           -- verify: VARIANT array e.g. ["soundstripe","wcpm"]
    ,results                    -- verify: VARIANT array of {Song ID, Score} objects
    ,error_message              -- verify: STRING
    ,"TRIGGER"                  -- verify: STRING ("URL Param" or "Form Submit") -- quoted: reserved word
    ,search_type                -- verify: STRING ("reference_track")
FROM pc_stitch_db.mixpanel.export
WHERE event IN (
    'Executed Reference Track Search'
    ,'Reference Track Search Sign Up Modal Opened'
    ,'Reference Track Search Error'
    ,'Reference Track Search Closed'
)
    AND time::date >= '2026-03-01'
ORDER BY time DESC
LIMIT 10;


-- QUERY D: Check Executed Agent Search for new optional properties
-- These are additions to a pre-existing event
SELECT
    search_type
    ,spotify_id
    ,COUNT(*) AS event_count
FROM pc_stitch_db.mixpanel.export
WHERE event = 'Executed Agent Search'
    AND time::date >= '2026-03-01'
    AND (search_type IS NOT NULL OR spotify_id IS NOT NULL)
GROUP BY 1, 2
ORDER BY 3 DESC
LIMIT 20;
