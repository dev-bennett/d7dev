-- =============================================================================
-- Q7a: Full Recovery Funnel — Classify Every HubSpot MQL
-- Author: d7admin
-- Date: 2026-04-07
-- Purpose: For every HubSpot MQL in week 03-30, classify the best available
--          Mixpanel matching strategy:
--          1. Form event match (time + URL) — direct session attribution
--          2. Page view match (enterprise URL, same session) — session attribution
--          3. Any Mixpanel event by same device ID within ±30 min — session proximity
--          4. No Mixpanel activity — fall back to HubSpot UTMs
-- Dependencies: soundstripe_prod.hubspot.hubspot_forms,
--               soundstripe_prod.staging.stg_contacts_2,
--               pc_stitch_db.mixpanel.export
-- =============================================================================

WITH hubspot_mqls AS (
    SELECT
        a.email
        ,a.SUBMISSION_TS
        ,a.PAGE_URL
        ,SPLIT_PART(SPLIT_PART(a.PAGE_URL, '?', 1), '//', 2) AS hs_base_url
        ,b.canonical_vid
        ,b.soundstripe_user_id
        ,ROW_NUMBER() OVER(PARTITION BY a.email ORDER BY a.SUBMISSION_TS) AS rn
    FROM soundstripe_prod.hubspot.hubspot_forms a
        INNER JOIN soundstripe_prod.staging.stg_contacts_2 b
            ON a.email = b.email
    WHERE 1=1
        AND a.FORM_NAME = 'Enterprise v2 - Updated'
        AND b.became_mql IS NOT NULL
        AND a.SUBMISSION_TS >= '2026-03-30'
        AND a.SUBMISSION_TS <  '2026-04-06'
    QUALIFY rn = 1
)

-- Tier 1: Form event on matching base URL within ±120 seconds
,tier1_form_event AS (
    SELECT DISTINCT
        h.email
        ,e.distinct_id
        ,e.time::TIMESTAMP AS mixpanel_ts
        ,ABS(DATEDIFF('second', e.time::TIMESTAMP, h.SUBMISSION_TS)) AS seconds_apart
        ,'tier1_form_event' AS match_tier
    FROM hubspot_mqls h
        INNER JOIN pc_stitch_db.mixpanel.export e
            ON ABS(DATEDIFF('second', e.time::TIMESTAMP, h.SUBMISSION_TS)) < 120
            AND SPLIT_PART(SPLIT_PART(COALESCE(e.current_url, e.mp_reserved_current_url, e.url), '?', 1), '//', 2) = h.hs_base_url
    WHERE e.time::TIMESTAMP >= '2026-03-29'
        AND e.time::TIMESTAMP <  '2026-04-07'
        AND (
            e.event = 'Submitted Form'
            OR e.event = 'CTA Form Submitted'
            OR e.event = 'MKT Submitted Enterprise Contact Form'
        )
    QUALIFY ROW_NUMBER() OVER(PARTITION BY h.email ORDER BY seconds_apart) = 1
)

-- Tier 2: Any Mixpanel event on the same enterprise-related URL within ±120 seconds
-- (page views, clicks — gives us a session to attribute)
,tier2_page_activity AS (
    SELECT DISTINCT
        h.email
        ,e.distinct_id
        ,e.time::TIMESTAMP AS mixpanel_ts
        ,ABS(DATEDIFF('second', e.time::TIMESTAMP, h.SUBMISSION_TS)) AS seconds_apart
        ,'tier2_page_activity' AS match_tier
    FROM hubspot_mqls h
        INNER JOIN pc_stitch_db.mixpanel.export e
            ON ABS(DATEDIFF('second', e.time::TIMESTAMP, h.SUBMISSION_TS)) < 120
    WHERE e.time::TIMESTAMP >= '2026-03-29'
        AND e.time::TIMESTAMP <  '2026-04-07'
        AND COALESCE(e.current_url, e.mp_reserved_current_url, e.url) ILIKE '%' || SPLIT_PART(h.hs_base_url, '/', 2) || '%'
        AND h.email NOT IN (SELECT email FROM tier1_form_event)
    QUALIFY ROW_NUMBER() OVER(PARTITION BY h.email ORDER BY seconds_apart) = 1
)

-- Tier 3: Any Mixpanel event by the same device that was on the enterprise page
-- within ±30 minutes — captures the session even if the form page wasn't tracked
,tier3_session_proximity AS (
    SELECT DISTINCT
        h.email
        ,e.distinct_id
        ,e.time::TIMESTAMP AS mixpanel_ts
        ,ABS(DATEDIFF('second', e.time::TIMESTAMP, h.SUBMISSION_TS)) AS seconds_apart
        ,'tier3_session_proximity' AS match_tier
    FROM hubspot_mqls h
        INNER JOIN pc_stitch_db.mixpanel.export e
            ON ABS(DATEDIFF('minute', e.time::TIMESTAMP, h.SUBMISSION_TS)) < 30
    WHERE e.time::TIMESTAMP >= '2026-03-29'
        AND e.time::TIMESTAMP <  '2026-04-07'
        AND e.event IN ('$mp_web_page_view', 'Viewed Page')
        AND COALESCE(e.current_url, e.mp_reserved_current_url, e.url) ILIKE '%soundstripe.com%'
        AND h.email NOT IN (SELECT email FROM tier1_form_event)
        AND h.email NOT IN (SELECT email FROM tier2_page_activity)
        -- Only match if this device also visited an enterprise-related page in the session
        AND e.distinct_id IN (
            SELECT DISTINCT e2.distinct_id
            FROM pc_stitch_db.mixpanel.export e2
            WHERE e2.time::TIMESTAMP BETWEEN DATEADD('minute', -30, h.SUBMISSION_TS)
                                         AND DATEADD('minute', 30, h.SUBMISSION_TS)
              AND (
                  COALESCE(e2.current_url, e2.mp_reserved_current_url, e2.url) ILIKE '%enterprise%'
                  OR COALESCE(e2.current_url, e2.mp_reserved_current_url, e2.url) ILIKE '%brand-solutions%'
                  OR COALESCE(e2.current_url, e2.mp_reserved_current_url, e2.url) ILIKE '%agency-solutions%'
              )
        )
    QUALIFY ROW_NUMBER() OVER(PARTITION BY h.email ORDER BY seconds_apart) = 1
)

SELECT match_tier, COUNT(DISTINCT email) AS users
FROM (
    SELECT email, match_tier FROM tier1_form_event
    UNION ALL
    SELECT email, match_tier FROM tier2_page_activity
    UNION ALL
    SELECT email, match_tier FROM tier3_session_proximity
    UNION ALL
    SELECT email, 'tier4_no_mixpanel' AS match_tier
    FROM hubspot_mqls
    WHERE email NOT IN (SELECT email FROM tier1_form_event)
      AND email NOT IN (SELECT email FROM tier2_page_activity)
      AND email NOT IN (SELECT email FROM tier3_session_proximity)
) grouped
GROUP BY 1
ORDER BY 1
;

-- =============================================================================
-- Q7b: HubSpot-Native Attribution for Unmatched MQLs
-- Purpose: For MQLs with no Mixpanel match, check what attribution data
--          HubSpot itself captured — PAGE_URL UTM parameters, first_url,
--          first_referrer from stg_contacts_2. This is the fallback path.
-- =============================================================================

WITH hubspot_mqls AS (
    SELECT
        a.email
        ,a.SUBMISSION_TS
        ,a.PAGE_URL
        ,b.canonical_vid
        ,b.first_url
        ,b.first_referrer
        ,ROW_NUMBER() OVER(PARTITION BY a.email ORDER BY a.SUBMISSION_TS) AS rn
    FROM soundstripe_prod.hubspot.hubspot_forms a
        INNER JOIN soundstripe_prod.staging.stg_contacts_2 b
            ON a.email = b.email
    WHERE 1=1
        AND a.FORM_NAME = 'Enterprise v2 - Updated'
        AND b.became_mql IS NOT NULL
        AND a.SUBMISSION_TS >= '2026-03-30'
        AND a.SUBMISSION_TS <  '2026-04-06'
    QUALIFY rn = 1
)

-- Check if PAGE_URL contains UTM parameters
SELECT
    h.email
    ,h.SUBMISSION_TS
    ,h.PAGE_URL
    ,CASE WHEN h.PAGE_URL ILIKE '%utm_source%' THEN TRUE ELSE FALSE END AS has_utm_in_page_url
    ,h.first_url
    ,CASE WHEN h.first_url ILIKE '%utm_source%' THEN TRUE ELSE FALSE END AS has_utm_in_first_url
    ,h.first_referrer
    ,CASE
        WHEN h.PAGE_URL ILIKE '%utm_source%' THEN 'hubspot_page_url_utms'
        WHEN h.first_url ILIKE '%utm_source%' THEN 'hubspot_first_url_utms'
        WHEN h.first_referrer IS NOT NULL AND h.first_referrer != '' THEN 'hubspot_referrer_only'
        ELSE 'no_attribution'
    END AS attribution_source
FROM hubspot_mqls h
ORDER BY attribution_source, h.email
;

-- =============================================================================
-- Q7c: Email Property Search in Raw Mixpanel
-- Purpose: Check if the raw Mixpanel export contains an email property on
--          form submission events. If so, we can match HubSpot → Mixpanel
--          directly by email, bypassing the identity chain entirely.
-- =============================================================================

SELECT
    e.event
    ,e.context
    ,e.email IS NOT NULL AS has_email_prop
    ,e.mp_reserved_distinct_id_before_identity IS NOT NULL AS has_pre_identity_id
    ,COUNT(*) AS event_count
    ,COUNT(DISTINCT CASE WHEN e.email IS NOT NULL THEN e.email END) AS distinct_emails
FROM pc_stitch_db.mixpanel.export e
WHERE e.time::TIMESTAMP >= '2026-03-30'
    AND e.time::TIMESTAMP <  '2026-04-06'
    AND (
        (e.event = 'Submitted Form')
        OR (e.event = 'CTA Form Submitted')
        OR (e.event = 'MKT Submitted Enterprise Contact Form')
    )
GROUP BY 1, 2, 3, 4
ORDER BY 5 DESC
;
