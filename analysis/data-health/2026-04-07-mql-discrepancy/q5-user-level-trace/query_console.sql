-- =============================================================================
-- Q5a: Identity Resolution — HubSpot MQLs to Mixpanel User IDs
-- Author: d7admin
-- Date: 2026-04-07
-- Purpose: For each HubSpot MQL from the most recent high-gap week (03-30),
--          resolve their Mixpanel identity via two paths:
--            1. stg_contacts_2.soundstripe_user_id → fct_events.user_id
--            2. canonical_vid → users.hubspot_contact_vid → users.id
--          Then classify: has Mixpanel identity, has MQL event, or unlinked.
-- Dependencies: soundstripe_prod.hubspot.hubspot_forms,
--               soundstripe_prod.staging.stg_contacts_2,
--               pc_stitch_db.soundstripe.users,
--               soundstripe_prod.core.fct_events
-- =============================================================================

WITH hubspot_mqls AS (
    -- All enterprise form MQLs from week of 03-30
    SELECT
        a.email
        ,a.SUBMISSION_TS
        ,a.FORM_NAME
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

,identity_resolution AS (
    -- Resolve Mixpanel user_id via two paths
    SELECT
        h.*
        ,u.id AS users_table_id
        ,COALESCE(h.soundstripe_user_id, u.id::STRING) AS resolved_mp_user_id
    FROM hubspot_mqls h
        LEFT JOIN pc_stitch_db.soundstripe.users u
            ON h.canonical_vid = u.hubspot_contact_vid
)

,mixpanel_presence AS (
    -- Check if each resolved user has ANY Mixpanel events within ±2 hours of submission
    SELECT
        ir.email
        ,ir.SUBMISSION_TS
        ,ir.resolved_mp_user_id
        ,ir.canonical_vid
        ,ir.soundstripe_user_id
        ,ir.users_table_id
        ,COUNT(e.event_ts) AS events_in_window
        ,COUNT(CASE
            WHEN (e.event = 'Submitted Form' AND LOWER(e.context) = 'enterprise contact form')
              OR (e.event = 'MKT Submitted Enterprise Contact Form' AND e.url ILIKE '%enterprise%')
              OR (e.event = 'Clicked Element' AND e.context = 'Enterprise Contact Form')
            THEN 1
        END) AS mql_events_in_window
        ,COUNT(CASE
            WHEN e.event = 'CTA Form Submitted'
            THEN 1
        END) AS cta_form_events_in_window
        ,COUNT(CASE
            WHEN e.event ILIKE '%form%' OR e.event ILIKE '%submit%'
            THEN 1
        END) AS any_form_events_in_window
    FROM identity_resolution ir
        LEFT JOIN soundstripe_prod.core.fct_events e
            ON e.user_id = ir.resolved_mp_user_id
            AND e.event_ts BETWEEN DATEADD('hour', -2, ir.SUBMISSION_TS)
                               AND DATEADD('hour', 2, ir.SUBMISSION_TS)
    WHERE ir.resolved_mp_user_id IS NOT NULL
    GROUP BY 1, 2, 3, 4, 5, 6
)

SELECT
    email
    ,SUBMISSION_TS
    ,canonical_vid
    ,soundstripe_user_id
    ,users_table_id
    ,resolved_mp_user_id
    ,events_in_window
    ,mql_events_in_window
    ,cta_form_events_in_window
    ,any_form_events_in_window
    ,CASE
        WHEN events_in_window = 0 THEN 'no_mixpanel_activity'
        WHEN mql_events_in_window > 0 THEN 'has_mql_event'
        WHEN any_form_events_in_window > 0 THEN 'has_form_event_not_mql'
        ELSE 'has_activity_no_form_event'
    END AS classification
FROM mixpanel_presence
ORDER BY classification, SUBMISSION_TS
;

-- =============================================================================
-- Q5b: Unlinked MQLs — HubSpot MQLs with No Resolvable Mixpanel Identity
-- Purpose: Count how many HubSpot MQLs have no soundstripe_user_id AND no
--          hubspot_contact_vid match in the users table — these cannot be
--          traced in Mixpanel at all.
-- =============================================================================

WITH hubspot_mqls AS (
    SELECT
        a.email
        ,a.SUBMISSION_TS
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
    CASE
        WHEN h.soundstripe_user_id IS NOT NULL THEN 'has_ss_user_id'
        WHEN u.id IS NOT NULL THEN 'vid_linked_only'
        ELSE 'no_mixpanel_identity'
    END AS identity_status
    ,COUNT(*) AS mql_count
FROM hubspot_mqls h
    LEFT JOIN pc_stitch_db.soundstripe.users u
        ON h.canonical_vid = u.hubspot_contact_vid
GROUP BY 1
ORDER BY 2 DESC
;

-- =============================================================================
-- Q5c: Full Clickstream for Sample Users
-- Purpose: For up to 5 HubSpot MQLs that have Mixpanel activity but NO MQL
--          event (classification = 'has_activity_no_form_event' or
--          'has_form_event_not_mql'), pull their complete event stream within
--          ±2 hours of the HubSpot submission. Shows what events actually fired.
-- =============================================================================

WITH hubspot_mqls AS (
    SELECT
        a.email
        ,a.SUBMISSION_TS
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

,identity_resolution AS (
    SELECT
        h.*
        ,COALESCE(h.soundstripe_user_id, u.id::STRING) AS resolved_mp_user_id
    FROM hubspot_mqls h
        LEFT JOIN pc_stitch_db.soundstripe.users u
            ON h.canonical_vid = u.hubspot_contact_vid
    WHERE COALESCE(h.soundstripe_user_id, u.id::STRING) IS NOT NULL
)

,sample_users AS (
    -- Pick users who have Mixpanel activity but might be missing MQL events
    SELECT
        ir.email
        ,ir.SUBMISSION_TS
        ,ir.resolved_mp_user_id
    FROM identity_resolution ir
        INNER JOIN soundstripe_prod.core.fct_events e
            ON e.user_id = ir.resolved_mp_user_id
            AND e.event_ts BETWEEN DATEADD('hour', -2, ir.SUBMISSION_TS)
                               AND DATEADD('hour', 2, ir.SUBMISSION_TS)
    GROUP BY 1, 2, 3
    HAVING COUNT(CASE
        WHEN (e.event = 'Submitted Form' AND LOWER(e.context) = 'enterprise contact form')
          OR (e.event = 'MKT Submitted Enterprise Contact Form' AND e.url ILIKE '%enterprise%')
          OR (e.event = 'Clicked Element' AND e.context = 'Enterprise Contact Form')
        THEN 1 END) = 0
    LIMIT 5
)

SELECT
    s.email
    ,s.SUBMISSION_TS AS hubspot_submission_ts
    ,e.event_ts
    ,DATEDIFF('second', s.SUBMISSION_TS, e.event_ts) AS seconds_from_submission
    ,e.event
    ,e.context
    ,e.url
    ,e.host
    ,e.path
    ,e.session_id
    ,e.distinct_id
FROM sample_users s
    INNER JOIN soundstripe_prod.core.fct_events e
        ON e.user_id = s.resolved_mp_user_id
        AND e.event_ts BETWEEN DATEADD('hour', -2, s.SUBMISSION_TS)
                           AND DATEADD('hour', 2, s.SUBMISSION_TS)
ORDER BY s.email, e.event_ts
;
