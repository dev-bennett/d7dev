-- Q6a: For meetings.hubspot.com MQLs — does a Clicked Element / Enterprise Contact Form
-- event exist in fct_events within ±300s? If yes, tier 1 has the event but base_url
-- comparison kills the match. If no, there's no Mixpanel signal at all.

WITH meetings_mqls AS (
    SELECT
        m.email
        ,m.SUBMISSION_TS
        ,m.PAGE_URL
        ,SPLIT_PART(SPLIT_PART(m.PAGE_URL, '?', 1), '//', 2) AS hs_base_url
    FROM soundstripe_prod.MARKETING.dim_mql_mapping m
    WHERE m.match_tier = 'tier3_session'
        AND m.SUBMISSION_TS >= '2026-03-16'
        AND m.SUBMISSION_TS < DATE_TRUNC('week', CURRENT_DATE())
        AND m.PAGE_URL ILIKE '%meetings.hubspot.com%'
        AND m.email NOT IN (
            SELECT DISTINCT email
            FROM soundstripe_prod.MARKETING.dim_mql_mapping
            WHERE match_tier IN ('tier1_form', 'tier2_page')
        )
)

SELECT
    h.email
    ,h.SUBMISSION_TS AS hs_ts
    ,h.hs_base_url
    ,a.event_ts AS mp_ts
    ,ABS(DATEDIFF('second', a.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) AS seconds_apart
    ,a.event
    ,a.context
    ,a.url AS mp_url
    ,SPLIT_PART(SPLIT_PART(a.url, '?', 1), '//', 2) AS mp_base_url
    ,a.distinct_id
    ,a.session_id
FROM meetings_mqls h
    LEFT JOIN soundstripe_prod.core.fct_events a
        ON ABS(DATEDIFF('second', a.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) < 300
        AND (
            (a.event = 'Clicked Element' AND a.context = 'Enterprise Contact Form')
            OR (a.event = 'Submitted Form' AND LOWER(a.context) = 'enterprise contact form')
            OR (a.event = 'MKT Submitted Enterprise Contact Form')
            OR (a.event = 'CTA Form Submitted')
            OR (a.event = 'Submitted Form' AND a.url ILIKE '%/brand-solutions%')
            OR (a.event = 'Submitted Form' AND a.url ILIKE '%/agency-solutions%')
        )
WHERE a.event_ts >= DATEADD('minute', -10, '2026-03-16'::timestamp)
    AND a.event_ts < DATE_TRUNC('week', CURRENT_DATE())
ORDER BY h.email, seconds_apart
;


-- Q6b: For /pricing MQLs — does ANY enterprise-related Mixpanel event exist
-- within ±300s? Broadest possible search: any event where URL or context
-- mentions enterprise, pricing, brand-solutions, agency-solutions.

WITH pricing_mqls AS (
    SELECT
        m.email
        ,m.SUBMISSION_TS
        ,m.PAGE_URL
        ,SPLIT_PART(SPLIT_PART(m.PAGE_URL, '?', 1), '//', 2) AS hs_base_url
    FROM soundstripe_prod.MARKETING.dim_mql_mapping m
    WHERE m.match_tier = 'tier3_session'
        AND m.SUBMISSION_TS >= '2026-03-16'
        AND m.SUBMISSION_TS < DATE_TRUNC('week', CURRENT_DATE())
        AND m.PAGE_URL ILIKE '%/pricing%'
        AND m.email NOT IN (
            SELECT DISTINCT email
            FROM soundstripe_prod.MARKETING.dim_mql_mapping
            WHERE match_tier IN ('tier1_form', 'tier2_page')
        )
)

SELECT
    h.email
    ,h.SUBMISSION_TS AS hs_ts
    ,h.hs_base_url
    ,a.event_ts AS mp_ts
    ,ABS(DATEDIFF('second', a.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) AS seconds_apart
    ,a.event
    ,a.context
    ,a.url AS mp_url
    ,a.distinct_id
    ,a.session_id
FROM pricing_mqls h
    LEFT JOIN soundstripe_prod.core.fct_events a
        ON ABS(DATEDIFF('second', a.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) < 300
        AND (
            -- Any enterprise-related event
            (a.event ILIKE '%enterprise%')
            OR (a.context ILIKE '%enterprise%')
            -- Any form submission event
            OR (a.event = 'Submitted Form')
            OR (a.event = 'CTA Form Submitted')
            OR (a.event ILIKE '%form%submit%')
            -- Clicked Element on pricing or enterprise
            OR (a.event = 'Clicked Element' AND (a.url ILIKE '%/pricing%' OR a.context ILIKE '%enterprise%'))
        )
WHERE a.event_ts >= DATEADD('minute', -10, '2026-03-16'::timestamp)
    AND a.event_ts < DATE_TRUNC('week', CURRENT_DATE())
ORDER BY h.email, seconds_apart
;


-- Q6c: For /music-licensing-for-enterprise MQLs that are tier-3-only —
-- same diagnostic. These should have the cleanest match path. If tier 1
-- misses these, something fundamental is broken.

WITH enterprise_page_mqls AS (
    SELECT
        m.email
        ,m.SUBMISSION_TS
        ,m.PAGE_URL
        ,SPLIT_PART(SPLIT_PART(m.PAGE_URL, '?', 1), '//', 2) AS hs_base_url
    FROM soundstripe_prod.MARKETING.dim_mql_mapping m
    WHERE m.match_tier = 'tier3_session'
        AND m.SUBMISSION_TS >= '2026-03-16'
        AND m.SUBMISSION_TS < DATE_TRUNC('week', CURRENT_DATE())
        AND m.PAGE_URL ILIKE '%/music-licensing-for-enterprise%'
        AND m.email NOT IN (
            SELECT DISTINCT email
            FROM soundstripe_prod.MARKETING.dim_mql_mapping
            WHERE match_tier IN ('tier1_form', 'tier2_page')
        )
)

SELECT
    h.email
    ,h.SUBMISSION_TS AS hs_ts
    ,h.hs_base_url
    ,a.event_ts AS mp_ts
    ,ABS(DATEDIFF('second', a.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) AS seconds_apart
    ,a.event
    ,a.context
    ,a.url AS mp_url
    ,SPLIT_PART(SPLIT_PART(a.url, '?', 1), '//', 2) AS mp_base_url
    ,h.hs_base_url = SPLIT_PART(SPLIT_PART(a.url, '?', 1), '//', 2) AS base_url_match
    ,a.distinct_id
    ,a.session_id
FROM enterprise_page_mqls h
    LEFT JOIN soundstripe_prod.core.fct_events a
        ON ABS(DATEDIFF('second', a.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) < 300
        AND (
            (a.event = 'Submitted Form' AND LOWER(a.context) = 'enterprise contact form')
            OR (a.event = 'MKT Submitted Enterprise Contact Form')
            OR (a.event = 'Clicked Element' AND a.context = 'Enterprise Contact Form')
            OR (a.event = 'CTA Form Submitted')
            OR (a.event = 'Submitted Form')
        )
WHERE a.event_ts >= DATEADD('minute', -10, '2026-03-16'::timestamp)
    AND a.event_ts < DATE_TRUNC('week', CURRENT_DATE())
ORDER BY h.email, seconds_apart
;
