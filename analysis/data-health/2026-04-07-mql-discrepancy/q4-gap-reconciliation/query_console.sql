-- =============================================================================
-- Q4a: HubSpot MQL Volume by Form Name — Weekly
-- Author: d7admin
-- Date: 2026-04-07
-- Purpose: Check if HubSpot MQL increase is from known enterprise forms or
--          new forms. Also checks whether became_mql contacts are submitting
--          forms outside the 5-name filter.
-- Dependencies: soundstripe_prod.hubspot.hubspot_forms,
--               soundstripe_prod.staging.stg_contacts_2
-- =============================================================================

WITH date_bounds AS (
    SELECT
        DATEADD('week', -9, DATE_TRUNC('week', CURRENT_DATE())) AS window_start
        ,DATE_TRUNC('week', CURRENT_DATE())                      AS window_end
)

SELECT
    DATE_TRUNC('week', a.SUBMISSION_TS) AS iso_week
    ,a.FORM_NAME
    ,COUNT(DISTINCT a.email)            AS mql_contacts
FROM soundstripe_prod.hubspot.hubspot_forms a
    INNER JOIN soundstripe_prod.staging.stg_contacts_2 b
        ON a.email = b.email
    CROSS JOIN date_bounds d
WHERE 1=1
    AND b.became_mql IS NOT NULL
    AND a.SUBMISSION_TS >= d.window_start
    AND a.SUBMISSION_TS <  d.window_end
GROUP BY 1, 2
ORDER BY 1, 3 DESC
;

-- =============================================================================
-- Q4b: Mixpanel fct_events Enterprise Events vs fct_sessions MQL Distinct IDs
-- Purpose: Check if enterprise events exist in fct_events but fail to produce
--          MQL flags in fct_sessions. Compares event-level distinct users to
--          session-level distinct users per week.
-- =============================================================================

WITH date_bounds AS (
    SELECT
        DATEADD('week', -9, DATE_TRUNC('week', CURRENT_DATE())) AS window_start
        ,DATE_TRUNC('week', CURRENT_DATE())                      AS window_end
)

,events_layer AS (
    SELECT
        DATE_TRUNC('week', e.event_ts) AS iso_week
        ,COUNT(DISTINCT e.distinct_id) AS event_distinct_users
    FROM soundstripe_prod.core.fct_events e
        CROSS JOIN date_bounds d
    WHERE 1=1
        AND e.event_ts >= d.window_start
        AND e.event_ts <  d.window_end
        AND (
            (e.event = 'Submitted Form' AND LOWER(e.context) = 'enterprise contact form')
            OR (e.event = 'MKT Submitted Enterprise Contact Form' AND e.url ILIKE '%enterprise%')
            OR (e.event = 'Clicked Element' AND e.context = 'Enterprise Contact Form')
        )
    GROUP BY 1
)

,sessions_layer AS (
    SELECT
        DATE_TRUNC('week', s.session_started_at) AS iso_week
        ,COUNT(DISTINCT s.distinct_id)            AS session_distinct_users
    FROM soundstripe_prod.core.fct_sessions s
        CROSS JOIN date_bounds d
    WHERE 1=1
        AND s.session_started_at >= d.window_start
        AND s.session_started_at <  d.window_end
        AND (
            s.ENTERPRISE_FORM_SUBMISSIONS > 0
            OR s.ENTERPRISE_LANDING_FORM_SUBMISSIONS > 0
            OR s.ENTERPRISE_SCHEDULE_DEMO > 0
        )
    GROUP BY 1
)

SELECT
    COALESCE(e.iso_week, s.iso_week) AS iso_week
    ,e.event_distinct_users
    ,s.session_distinct_users
    ,e.event_distinct_users - s.session_distinct_users AS drop_off
FROM events_layer e
    FULL OUTER JOIN sessions_layer s
        ON e.iso_week = s.iso_week
ORDER BY 1
;
