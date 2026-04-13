-- =============================================================================
-- Q3a: URL Inspection — Submitted Form with Empty/Blank Context
-- Author: d7admin
-- Date: 2026-04-07
-- Purpose: Determine which Submitted Form events with empty context are
--          enterprise form submissions by inspecting their URLs.
-- Dependencies: pc_stitch_db.mixpanel.export
-- =============================================================================

WITH date_bounds AS (
    SELECT
        DATEADD('week', -9, DATE_TRUNC('week', CURRENT_DATE())) AS window_start
        ,DATE_TRUNC('week', CURRENT_DATE())                      AS window_end
)

SELECT
    DATE_TRUNC('week', e.time::timestamp)                                          AS iso_week
    ,PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):host::STRING  AS host
    ,PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::STRING  AS path
    ,e.context
    ,COUNT(*)                                                                       AS event_count
FROM pc_stitch_db.mixpanel.export e
    CROSS JOIN date_bounds d
WHERE 1=1
    AND e.time::timestamp >= d.window_start
    AND e.time::timestamp <  d.window_end
    AND e.event = 'Submitted Form'
    AND (e.context IS NULL OR TRIM(e.context) = '' OR e.context = 'null')
GROUP BY 1, 2, 3, 4
ORDER BY 1, 5 DESC
;

-- =============================================================================
-- Q3b: URL Inspection — CTA Form Submitted Events
-- Purpose: Inspect URLs and context values for the new CTA Form Submitted
--          events to determine if any represent enterprise MQL submissions.
-- =============================================================================

WITH date_bounds AS (
    SELECT
        DATEADD('week', -9, DATE_TRUNC('week', CURRENT_DATE())) AS window_start
        ,DATE_TRUNC('week', CURRENT_DATE())                      AS window_end
)

SELECT
    DATE_TRUNC('week', e.time::timestamp)                                          AS iso_week
    ,PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):host::STRING  AS host
    ,PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::STRING  AS path
    ,e.context
    ,COUNT(*)                                                                       AS event_count
FROM pc_stitch_db.mixpanel.export e
    CROSS JOIN date_bounds d
WHERE 1=1
    AND e.time::timestamp >= d.window_start
    AND e.time::timestamp <  d.window_end
    AND e.event = 'CTA Form Submitted'
GROUP BY 1, 2, 3, 4
ORDER BY 1, 5 DESC
;

-- =============================================================================
-- Q3c: Submitted Form with context = 'Enterprise Contact Form' — URL Check
-- Purpose: Verify these ARE being captured by pipeline (lower() match).
--          Also inspect URLs to confirm they're on enterprise pages.
-- =============================================================================

WITH date_bounds AS (
    SELECT
        DATEADD('week', -9, DATE_TRUNC('week', CURRENT_DATE())) AS window_start
        ,DATE_TRUNC('week', CURRENT_DATE())                      AS window_end
)

SELECT
    DATE_TRUNC('week', e.time::timestamp)                                          AS iso_week
    ,PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):host::STRING  AS host
    ,PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::STRING  AS path
    ,e.context
    ,COUNT(*)                                                                       AS event_count
FROM pc_stitch_db.mixpanel.export e
    CROSS JOIN date_bounds d
WHERE 1=1
    AND e.time::timestamp >= d.window_start
    AND e.time::timestamp <  d.window_end
    AND e.event = 'Submitted Form'
    AND LOWER(e.context) = 'enterprise contact form'
GROUP BY 1, 2, 3, 4
ORDER BY 1, 5 DESC
;
