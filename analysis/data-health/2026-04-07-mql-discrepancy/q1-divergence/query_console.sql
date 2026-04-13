-- =============================================================================
-- Q1: MQL Divergence — HubSpot vs Mixpanel Weekly Side-by-Side
-- Author: d7admin
-- Date: 2026-04-07
-- Purpose: Quantify the weekly MQL gap between HubSpot (source of truth)
--          and Mixpanel (fct_sessions) over the past 9 completed ISO weeks.
-- Dependencies: soundstripe_prod.hubspot.hubspot_forms,
--               soundstripe_prod.staging.stg_contacts_2,
--               soundstripe_prod.core.fct_sessions
-- =============================================================================

WITH date_bounds AS (
    -- 9 completed ISO weeks: from 9 weeks before current week start
    -- through the end of last completed week
    SELECT
        DATEADD('week', -9, DATE_TRUNC('week', CURRENT_DATE())) AS window_start
        ,DATE_TRUNC('week', CURRENT_DATE())                      AS window_end
)

,hubspot_weekly AS (
    SELECT
        DATE_TRUNC('week', a.SUBMISSION_TS) AS iso_week
        ,COUNT(DISTINCT a.email)               AS hubspot_mqls
    FROM soundstripe_prod.hubspot.hubspot_forms a
        INNER JOIN soundstripe_prod.staging.stg_contacts_2 b
            ON a.email = b.email
        CROSS JOIN date_bounds d
    WHERE 1=1
        AND a.FORM_NAME IN (
            'Enterprise (API Page)'
            ,'Enterprise Multi-step Form'
            ,'Enterprise Request Form'
            ,'Enterprise Request Form (Hubspot)'
            ,'Enterprise v2 - Updated'
        )
        AND b.became_mql IS NOT NULL
        AND a.SUBMISSION_TS >= d.window_start
        AND a.SUBMISSION_TS <  d.window_end
    GROUP BY 1
)

,mixpanel_weekly AS (
    SELECT
        DATE_TRUNC('week', s.session_started_at) AS iso_week
        ,COUNT(DISTINCT CASE
            WHEN s.ENTERPRISE_FORM_SUBMISSIONS > 0
              OR s.ENTERPRISE_LANDING_FORM_SUBMISSIONS > 0
              OR s.ENTERPRISE_SCHEDULE_DEMO > 0
            THEN s.distinct_id
        END) AS mixpanel_mqls
    FROM soundstripe_prod.CORE.fct_sessions s
        CROSS JOIN date_bounds d
    WHERE 1=1
        AND s.session_started_at >= d.window_start
        AND s.session_started_at <  d.window_end
    GROUP BY 1
)

SELECT
    COALESCE(h.iso_week, m.iso_week)                  AS iso_week
    ,h.hubspot_mqls
    ,m.mixpanel_mqls
    ,h.hubspot_mqls - m.mixpanel_mqls                 AS gap_absolute
    ,ROUND(DIV0(h.hubspot_mqls - m.mixpanel_mqls
               ,h.hubspot_mqls) * 100, 1)             AS gap_pct
FROM hubspot_weekly h
    FULL OUTER JOIN mixpanel_weekly m
        ON h.iso_week = m.iso_week
ORDER BY 1
;
