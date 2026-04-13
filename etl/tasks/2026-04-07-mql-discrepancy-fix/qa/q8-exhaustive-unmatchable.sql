-- Q8: Exhaustive search for "unmatchable" tier-3-only MQLs
-- Uses raw Mixpanel export (has identity fields) to search for ANY event
-- on the same base URL within ±300s. No event type filter.
-- If rows come back, there's a matchable signal we missed.

WITH unmatchable_mqls AS (
    SELECT
        m.email
        ,m.SUBMISSION_TS
        ,m.PAGE_URL
        ,SPLIT_PART(SPLIT_PART(m.PAGE_URL, '?', 1), '//', 2) AS hs_base_url
    FROM soundstripe_prod.MARKETING.dim_mql_mapping m
    WHERE m.match_tier = 'tier3_session'
        AND m.SUBMISSION_TS >= '2026-02-23'
        AND m.SUBMISSION_TS < DATE_TRUNC('week', CURRENT_DATE())
        AND m.PAGE_URL NOT ILIKE '%/pricing%'
        AND m.email NOT IN (
            SELECT DISTINCT email
            FROM soundstripe_prod.MARKETING.dim_mql_mapping
            WHERE match_tier IN ('tier1_form', 'tier2_page')
        )
        AND m.email NOT IN (
            SELECT DISTINCT email
            FROM soundstripe_prod.MARKETING.dim_mql_mapping
            WHERE PAGE_URL ILIKE '%/pricing%'
        )
)

SELECT
    h.email
    ,h.SUBMISSION_TS AS hs_ts
    ,h.hs_base_url
    ,e.time::timestamp AS mp_ts
    ,ABS(DATEDIFF('second', e.time::timestamp, h.SUBMISSION_TS::timestamp)) AS seconds_apart
    ,e.event
    ,e.context
    ,COALESCE(e.current_url, e.mp_reserved_current_url, e.url) AS mp_url
    ,SPLIT_PART(SPLIT_PART(COALESCE(e.current_url, e.mp_reserved_current_url, e.url), '?', 1), '//', 2) AS mp_base_url
    ,e.distinct_id
    ,COALESCE(e.user_id, e.mp_reserved_user_id) AS resolved_user_id
FROM unmatchable_mqls h
    LEFT JOIN pc_stitch_db.mixpanel.export e
        ON ABS(DATEDIFF('second', e.time::timestamp, h.SUBMISSION_TS::timestamp)) < 300
        AND SPLIT_PART(SPLIT_PART(COALESCE(e.current_url, e.mp_reserved_current_url, e.url), '?', 1), '//', 2)
            = h.hs_base_url
        AND e.time::timestamp >= DATEADD('minute', -10, '2026-02-23'::timestamp)
        AND e.time::timestamp < DATE_TRUNC('week', CURRENT_DATE())
ORDER BY h.email, seconds_apart
;
