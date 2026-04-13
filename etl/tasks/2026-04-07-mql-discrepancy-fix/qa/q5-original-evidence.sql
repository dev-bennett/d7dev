-- Q5a: Original analysis Q3a — Submitted Form with empty context by URL
-- This query proved the events EXIST in raw Mixpanel on /brand-solutions
-- and /agency-solutions, which was the basis for adding those patterns
-- to fct_sessions_build and dim_mql_mapping.
-- Source: analysis/data-health/2026-04-07-mql-discrepancy/q3-uncaptured-events/

WITH date_bounds AS (
    SELECT
        '2026-02-23'::DATE AS window_start
        ,DATE_TRUNC('week', CURRENT_DATE()) AS window_end
)

SELECT
    DATE_TRUNC('week', e.time::timestamp) AS iso_week
    ,PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):host::STRING AS host
    ,PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::STRING AS path
    ,e.context
    ,COUNT(*) AS event_count
FROM pc_stitch_db.mixpanel.export e
    CROSS JOIN date_bounds d
WHERE 1=1
    AND e.time::timestamp >= d.window_start
    AND e.time::timestamp < d.window_end
    AND e.event = 'Submitted Form'
    AND (e.context IS NULL OR TRIM(e.context) = '' OR e.context = 'null')
GROUP BY 1, 2, 3, 4
ORDER BY 1, 5 DESC
;


-- Q5b: Do those same events exist in fct_events (post-pipeline)?
-- If yes, dim_mql_mapping tier 1 should find them.
-- If no, they're being dropped somewhere in the pipeline.

SELECT
    DATE_TRUNC('week', a.event_ts) AS iso_week
    ,a.event
    ,a.context
    ,a.url
    ,SPLIT_PART(SPLIT_PART(a.url, '?', 1), '//', 2) AS derived_base_url
    ,COUNT(*) AS event_count
FROM soundstripe_prod.core.fct_events a
WHERE a.event_ts >= '2026-02-23'
    AND a.event_ts < DATE_TRUNC('week', CURRENT_DATE())
    AND a.event = 'Submitted Form'
    AND (
        a.url ILIKE '%/brand-solutions%'
        OR a.url ILIKE '%/agency-solutions%'
    )
GROUP BY 1, 2, 3, 4, 5
ORDER BY 1, 6 DESC
;


-- Q5c: For tier-3-only MQLs, show the HubSpot base_url vs what fct_events has
-- This directly tests whether the base_url join condition in tier 1 can match.
-- If the URLs don't align (e.g., www.soundstripe.com vs soundstripe.com),
-- that explains why tier 1 fails and tier 3 (which doesn't use base_url) catches them.

WITH tier3_only_emails AS (
    SELECT DISTINCT m.email
    FROM soundstripe_prod.MARKETING.dim_mql_mapping m
    WHERE m.match_tier = 'tier3_session'
        AND m.SUBMISSION_TS >= '2026-03-16'
        AND m.SUBMISSION_TS < DATE_TRUNC('week', CURRENT_DATE())
        AND m.email NOT IN (
            SELECT DISTINCT email
            FROM soundstripe_prod.MARKETING.dim_mql_mapping
            WHERE match_tier IN ('tier1_form', 'tier2_page')
        )
),

hubspot_side AS (
    SELECT
        h.email
        ,h.SUBMISSION_TS
        ,h.PAGE_URL
        ,SPLIT_PART(SPLIT_PART(h.PAGE_URL, '?', 1), '//', 2) AS hs_base_url
    FROM soundstripe_prod.hubspot.hubspot_forms h
    WHERE h.email IN (SELECT email FROM tier3_only_emails)
        AND h.FORM_NAME IN (
            'Enterprise (API Page)', 'Enterprise Multi-step Form', 'Enterprise Request Form'
            ,'Enterprise Request Form (Hubspot)', 'Enterprise v2 - Updated'
            ,'Meetings Link: ned-pruitt/enterprise-calendar-schedule-form'
        )
),

mixpanel_side AS (
    SELECT
        a.event_ts
        ,a.event
        ,a.url AS mp_url
        ,SPLIT_PART(SPLIT_PART(a.url, '?', 1), '//', 2) AS mp_base_url
        ,a.distinct_id
        ,a.session_id
    FROM soundstripe_prod.core.fct_events a
    WHERE a.event_ts >= '2026-03-16'
        AND a.event_ts < DATE_TRUNC('week', CURRENT_DATE())
        AND (
            (a.event = 'Submitted Form' AND LOWER(a.context) = 'enterprise contact form')
            OR (a.event = 'Submitted Form' AND a.url ILIKE '%/brand-solutions%')
            OR (a.event = 'Submitted Form' AND a.url ILIKE '%/agency-solutions%')
            OR (a.event = 'CTA Form Submitted' AND a.url ILIKE '%/enterprise%')
            OR (a.event = 'MKT Submitted Enterprise Contact Form' AND a.url ILIKE '%enterprise%')
            OR (a.event = 'Clicked Element' AND a.context = 'Enterprise Contact Form')
        )
)

SELECT
    h.email
    ,h.SUBMISSION_TS AS hs_ts
    ,h.hs_base_url
    ,m.event_ts AS mp_ts
    ,m.mp_base_url
    ,ABS(DATEDIFF('second', m.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) AS seconds_apart
    ,m.event AS mp_event
    ,h.hs_base_url = m.mp_base_url AS base_url_match
FROM hubspot_side h
    LEFT JOIN mixpanel_side m
        ON ABS(DATEDIFF('second', m.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) < 300
ORDER BY h.email, seconds_apart
;
