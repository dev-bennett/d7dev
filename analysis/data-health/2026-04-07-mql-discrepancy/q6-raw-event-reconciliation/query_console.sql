-- =============================================================================
-- Q6a: Raw Event Search — Do Anonymous Enterprise Form Events Exist?
-- Author: d7admin
-- Date: 2026-04-07
-- Purpose: For each "missing" HubSpot MQL from week 03-30, search the RAW
--          Mixpanel export for ANY events within ±120 seconds on the same
--          base URL. Ignores identity entirely — searches by timestamp + URL.
--          This answers: do the Mixpanel events exist at all?
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
    FROM soundstripe_prod.hubspot.hubspot_forms a
        INNER JOIN soundstripe_prod.staging.stg_contacts_2 b
            ON a.email = b.email
    WHERE 1=1
        AND a.FORM_NAME = 'Enterprise v2 - Updated'
        AND b.became_mql IS NOT NULL
        AND a.SUBMISSION_TS >= '2026-03-30'
        AND a.SUBMISSION_TS <  '2026-04-06'
)

SELECT
    h.email
    ,h.SUBMISSION_TS                                        AS hubspot_ts
    ,h.hs_base_url
    ,h.soundstripe_user_id
    ,e.time::TIMESTAMP                                      AS mixpanel_ts
    ,ABS(DATEDIFF('second', e.time::TIMESTAMP, h.SUBMISSION_TS)) AS seconds_apart
    ,e.event
    ,e.context
    ,e.distinct_id
    ,COALESCE(e.user_id, e.mp_reserved_user_id, e.mp_reserved_distinct_id_before_identity) AS resolved_user_id
    ,COALESCE(e.current_url, e.mp_reserved_current_url, e.url) AS mp_url
    ,SPLIT_PART(SPLIT_PART(COALESCE(e.current_url, e.mp_reserved_current_url, e.url), '?', 1), '//', 2) AS mp_base_url
FROM hubspot_mqls h
    INNER JOIN pc_stitch_db.mixpanel.export e
        ON ABS(DATEDIFF('second', e.time::TIMESTAMP, h.SUBMISSION_TS)) < 120
        AND SPLIT_PART(SPLIT_PART(COALESCE(e.current_url, e.mp_reserved_current_url, e.url), '?', 1), '//', 2)
            = h.hs_base_url
WHERE 1=1
    AND e.time::TIMESTAMP >= DATEADD('minute', -5, (SELECT MIN(SUBMISSION_TS) FROM hubspot_mqls))
    AND e.time::TIMESTAMP <= DATEADD('minute', 5, (SELECT MAX(SUBMISSION_TS) FROM hubspot_mqls))
    AND (
        (e.event = 'Submitted Form')
        OR (e.event ILIKE '%enterprise%')
        OR (e.event = 'CTA Form Submitted')
        OR (e.event = 'Clicked Element' AND e.context ILIKE '%enterprise%')
        OR (e.event ILIKE '%form%')
    )
ORDER BY h.email, seconds_apart
;

-- =============================================================================
-- Q6b: Broaden the Search — Any Event on Enterprise Page Near Submission
-- Purpose: For the same HubSpot MQLs, find ANY Mixpanel event (not just
--          form events) on an enterprise-related URL within ±120 seconds.
--          Tests whether the marketing site has Mixpanel JS at all.
-- =============================================================================

WITH hubspot_mqls AS (
    SELECT
        a.email
        ,a.SUBMISSION_TS
        ,a.PAGE_URL
        ,b.canonical_vid
        ,b.soundstripe_user_id
    FROM soundstripe_prod.hubspot.hubspot_forms a
        INNER JOIN soundstripe_prod.staging.stg_contacts_2 b
            ON a.email = b.email
    WHERE 1=1
        AND a.FORM_NAME = 'Enterprise v2 - Updated'
        AND b.became_mql IS NOT NULL
        AND a.SUBMISSION_TS >= '2026-03-30'
        AND a.SUBMISSION_TS <  '2026-04-06'
)

SELECT
    h.email
    ,h.SUBMISSION_TS                                        AS hubspot_ts
    ,h.soundstripe_user_id
    ,e.time::TIMESTAMP                                      AS mixpanel_ts
    ,ABS(DATEDIFF('second', e.time::TIMESTAMP, h.SUBMISSION_TS)) AS seconds_apart
    ,e.event
    ,e.context
    ,e.distinct_id
    ,COALESCE(e.user_id, e.mp_reserved_user_id, e.mp_reserved_distinct_id_before_identity) AS resolved_user_id
    ,COALESCE(e.current_url, e.mp_reserved_current_url, e.url) AS mp_url
FROM hubspot_mqls h
    INNER JOIN pc_stitch_db.mixpanel.export e
        ON ABS(DATEDIFF('second', e.time::TIMESTAMP, h.SUBMISSION_TS)) < 120
WHERE 1=1
    AND e.time::TIMESTAMP >= DATEADD('minute', -5, (SELECT MIN(SUBMISSION_TS) FROM hubspot_mqls))
    AND e.time::TIMESTAMP <= DATEADD('minute', 5, (SELECT MAX(SUBMISSION_TS) FROM hubspot_mqls))
    AND COALESCE(e.current_url, e.mp_reserved_current_url, e.url) ILIKE '%enterprise%'
ORDER BY h.email, seconds_apart
;

-- =============================================================================
-- Q6c: dim_mql_mapping Match Rate Audit
-- Purpose: Run the dim_mql_mapping logic for week 03-30 and report the
--          match distribution: VID+time+URL match, time+URL match, no match.
--          Identifies where the existing reconciliation fails.
-- =============================================================================

WITH form_submissions_mixpanel AS (
    -- Replicate dim_mql_mapping join chain: fct_events -> dim_session_mapping -> fct_sessions -> users
    SELECT
        a.EVENT_TS
        ,c.USER_ID AS session_user_id
        ,a.distinct_id
        ,d.HUBSPOT_CONTACT_VID
        ,d.email AS users_email
        ,a.__SDC_PRIMARY_KEY AS sdc_primary_key
        ,a.url
        ,c.SESSION_ID
        ,SPLIT_PART(SPLIT_PART(a.url, '?', 1), '//', 2) AS base_url
        ,a.event
        ,a.context
    FROM soundstripe_prod.core.fct_events a
        LEFT JOIN soundstripe_prod.core.dim_session_mapping b
            ON a.session_id = b.session_id_events
        LEFT JOIN soundstripe_prod.core.fct_sessions c
            ON b.session_id = c.session_id
        LEFT JOIN pc_stitch_db.soundstripe.users d
            ON c.user_id::STRING = d.id::STRING
    WHERE 1=1
        AND a.event_ts >= '2026-03-30'
        AND a.event_ts <  '2026-04-06'
        AND (
            (a.event = 'Submitted Form' AND LOWER(a.context) = 'enterprise contact form')
            OR (a.event = 'MKT Submitted Enterprise Contact Form' AND a.url ILIKE '%enterprise%')
            OR (a.event = 'Clicked Element' AND a.context = 'Enterprise Contact Form')
            OR (a.event = 'CTA Form Submitted' AND a.url ILIKE '%/enterprise%')
        )
)

,hubspot_mqls AS (
    SELECT
        a.email
        ,a.SUBMISSION_TS
        ,a.FORM_NAME
        ,a.PAGE_URL
        ,SPLIT_PART(SPLIT_PART(a.PAGE_URL, '?', 1), '//', 2) AS base_url
        ,b.canonical_vid
        ,b.soundstripe_user_id
        ,u.id AS users_table_id
        ,u.hubspot_contact_vid
    FROM soundstripe_prod.hubspot.hubspot_forms a
        INNER JOIN soundstripe_prod.staging.stg_contacts_2 b
            ON a.email = b.email
        LEFT JOIN pc_stitch_db.soundstripe.users u
            ON b.canonical_vid = u.hubspot_contact_vid
    WHERE 1=1
        AND a.FORM_NAME = 'Enterprise v2 - Updated'
        AND b.became_mql IS NOT NULL
        AND a.SUBMISSION_TS >= '2026-03-30'
        AND a.SUBMISSION_TS <  '2026-04-06'
)

-- Primary match: VID + time + URL (mirrors dim_mql_mapping user_match)
,vid_match AS (
    SELECT
        h.*
        ,m.sdc_primary_key
        ,m.EVENT_TS AS mixpanel_event_ts
        ,m.SESSION_ID AS mixpanel_session_id
        ,m.distinct_id AS mixpanel_distinct_id
        ,m.event AS mixpanel_event
        ,'vid_time_url' AS match_type
    FROM hubspot_mqls h
        LEFT JOIN form_submissions_mixpanel m
            ON ABS(DATEDIFF('second', m.event_ts::TIMESTAMP, h.SUBMISSION_TS::TIMESTAMP)) < 40
            AND h.base_url = m.base_url
            AND h.canonical_vid = m.HUBSPOT_CONTACT_VID
)

-- Time + URL match (no VID) for those that didn't match above — wider 120s window
,time_url_match AS (
    SELECT
        h.*
        ,m.sdc_primary_key
        ,m.EVENT_TS AS mixpanel_event_ts
        ,m.SESSION_ID AS mixpanel_session_id
        ,m.distinct_id AS mixpanel_distinct_id
        ,m.event AS mixpanel_event
        ,'time_url_only' AS match_type
    FROM hubspot_mqls h
        INNER JOIN form_submissions_mixpanel m
            ON ABS(DATEDIFF('second', m.event_ts::TIMESTAMP, h.SUBMISSION_TS::TIMESTAMP)) < 120
            AND h.base_url = m.base_url
    WHERE h.email NOT IN (SELECT email FROM vid_match WHERE sdc_primary_key IS NOT NULL)
    QUALIFY ROW_NUMBER() OVER(PARTITION BY h.email ORDER BY ABS(DATEDIFF('second', m.event_ts, h.SUBMISSION_TS))) = 1
)

SELECT
    email
    ,SUBMISSION_TS
    ,soundstripe_user_id
    ,hubspot_contact_vid
    ,mixpanel_event_ts
    ,mixpanel_session_id
    ,mixpanel_distinct_id
    ,mixpanel_event
    ,match_type
FROM vid_match
WHERE sdc_primary_key IS NOT NULL

UNION ALL

SELECT
    email
    ,SUBMISSION_TS
    ,soundstripe_user_id
    ,hubspot_contact_vid
    ,mixpanel_event_ts
    ,mixpanel_session_id
    ,mixpanel_distinct_id
    ,mixpanel_event
    ,match_type
FROM time_url_match

UNION ALL

-- Unmatched
SELECT
    h.email
    ,h.SUBMISSION_TS
    ,h.soundstripe_user_id
    ,h.hubspot_contact_vid
    ,NULL
    ,NULL
    ,NULL
    ,NULL
    ,'no_match'
FROM hubspot_mqls h
WHERE h.email NOT IN (SELECT email FROM vid_match WHERE sdc_primary_key IS NOT NULL)
  AND h.email NOT IN (SELECT email FROM time_url_match)

ORDER BY match_type, email
;
