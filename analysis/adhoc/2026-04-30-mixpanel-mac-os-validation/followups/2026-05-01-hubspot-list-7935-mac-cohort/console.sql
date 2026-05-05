-- Purpose:    Extract HubSpot list 7935 ("Cue Beta User Targets All") with each
--             contact tagged Mac / non-Mac for Soundstripe Live beta targeting.
-- Author:     Devon Bennett (drafted with assistant)
-- Date:       2026-05-01
-- Source:     HUBSPOT_PLATFORM_DATA.V2_LIVE  (live-sync schema; V2_DAILY had not
--             yet picked up list 7935 at run time. List was created 2026-05-01
--             12:00 UTC; ingested into V2_LIVE 1 minute later).
--             SOUNDSTRIPE_PROD.HUBSPOT.HUBSPOT_CONTACTS  (mart with PROPERTIES JSON)
--             SOUNDSTRIPE_PROD.CORE.{DIM_USERS, FCT_SESSIONS, FCT_EVENTS,
--                                     DIM_SESSION_MAPPING}
--             pc_stitch_db.mixpanel.export  (raw OS labels)
-- Window:     2025-05-01 to 2026-05-01 (12 months historical; broader than the
--             parent task's 7-day validation to capture historical Mac usage.
--             Switching the window from 30d to 12mo moved 19 contacts from the
--             "no recent activity" bucket into MAC.)
-- Cost:       <$0.10 expected; 97-row list, narrow user_id IN-list.
-- Parent:     ../../  (analysis/adhoc/2026-04-30-mixpanel-mac-os-validation/
--             — canonical Mac filter `mp_reserved_os IN ('Mac','Mac OS X')`)


----------------------------------------------------------------------
-- q0: list metadata sanity check.
----------------------------------------------------------------------
SELECT
       LISTID
     , CLASSICLISTID
     , NAME
     , LISTTYPE
     , OBJECTTYPEID
     , SIZE
     , CREATEDAT
     , INGESTEDAT
FROM HUBSPOT_PLATFORM_DATA.V2_LIVE.LISTS
WHERE LISTID = 7935;
-- Expected: 1 row, NAME = 'Cue Beta User Targets All', LISTTYPE = 'SNAPSHOT',
--           OBJECTTYPEID = '0-1' (contacts), SIZE = 97.


----------------------------------------------------------------------
-- q1: List 7935 contact extract — 97 rows with HubSpot attributes.
--     Bridges to dim_users via three paths in priority order:
--       1. dim_users.HUBSPOT_CONTACT_VID  (mart-confirmed bridge)
--       2. dim_users.USER_ID = soundstripe_user_id  (HubSpot custom property)
--       3. dim_users.EMAIL  (fallback)
--     Output: one row per HubSpot list-7935 contact, including the
--     `bridge_path` and `resolved_user_id` columns used by q2.
----------------------------------------------------------------------
WITH list_members AS (
    SELECT lm.OBJECTID AS hubspot_vid
    FROM HUBSPOT_PLATFORM_DATA.V2_LIVE.LIST_MEMBERSHIPS lm
    WHERE lm.LISTID = 7935
)
, list_with_attrs AS (
    SELECT
           m.hubspot_vid
         , LOWER(c.PROPERTIES:email::string)                              AS email
         , c.PROPERTIES:firstname::string                                  AS firstname
         , c.PROPERTIES:lastname::string                                   AS lastname
         , TRY_CAST(c.PROPERTIES:soundstripe_user_id::string AS NUMBER)    AS soundstripe_user_id
         , c.PROPERTIES:subscription_type__core_type_::string              AS subscription_core_type
         , c.PROPERTIES:subscription_status::string                        AS subscription_status
         , c.PROPERTIES:hs_lead_status::string                             AS hs_lead_status
         , c.PROPERTIES:company::string                                    AS company
    FROM      list_members                              m
    LEFT JOIN SOUNDSTRIPE_PROD.HUBSPOT.HUBSPOT_CONTACTS c
           ON m.hubspot_vid = c.OBJECT_ID
)
SELECT
       l.hubspot_vid
     , l.email
     , l.firstname
     , l.lastname
     , l.soundstripe_user_id
     , l.subscription_core_type
     , l.subscription_status
     , l.hs_lead_status
     , l.company
     , COALESCE(du_vid.user_id, du_uid.user_id, du_email.user_id)      AS resolved_user_id
     , CASE
           WHEN du_vid.user_id   IS NOT NULL THEN 'hubspot_vid'
           WHEN du_uid.user_id   IS NOT NULL THEN 'soundstripe_user_id'
           WHEN du_email.user_id IS NOT NULL THEN 'email'
           ELSE 'none'
       END                                                              AS bridge_path
FROM      list_with_attrs                          l
LEFT JOIN SOUNDSTRIPE_PROD.CORE.DIM_USERS          du_vid
       ON du_vid.HUBSPOT_CONTACT_VID = l.hubspot_vid
LEFT JOIN SOUNDSTRIPE_PROD.CORE.DIM_USERS          du_uid
       ON du_uid.USER_ID = l.soundstripe_user_id
      AND du_vid.user_id IS NULL
LEFT JOIN SOUNDSTRIPE_PROD.CORE.DIM_USERS          du_email
       ON LOWER(du_email.EMAIL) = l.email
      AND du_vid.user_id IS NULL
      AND du_uid.user_id IS NULL
ORDER BY l.hubspot_vid;


----------------------------------------------------------------------
-- q2: List 7935 × Mac classification — final deliverable (97 rows).
--
-- Classification:
--   MAC                 : ANY event in 12-month window with mp_reserved_os
--                         IN ('Mac','Mac OS X') for this contact's resolved
--                         Soundstripe user_id
--   NON_MAC             : HAS events in 12-month window, but none on Mac
--   NO_DATA_12MO        : Resolved Soundstripe user_id, but no Mixpanel
--                         events in 12-month window
--   NO_SS_ACCOUNT       : No Soundstripe match — verified across dim_users
--                         (vid + user_id + email + alt-vids in hs_all_contact_vids)
--                         AND raw pc_stitch_db.soundstripe.users on email.
--                         HubSpot-side: lifecyclestage = 'lead' for 10 of 12,
--                         no chargebee_customer_id, no stripe_customer_id,
--                         no subscription_type. These contacts are leads, not
--                         paid subscribers.
--
-- Surfaced columns:
--   most_recent_os      : last observed OS in 12mo (helps spot users who
--                         switched, e.g. classified MAC because of an event
--                         9 months ago but currently on Windows)
--   last_mac_date       : last date the contact appeared on a Mac (NULL if
--                         never)
--   last_seen_date      : last date the contact had any Mixpanel event
--   mac_event_count, total_events: raw counts in the 12mo window
--
-- Lineage (per parent task q5):
--   pc_stitch_db.mixpanel.export
--      ON __sdc_primary_key
--   ← core.fct_events
--      ON fct_events.session_id = dim_session_mapping.session_id_events
--   ← core.dim_session_mapping
--      ON dim_session_mapping.session_id = fct_sessions.session_id
--   ← core.fct_sessions  (filter to user_ids in q1's resolved_user_id IN-list)
--   ← TRY_CAST(fct_sessions.user_id AS NUMBER) joins dim_users.user_id
--     (fct_sessions.user_id is TEXT; can hold '$device:...' for anonymous
--     sessions — TRY_CAST drops those, which is correct here.)
----------------------------------------------------------------------
WITH list_members AS (
    SELECT lm.OBJECTID AS hubspot_vid
    FROM HUBSPOT_PLATFORM_DATA.V2_LIVE.LIST_MEMBERSHIPS lm
    WHERE lm.LISTID = 7935
)
, list_with_attrs AS (
    SELECT
           m.hubspot_vid
         , LOWER(c.PROPERTIES:email::string)                              AS email
         , c.PROPERTIES:firstname::string                                  AS firstname
         , c.PROPERTIES:lastname::string                                   AS lastname
         , TRY_CAST(c.PROPERTIES:soundstripe_user_id::string AS NUMBER)    AS soundstripe_user_id
         , c.PROPERTIES:subscription_type__core_type_::string              AS subscription_core_type
         , c.PROPERTIES:subscription_status::string                        AS subscription_status
         , c.PROPERTIES:hs_lead_status::string                             AS hs_lead_status
         , c.PROPERTIES:company::string                                    AS company
    FROM      list_members                              m
    LEFT JOIN SOUNDSTRIPE_PROD.HUBSPOT.HUBSPOT_CONTACTS c
           ON m.hubspot_vid = c.OBJECT_ID
)
, list_with_user_id AS (
    SELECT
           l.hubspot_vid
         , l.email
         , l.firstname
         , l.lastname
         , l.soundstripe_user_id
         , l.subscription_core_type
         , l.subscription_status
         , l.hs_lead_status
         , l.company
         , COALESCE(du_vid.user_id, du_uid.user_id, du_email.user_id)      AS resolved_user_id
         , CASE
               WHEN du_vid.user_id   IS NOT NULL THEN 'hubspot_vid'
               WHEN du_uid.user_id   IS NOT NULL THEN 'soundstripe_user_id'
               WHEN du_email.user_id IS NOT NULL THEN 'email'
               ELSE 'none'
           END                                                              AS bridge_path
    FROM      list_with_attrs                          l
    LEFT JOIN SOUNDSTRIPE_PROD.CORE.DIM_USERS          du_vid
           ON du_vid.HUBSPOT_CONTACT_VID = l.hubspot_vid
    LEFT JOIN SOUNDSTRIPE_PROD.CORE.DIM_USERS          du_uid
           ON du_uid.USER_ID = l.soundstripe_user_id
          AND du_vid.user_id IS NULL
    LEFT JOIN SOUNDSTRIPE_PROD.CORE.DIM_USERS          du_email
           ON LOWER(du_email.EMAIL) = l.email
          AND du_vid.user_id IS NULL
          AND du_uid.user_id IS NULL
)
, sessions_in_window AS (
    SELECT
           s.session_id
         , TRY_CAST(s.user_id AS NUMBER)                                AS user_id_num
    FROM SOUNDSTRIPE_PROD.CORE.FCT_SESSIONS s
    WHERE s.session_started_at >= '2025-05-01'
      AND s.session_started_at <  '2026-05-01'
      AND TRY_CAST(s.user_id AS NUMBER) IN (
            SELECT resolved_user_id FROM list_with_user_id WHERE resolved_user_id IS NOT NULL
          )
)
, events_bridged AS (
    SELECT
           siw.user_id_num                          AS user_id
         , fe.__sdc_primary_key
         , fe.event_ts
    FROM      sessions_in_window                            siw
    INNER JOIN SOUNDSTRIPE_PROD.CORE.DIM_SESSION_MAPPING    dsm
            ON siw.session_id = dsm.session_id
    INNER JOIN SOUNDSTRIPE_PROD.CORE.FCT_EVENTS             fe
            ON dsm.session_id_events = fe.session_id
    WHERE fe.event_ts >= '2025-05-01'
      AND fe.event_ts <  '2026-05-01'
)
, events_with_os AS (
    SELECT
           eb.user_id
         , mx.mp_reserved_os
         , mx.time AS mx_event_time
    FROM      events_bridged                  eb
    INNER JOIN pc_stitch_db.mixpanel.export   mx
            ON eb.__sdc_primary_key = mx.__sdc_primary_key
    WHERE mx.time::date >= '2025-05-01'
      AND mx.time::date <  '2026-05-01'
)
, os_per_user AS (
    SELECT
           user_id
         , COALESCE(BOOLOR_AGG(mp_reserved_os IN ('Mac', 'Mac OS X')), FALSE)  AS ever_used_mac
         , COUNT_IF(mp_reserved_os IN ('Mac', 'Mac OS X'))                     AS mac_event_count
         , COUNT(*)                                                            AS total_events
         , MAX(mx_event_time)::date                                            AS last_seen_date
         , MAX_BY(mp_reserved_os, mx_event_time)                               AS most_recent_os
         , MAX_BY(CASE WHEN mp_reserved_os IN ('Mac','Mac OS X') THEN mx_event_time END,
                  CASE WHEN mp_reserved_os IN ('Mac','Mac OS X') THEN mx_event_time END)::date AS last_mac_date
    FROM events_with_os
    GROUP BY 1
)
SELECT
       l.hubspot_vid
     , l.email
     , l.firstname
     , l.lastname
     , l.soundstripe_user_id
     , l.subscription_core_type
     , l.subscription_status
     , l.hs_lead_status
     , l.company
     , l.bridge_path
     , l.resolved_user_id
     , CASE
           WHEN l.resolved_user_id IS NULL                THEN 'NO_SS_ACCOUNT'
           WHEN m.user_id IS NULL                         THEN 'NO_DATA_12MO'
           WHEN m.ever_used_mac                           THEN 'MAC'
           ELSE                                                'NON_MAC'
       END                                            AS mac_classification
     , m.most_recent_os
     , m.last_seen_date
     , m.last_mac_date
     , m.mac_event_count
     , m.total_events
FROM      list_with_user_id   l
LEFT JOIN os_per_user         m
       ON l.resolved_user_id = m.user_id
ORDER BY mac_classification, l.subscription_core_type DESC NULLS LAST, l.lastname, l.firstname;


----------------------------------------------------------------------
-- q3: audit — Mac classification distribution (12-month window).
--
-- Result on 2026-05-01:
--   MAC            56  (57.7%)
--   NON_MAC        19  (19.6%)
--   NO_DATA_12MO    9   (9.3%)
--   NO_SS_ACCOUNT  12  (12.4%)   -- verified leads with no Soundstripe presence
--   Total          97
--
-- Compare to 30-day window (the original recent-only cut):
--   MAC                  37  (38.1%)
--   NON_MAC              18  (18.6%)
--   NO_RECENT_ACTIVITY   30  (30.9%)
--   UNKNOWN              12  (12.4%)
--
-- Net effect of the 12-month widening: +19 contacts moved from
-- "NO_RECENT_ACTIVITY" to "MAC" (true historical Mac users with no events
-- in the last 30 days), +1 to NON_MAC, and the residual 9 contacts have
-- not used Soundstripe at all in the past year.
----------------------------------------------------------------------


----------------------------------------------------------------------
-- q4: diligence — verify the 12 NO_SS_ACCOUNT contacts are not Soundstripe
--     users via any alternate identifier path. Triggered by stakeholder
--     pushback ("Dave built this list from active paid subscribers /
--     enterprise contacts — the 12 unknowns shouldn't exist").
--
-- Match attempts run, all returning 0 hits for all 12 contacts:
--   1. dim_users.HUBSPOT_CONTACT_VID = list_member.OBJECTID
--   2. dim_users.USER_ID = HubSpot custom property soundstripe_user_id
--   3. dim_users.EMAIL  = HubSpot PROPERTIES:email (LOWER on both sides)
--   4. dim_users.HUBSPOT_CONTACT_VID IN (split of hs_all_contact_vids)
--   5. pc_stitch_db.soundstripe.users.EMAIL = HubSpot PROPERTIES:email
--      (raw upstream of dim_users; 1.7M rows, ~370 broader than dim_users)
--
-- HubSpot-side evidence corroborating: of the 12 NO_SS_ACCOUNT contacts,
--   10 have lifecyclestage = 'lead' (not 'customer')
--    1 (Len Turner) has lifecyclestage = '262492257' (Customer) but is an
--      enterprise sales prospect, NO chargebee_customer_id, NO stripe id,
--      NO subscription_type — likely tagged in HubSpot ahead of close
--    1 (Jacquie Vercollone) lifecyclestage = '262492257', same pattern
--   12/12 have NULL chargebee_customer_id, stripe_customer_id, subscription_type
--   12/12 have NULL/empty additional_emails and hs_additional_emails
--
-- Conclusion: list 7935 is NOT strictly active paid subscribers. It contains
-- (a) 56 Mac users with Soundstripe activity in 12mo, (b) 19 non-Mac active
-- users, (c) 9 dormant Soundstripe users (>12mo since last event), (d) 12
-- HubSpot-only leads with no Soundstripe account. Sales-side context (e.g.,
-- Dave's exact list-construction filter) needed to determine whether the 12
-- leads were intentionally included.
----------------------------------------------------------------------


----------------------------------------------------------------------
-- §1 RATE — Mac fraction of list 7935
----------------------------------------------------------------------
-- RATE: mac_fraction_of_list_7935
-- NUMERATOR:   contacts with mac_classification = 'MAC' (any Mac event in 12mo)
-- DENOMINATOR: ALL list 7935 contacts (97), regardless of Soundstripe presence
-- TYPE:        list_contacts_on_mac / list_contacts_total
-- NOT:         do not denominate by "Soundstripe-active users only" — would
--              inflate the rate by silently dropping NO_DATA_12MO and UNKNOWN;
--              Dave targets the FULL list, not just the Mixpanel-active subset.
--
-- TYPE AUDIT — q2:
--   Declared denominator: all list 7935 contacts (97)
--   JOIN chain: list_members → LEFT JOIN hubspot_contacts → LEFT JOIN dim_users (3x) → LEFT JOIN os_per_user
--   Column used as denominator: list_members.hubspot_vid (97 rows preserved by all LEFT JOINs)
--   Does JOIN type enforce declared denominator?  YES — every LEFT JOIN preserves
--   the full 97-row list_members population; os_per_user being NULL is what
--   produces the NO_DATA_12MO / UNKNOWN buckets, not row attrition.
--   RESULT: PASS
