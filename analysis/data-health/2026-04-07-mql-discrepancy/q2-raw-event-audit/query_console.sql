-- =============================================================================
-- Q2a: Raw Mixpanel Event Taxonomy — Enterprise-Related Events
-- Author: d7admin
-- Date: 2026-04-07
-- Purpose: Surface the full set of event names and context values related to
--          enterprise form tracking over the past 9 completed ISO weeks.
--          Identify new/changed event patterns the pipeline may not capture.
-- Dependencies: pc_stitch_db.mixpanel.export
-- =============================================================================

WITH date_bounds AS (
    SELECT
        DATEADD('week', -9, DATE_TRUNC('week', CURRENT_DATE())) AS window_start
        ,DATE_TRUNC('week', CURRENT_DATE())                      AS window_end
)

SELECT
    DATE_TRUNC('week', e.time::timestamp) AS iso_week
    ,e.event
    ,e.context
    ,COUNT(*)                         AS event_count
FROM pc_stitch_db.mixpanel.export e
    CROSS JOIN date_bounds d
WHERE 1=1
    AND e.time::timestamp >= d.window_start
    AND e.time::timestamp <  d.window_end
    AND (
        -- Known MQL events
        (e.event = 'Submitted Form' AND LOWER(e.context) LIKE '%enterprise%')
        OR (e.event ILIKE '%enterprise%')
        OR (e.event = 'Clicked Element' AND e.context ILIKE '%enterprise%')
        -- Broad net: any form submission event (to catch renamed events)
        OR (e.event ILIKE '%submitted%form%')
        OR (e.event ILIKE '%form%submit%')
    )
GROUP BY 1, 2, 3
ORDER BY 1, 4 DESC
;

-- =============================================================================
-- Q2b: Event + Context Pairs — Pre-Divergence vs Current
-- Purpose: Compare distinct (event, context) combinations between the first 3
--          weeks of the window (pre-divergence baseline) and the last 3 weeks
--          (current period) to surface new or disappeared patterns.
-- =============================================================================

WITH date_bounds AS (
    SELECT
        DATEADD('week', -9, DATE_TRUNC('week', CURRENT_DATE())) AS window_start
        ,DATEADD('week', -6, DATE_TRUNC('week', CURRENT_DATE())) AS baseline_end
        ,DATEADD('week', -3, DATE_TRUNC('week', CURRENT_DATE())) AS current_start
        ,DATE_TRUNC('week', CURRENT_DATE())                       AS window_end
)

,baseline AS (
    SELECT DISTINCT
        e.event
        ,e.context
        ,'baseline' AS period
    FROM pc_stitch_db.mixpanel.export e
        CROSS JOIN date_bounds d
    WHERE 1=1
        AND e.time::timestamp >= d.window_start
        AND e.time::timestamp <  d.baseline_end
        AND (
            (e.event = 'Submitted Form' AND LOWER(e.context) LIKE '%enterprise%')
            OR (e.event ILIKE '%enterprise%')
            OR (e.event = 'Clicked Element' AND e.context ILIKE '%enterprise%')
            OR (e.event ILIKE '%submitted%form%')
            OR (e.event ILIKE '%form%submit%')
        )
)

,current_period AS (
    SELECT DISTINCT
        e.event
        ,e.context
        ,'current' AS period
    FROM pc_stitch_db.mixpanel.export e
        CROSS JOIN date_bounds d
    WHERE 1=1
        AND e.time::timestamp >= d.current_start
        AND e.time::timestamp <  d.window_end
        AND (
            (e.event = 'Submitted Form' AND LOWER(e.context) LIKE '%enterprise%')
            OR (e.event ILIKE '%enterprise%')
            OR (e.event = 'Clicked Element' AND e.context ILIKE '%enterprise%')
            OR (e.event ILIKE '%submitted%form%')
            OR (e.event ILIKE '%form%submit%')
        )
)

SELECT
    COALESCE(b.event, c.event)     AS event
    ,COALESCE(b.context, c.context) AS context
    ,CASE
        WHEN b.event IS NOT NULL AND c.event IS NOT NULL THEN 'both'
        WHEN b.event IS NOT NULL THEN 'baseline_only'
        ELSE 'current_only'
    END AS presence
FROM baseline b
    FULL OUTER JOIN current_period c
        ON b.event = c.event
        AND NVL(b.context, '__null__') = NVL(c.context, '__null__')
ORDER BY 3 DESC, 1, 2
;

-- =============================================================================
-- Q2c: URL Host Distribution for Enterprise Events
-- Purpose: Check if the domain consolidation (www/app -> soundstripe.com)
--          changed the host values in enterprise-related events.
-- =============================================================================

WITH date_bounds AS (
    SELECT
        DATEADD('week', -9, DATE_TRUNC('week', CURRENT_DATE())) AS window_start
        ,DATE_TRUNC('week', CURRENT_DATE())                      AS window_end
)

SELECT
    DATE_TRUNC('week', e.time::timestamp) AS iso_week
    ,PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):host::STRING AS host
    ,e.event
    ,COUNT(*)                         AS event_count
FROM pc_stitch_db.mixpanel.export e
    CROSS JOIN date_bounds d
WHERE 1=1
    AND e.time::timestamp >= d.window_start
    AND e.time::timestamp <  d.window_end
    AND (
        (e.event = 'Submitted Form' AND LOWER(e.context) LIKE '%enterprise%')
        OR (e.event ILIKE '%enterprise%')
        OR (e.event = 'Clicked Element' AND e.context ILIKE '%enterprise%')
    )
GROUP BY 1, 2, 3
ORDER BY 1, 4 DESC
;
