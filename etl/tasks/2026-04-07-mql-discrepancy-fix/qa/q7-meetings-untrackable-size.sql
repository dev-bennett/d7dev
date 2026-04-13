-- Q7: Size the genuinely untrackable meetings MQLs — those with meetings.hubspot.com
-- HubSpot URL and NO Mixpanel enterprise event (click or submission) within ±300s.

WITH meetings_mqls AS (
    SELECT
        m.email
        ,m.SUBMISSION_TS
        ,m.PAGE_URL
        ,m.match_tier
    FROM soundstripe_prod.MARKETING.dim_mql_mapping m
    WHERE m.PAGE_URL ILIKE '%meetings.hubspot.com%'
        AND m.SUBMISSION_TS >= '2026-02-23'
        AND m.SUBMISSION_TS < DATE_TRUNC('week', CURRENT_DATE())
),

has_mixpanel_signal AS (
    SELECT DISTINCT h.email
    FROM meetings_mqls h
        INNER JOIN soundstripe_prod.core.fct_events a
            ON ABS(DATEDIFF('second', a.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) < 300
    WHERE a.event_ts >= DATEADD('minute', -10, '2026-02-23'::timestamp)
        AND a.event_ts < DATE_TRUNC('week', CURRENT_DATE())
        AND (
            (a.event = 'Clicked Element' AND a.context = 'Enterprise Contact Form')
            OR (a.event = 'Submitted Form' AND LOWER(a.context) = 'enterprise contact form')
            OR (a.event = 'MKT Submitted Enterprise Contact Form')
            OR (a.event = 'CTA Form Submitted')
            OR (a.event = 'Clicked Contact Sales' AND a.context = 'Enterprise Intent')
        )
)

SELECT
    DATE_TRUNC('week', h.SUBMISSION_TS) AS week
    ,COUNT(DISTINCT h.email) AS meetings_mqls
    ,COUNT(DISTINCT CASE WHEN s.email IS NOT NULL THEN h.email END) AS has_mp_signal
    ,COUNT(DISTINCT CASE WHEN s.email IS NULL THEN h.email END) AS untrackable
FROM meetings_mqls h
    LEFT JOIN has_mixpanel_signal s
        ON h.email = s.email
GROUP BY 1
ORDER BY 1;
