-- Purpose:    Validate device/OS-level data in pc_stitch_db.mixpanel.export to
--             distinguish Mac (desktop macOS) users.
-- Author:     Devon Bennett (drafted with assistant)
-- Date:       2026-04-30
-- Source:     pc_stitch_db.mixpanel.export (raw Mixpanel export; device/OS
--             columns are NOT carried into core.fct_events).
-- Window:     2026-04-22 to 2026-04-28 (7 days, full UTC days), unless noted.
-- Cost:       X-Small DATA_SCIENCE; date-scoped; <$0.05 total expected.


----------------------------------------------------------------------
-- q1: Schema discovery — device/OS-shaped columns in the raw export.
----------------------------------------------------------------------
SELECT
     column_name
   , data_type
   , ordinal_position
FROM pc_stitch_db.information_schema.columns
WHERE table_schema = 'MIXPANEL'
  AND table_name   = 'EXPORT'
  AND (
       column_name ILIKE '%OS%'
    OR column_name ILIKE '%DEVICE%'
    OR column_name ILIKE '%BROWSER%'
    OR column_name ILIKE '%PLATFORM%'
    OR column_name ILIKE '%USER_AGENT%'
    OR column_name ILIKE '%MODEL%'
    OR column_name ILIKE '%MAC%'
  )
ORDER BY ordinal_position
;


----------------------------------------------------------------------
-- q2: Fill rates for OS / device / browser / platform columns
--     across a 7-day event window. Aggregate-only — single row.
----------------------------------------------------------------------
WITH base AS (
    SELECT *
    FROM pc_stitch_db.mixpanel.export
    WHERE time::date >= '2026-04-22'
      AND time::date <  '2026-04-29'
)
SELECT
       COUNT(*)                                  AS row_count
     , COUNT(DISTINCT distinct_id)               AS distinct_users
     , COUNT(mp_reserved_os)                     AS fill_mp_reserved_os
     , COUNT(mp_reserved_browser)                AS fill_mp_reserved_browser
     , COUNT(mp_reserved_device)                 AS fill_mp_reserved_device
     , COUNT(user_agent)                         AS fill_user_agent
     , COUNT(mp_reserved_user_agent)             AS fill_mp_reserved_user_agent
     , COUNT(platform)                           AS fill_platform
     , COUNT(mobile_app_os)                      AS fill_mobile_app_os
     , COUNT(source_platform)                    AS fill_source_platform
     , COUNT(host_application)                   AS fill_host_application
FROM base
;


----------------------------------------------------------------------
-- q3: OS-value distribution at the user grain.
--     Pick each user's modal mp_reserved_os, then GROUP BY.
--     This is the headline validation query — one row per OS label,
--     with user count and share.
----------------------------------------------------------------------
WITH user_os AS (
    SELECT
           distinct_id
         , mp_reserved_os
         , COUNT(*) AS event_count
    FROM pc_stitch_db.mixpanel.export
    WHERE time::date >= '2026-04-22'
      AND time::date <  '2026-04-29'
      AND mp_reserved_os IS NOT NULL
    GROUP BY 1, 2
    QUALIFY ROW_NUMBER() OVER (
                PARTITION BY distinct_id
                ORDER BY event_count DESC
            ) = 1
)
SELECT
       mp_reserved_os
     , COUNT(*)                                                AS user_count
     , ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)      AS pct_of_users
FROM user_os
GROUP BY 1
ORDER BY user_count DESC
;


----------------------------------------------------------------------
-- q4: User-agent spot-check for the two macOS labels
--     ('Mac' and 'Mac OS X') to confirm both map to desktop macOS.
--     Single-day window keeps the result small.
----------------------------------------------------------------------
SELECT
       mp_reserved_os
     , SUBSTR(user_agent, 1, 200) AS ua_sample
     , COUNT(*)                   AS n
FROM pc_stitch_db.mixpanel.export
WHERE time::date = '2026-04-28'
  AND mp_reserved_os IN ('Mac', 'Mac OS X')
  AND user_agent IS NOT NULL
GROUP BY 1, 2
QUALIFY ROW_NUMBER() OVER (PARTITION BY mp_reserved_os ORDER BY n DESC) <= 3
ORDER BY mp_reserved_os, n DESC
;


----------------------------------------------------------------------
-- q5: Per-merged-user Mac usage × subscriber status. NO FAN-OUT —
--     one row per merged user, with a boolean used_mac flag.
--
-- Grain: fct_sessions.distinct_id (= consolidated profile_id post
-- www↔app identity stitching, NOT the raw Mixpanel distinct_id). This
-- is the merged-user identity column — see core__fct_sessions
-- calibration §Columns and §Grain.
--
-- Lineage (per user instruction, 2026-04-30):
--   pc_stitch_db.mixpanel.export
--      ON __sdc_primary_key
--   → core.fct_events
--      ON fct_events.session_id = dim_session_mapping.session_id_events
--   → core.dim_session_mapping
--      ON dim_session_mapping.session_id = fct_sessions.session_id
--   → core.fct_sessions  (merged identity = .distinct_id)
--   → filter to sessions in window
--   → fold per-event mp_reserved_os into per-user BOOL_OR
--
-- used_mac: TRUE if ANY event for this merged user in the window
--           carried mp_reserved_os IN ('Mac','Mac OS X'); else FALSE.
--           A Mac-and-Windows user collapses to one row, used_mac=TRUE.
--
-- subscriber_status: from the most-recent observed current_plan in the
-- window's events for this merged user (snapshot semantics — matches
-- Dave's state-driven invite use case).
--
-- Caveats:
--   1. Enterprise bucket uses ILIKE on plan_name / plan_id. Validate
--      against q5a (below) before citing the enterprise count.
--   2. CURRENT_PLAN_ID uses the literal string 'None' for no-plan;
--      SQL NULL and 'None' are both treated as "no plan" here.
--   3. Anonymous distinct_id sprawl post-2026-03-16 (cookie-scope/SDK
--      changes at domain-consolidation cutover) inflates the
--      anonymous bucket. Authenticated users (the bucket Dave cares
--      about for the beta) are insulated. See core__fct_sessions
--      calibration §3a.
----------------------------------------------------------------------
WITH sessions_in_window AS (
    SELECT
           s.session_id
         , s.distinct_id            AS merged_distinct_id
         , s.user_id                AS session_user_id
    FROM soundstripe_prod.core.fct_sessions s
    WHERE s.session_started_at >= '2026-04-22'
      AND s.session_started_at <  '2026-04-29'
      AND s.distinct_id IS NOT NULL
)
, events_bridged AS (
    -- fct_sessions.session_id → dim_session_mapping → fct_events
    SELECT
           siw.merged_distinct_id
         , siw.session_user_id
         , fe.__sdc_primary_key
         , fe.event_ts
    FROM      sessions_in_window                       siw
    INNER JOIN soundstripe_prod.core.dim_session_mapping dsm
            ON siw.session_id = dsm.session_id
    INNER JOIN soundstripe_prod.core.fct_events         fe
            ON dsm.session_id_events = fe.session_id
    WHERE fe.event_ts >= '2026-04-22'
      AND fe.event_ts <  '2026-04-29'
)
, events_with_attrs AS (
    -- fct_events → mixpanel.export for OS + plan attributes
    -- (mp_reserved_os and current_plan_* live on the raw export only)
    SELECT
           e.merged_distinct_id
         , e.session_user_id
         , e.event_ts
         , mx.mp_reserved_os
         , mx.current_plan_id
         , mx.current_plan_name
         , mx.user_id                AS mx_user_id
    FROM      events_bridged                       e
    INNER JOIN pc_stitch_db.mixpanel.export        mx
            ON e.__sdc_primary_key = mx.__sdc_primary_key
    WHERE mx.time::date >= '2026-04-22'
      AND mx.time::date <  '2026-04-29'
)
, per_user AS (
    -- Fold per-event attributes into per-user aggregates. NO FAN-OUT
    -- past this CTE — one row per merged user.
    SELECT
           merged_distinct_id
         , COALESCE(BOOLOR_AGG(mp_reserved_os IN ('Mac', 'Mac OS X')), FALSE) AS used_mac
         , BOOLOR_AGG((session_user_id IS NOT NULL) OR (mx_user_id IS NOT NULL)) AS ever_authenticated
         , MAX_BY(current_plan_id,   event_ts)                             AS latest_plan_id
         , MAX_BY(current_plan_name, event_ts)                             AS latest_plan_name
    FROM events_with_attrs
    GROUP BY 1
)
, classified AS (
    SELECT
           merged_distinct_id
         , used_mac
         , CASE
               WHEN NOT ever_authenticated                                          THEN 'anonymous'
               WHEN latest_plan_id IS NULL OR latest_plan_id = 'None'               THEN 'free_signed_in'
               WHEN COALESCE(latest_plan_name, '') ILIKE '%enterprise%'
                 OR COALESCE(latest_plan_id,   '') ILIKE '%enterprise%'             THEN 'enterprise'
               ELSE                                                                      'self_serve_paid'
           END AS subscriber_status
    FROM per_user
)
SELECT
       used_mac
     , subscriber_status
     , COUNT(*)                                                                     AS user_count
     -- Within-segment Mac rate: "what share of <subscriber_status> users used a Mac?"
     -- Read horizontally across used_mac=TRUE/FALSE for one subscriber_status — sums to 100%.
     , ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY subscriber_status), 2)
                                                                                     AS pct_within_subscriber_status
     -- Within-Mac segment mix: "of users who used a Mac, what's their subscriber-status mix?"
     -- Read vertically down rows for used_mac=TRUE — sums to 100%.
     , ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY used_mac), 2)
                                                                                     AS pct_within_used_mac
     -- Grand-total share (all four cells sum to 100%) — sanity / sizing only.
     , ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)                            AS pct_of_total
FROM classified
GROUP BY 1, 2
ORDER BY subscriber_status, used_mac DESC
;


----------------------------------------------------------------------
-- q5a: Discovery — distinct current_plan_name values in the window,
--      ranked by distinct_id count. Used to validate the 'enterprise'
--      ILIKE bucket in q5 before relying on its count.
--      Filters out the 'None' / NULL no-plan rows.
----------------------------------------------------------------------
WITH user_latest_plan AS (
    SELECT
           distinct_id
         , current_plan_id
         , current_plan_name
    FROM pc_stitch_db.mixpanel.export
    WHERE time::date >= '2026-04-22'
      AND time::date <  '2026-04-29'
    QUALIFY ROW_NUMBER() OVER (
                PARTITION BY distinct_id
                ORDER BY time DESC
            ) = 1
)
SELECT
       current_plan_name
     , current_plan_id
     , COUNT(*) AS user_count
FROM user_latest_plan
WHERE current_plan_id IS NOT NULL
  AND current_plan_id <> 'None'
GROUP BY 1, 2
ORDER BY user_count DESC
LIMIT 100
;


----------------------------------------------------------------------
-- Canonical filter for downstream Mac-cohort analyses
----------------------------------------------------------------------
-- WHERE mp_reserved_os IN ('Mac', 'Mac OS X')
--   AND time::date >= <start>
--   AND time::date <  <end>
--
-- Excludes: iOS (mobile), iPadOS (tablet), Android, Windows, Linux, Chrome OS.
