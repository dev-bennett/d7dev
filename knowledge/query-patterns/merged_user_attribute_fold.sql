-- PURPOSE:       Attach per-event Mixpanel attributes (OS, user_agent, scroll, plan, etc.)
--                to merged-user identity at a NO-FAN-OUT (one-row-per-user) grain. Solves
--                the recurring "tag every merged user with a flag/attribute derived from
--                their events in a window" problem.
-- TABLES:        pc_stitch_db.mixpanel.export, soundstripe_prod.core.fct_events,
--                soundstripe_prod.core.dim_session_mapping, soundstripe_prod.core.fct_sessions
-- PARAMETERS:    :start_date, :end_date (event/session window — apply to ALL four tables)
-- PRIOR USES:    analysis/experimentation/2026-04-18-wcpm-test-audit/ — identity reconciliation
--                analysis/adhoc/2026-04-30-mixpanel-mac-os-validation/console.sql q5 — Mac flag × subscriber status
-- RATE BLOCK:    n/a (population template — layer rate logic on top)
-- LAST UPDATED:  2026-04-30
-- RELATED:       knowledge/query-patterns/session_event_bridge.sql (the skeleton bridge);
--                this pattern extends it with raw-Mixpanel attribute pull + per-user fold.
--                memory: reference_session_event_join, project_wcpm_1to1_mapping_exclusion
--                calibration: core__fct_sessions §3a (anonymous distinct_id sprawl post-2026-03-16),
--                             pc_stitch_db__mixpanel__export (columns dropped from fct_events)


-- WHY THIS PATTERN EXISTS
--
-- Three failure modes this pattern eliminates by construction:
--
-- 1. FAN-OUT. Joining mixpanel.export → fct_events → bridge → fct_sessions and then
--    GROUPing BY distinct_id without folding produces N rows per user (one per event).
--    A user with 1,000 events appears as 1,000 rows. Any downstream COUNT(*) or
--    SUM is multiplied. Fold per-event attributes into per-user aggregates BEFORE
--    you cross-tab or count.
--
-- 2. WRONG GRAIN. fct_events.distinct_id is the RAW Mixpanel device ID. fct_sessions.distinct_id
--    is the CONSOLIDATED profile_id (post-www↔app identity stitching). For "how many
--    distinct humans," use fct_sessions.distinct_id. For "device-level attribution,"
--    use fct_events.distinct_id. They are different populations and the gap widened
--    after the 2026-03-16 domain-consolidation cutover (anonymous sprawl, see
--    fct_sessions calibration §3a).
--
-- 3. MISSING ATTRIBUTES. core.fct_events DROPS columns from the raw export:
--    USER_AGENT, USER_IP, MP_LIB, MP_RESERVED_SCREEN_*, MP_RESERVED_INITIAL_REFERRER,
--    MP_RESERVED_PAGEY/PAGEHEIGHT, MP_RESERVED_MAX_SCROLL_PERCENTAGE, and all
--    spatial autocapture / replay properties. mp_reserved_os IS retained on
--    fct_events but mp_reserved_browser, device, screen_*, etc. are NOT. If you
--    need ANY of these, you MUST go back to pc_stitch_db.mixpanel.export and
--    join on __sdc_primary_key (1:1).


-- LINEAGE
--
-- pc_stitch_db.mixpanel.export
--   ON __sdc_primary_key (1:1)
-- → soundstripe_prod.core.fct_events
--   ON fct_events.session_id = dim_session_mapping.session_id_events (M:1)
-- → soundstripe_prod.core.dim_session_mapping
--   ON dim_session_mapping.session_id = fct_sessions.session_id (M:1 raw → consolidated)
-- → soundstripe_prod.core.fct_sessions
--   merged identity = fct_sessions.distinct_id (consolidated profile_id, NOT raw Mixpanel distinct_id)
--   authenticated identity = fct_sessions.user_id (NULL for anonymous)


-- ===================================================================
-- TEMPLATE — copy and adapt the per-user aggregates inside `per_user`
-- ===================================================================

WITH sessions_in_window AS (
    -- 1) Population: merged-user sessions in window. Drives the LEFT side of
    --    every downstream join. Filter early — fct_sessions is small (~42M rows).
    SELECT
           s.session_id
         , s.distinct_id            AS merged_distinct_id   -- consolidated profile_id
         , s.user_id                AS session_user_id      -- NULL for anonymous sessions
    FROM soundstripe_prod.core.fct_sessions s
    WHERE s.session_started_at >= :start_date
      AND s.session_started_at <  :end_date
      AND s.distinct_id IS NOT NULL                          -- defensive — model already filters this
)

, events_bridged AS (
    -- 2) fct_sessions.session_id → dim_session_mapping.session_id_events → fct_events.session_id
    --    Always INNER JOIN — events without a session entry are not part of the population.
    SELECT
           siw.merged_distinct_id
         , siw.session_user_id
         , fe.__sdc_primary_key
         , fe.event_ts
         , fe.event
         , fe.url
         , fe.distinct_id           AS fct_events_distinct_id   -- raw Mixpanel device id
         , fe.user_id               AS fct_events_user_id
    FROM       sessions_in_window                       siw
    INNER JOIN soundstripe_prod.core.dim_session_mapping dsm
            ON siw.session_id = dsm.session_id
    INNER JOIN soundstripe_prod.core.fct_events         fe
            ON dsm.session_id_events = fe.session_id
    WHERE fe.event_ts >= :start_date
      AND fe.event_ts <  :end_date
)

, events_with_attrs AS (
    -- 3) Pull raw-only attributes from pc_stitch_db.mixpanel.export.
    --    1:1 join on __sdc_primary_key. ALWAYS date-scope mixpanel.export
    --    independently — it's the 2.18B-row raw table and partition pruning
    --    requires the predicate locally even though logically redundant.
    SELECT
           e.merged_distinct_id
         , e.session_user_id
         , e.fct_events_user_id
         , e.event_ts
         , e.event
         , e.url
         -- Add whichever raw-only or shared attributes you need:
         , mx.mp_reserved_os
         , mx.mp_reserved_browser
         , mx.mp_reserved_device
         , mx.user_agent
         , mx.user_ip
         , mx.mp_lib
         , mx.mp_reserved_initial_referrer
         , mx.mp_reserved_max_scroll_percentage     -- BROKEN since 2026-02-25 on pricing URLs
         , mx.current_plan_id
         , mx.current_plan_name
         , mx.user_id                AS mx_user_id
    FROM       events_bridged                       e
    INNER JOIN pc_stitch_db.mixpanel.export         mx
            ON e.__sdc_primary_key = mx.__sdc_primary_key
    WHERE mx.time::date >= :start_date
      AND mx.time::date <  :end_date
)

, per_user AS (
    -- 4) FOLD per-event attributes to per-user grain. ONE ROW PER MERGED USER
    --    AFTER THIS CTE. Add/remove aggregates inside this block — the rest of
    --    the template stays the same.
    --
    --    Snowflake aggregate cheat-sheet for this fold:
    --      BOOLOR_AGG(<bool expr>)        — TRUE if ANY row matches, else FALSE/NULL
    --      BOOLAND_AGG(<bool expr>)       — TRUE only if ALL rows match
    --      MAX_BY(<col>, <order_col>)     — value of <col> at the row with the max <order_col>
    --      MIN_BY(<col>, <order_col>)     — value of <col> at the row with the min <order_col>
    --      COUNT_IF(<bool expr>)          — count of rows where <bool expr> is TRUE
    --      ARRAY_UNIQUE_AGG(<col>)        — distinct values list (small cardinalities only)
    --
    --    NOT BOOL_OR — Snowflake's name is BOOLOR_AGG. PyCharm linter does not
    --    fully recognize Snowflake-specific aggregates; warnings are usually
    --    false-positives but worth wrapping boolean OR-chains in parens to help.
    SELECT
           merged_distinct_id

         -- Boolean "ever did X" flags (NO FAN-OUT) — example: device usage
         , COALESCE(BOOLOR_AGG(mp_reserved_os IN ('Mac', 'Mac OS X')), FALSE)         AS used_mac
         , COALESCE(BOOLOR_AGG(mp_reserved_os = 'Windows'), FALSE)                    AS used_windows
         , COALESCE(BOOLOR_AGG(mp_reserved_os IN ('iOS', 'iPadOS')), FALSE)           AS used_ios

         -- Identity flags
         , BOOLOR_AGG((session_user_id IS NOT NULL) OR (mx_user_id IS NOT NULL))     AS ever_authenticated

         -- "Most-recent observed" attributes (snapshot semantics)
         , MAX_BY(current_plan_id,   event_ts)                                        AS latest_plan_id
         , MAX_BY(current_plan_name, event_ts)                                        AS latest_plan_name
         , MAX_BY(COALESCE(session_user_id, mx_user_id), event_ts)                    AS latest_user_id

         -- Counts
         , COUNT(*)                                                                   AS event_count
         , COUNT_IF(mp_reserved_os IN ('Mac', 'Mac OS X'))                            AS mac_event_count

         -- Window bounds
         , MIN(event_ts)                                                              AS first_event_ts
         , MAX(event_ts)                                                              AS last_event_ts
    FROM events_with_attrs
    GROUP BY 1
)

-- 5) Use the per_user CTE for crosstabs, list joins, exports — one row per merged user.
SELECT
       merged_distinct_id
     , latest_user_id
     , used_mac
     , ever_authenticated
     , latest_plan_id
     , latest_plan_name
     , event_count
FROM per_user
;


-- ===================================================================
-- COMMON ADAPTATIONS
-- ===================================================================
--
-- A) "Just give me the population that used a Mac in window X."
--      → Add WHERE used_mac in the final SELECT. The fold already captured it.
--
-- B) "Cross with subscriber status (anonymous / free / self_serve / enterprise)."
--      → Wrap per_user in a `classified` CTE with a CASE on (ever_authenticated,
--        latest_plan_id, latest_plan_name). Validate the enterprise pattern with
--        a discovery query (top current_plan_name × user_count) before relying
--        on the count.
--
-- C) "Join against an external user list (Dave's beta target list, etc.)."
--      → Join on the appropriate identifier:
--        - latest_user_id            (authenticated app user_id; preferred when list has it)
--        - merged_distinct_id        (anonymous-inclusive merged identity)
--        DO NOT join on fct_events.distinct_id — that's device-grain.
--
-- D) "Need scroll depth / click position / user_agent / IP."
--      → Already pulled from mixpanel.export above. Note autocapture spatial
--        properties (mp_reserved_pagey, max_scroll_percentage) BROKEN on pricing
--        URLs from 2026-02-25 onward (project_mixpanel_autocapture_collapse_open).
--
-- E) "Wider window — last 30 days instead of 7."
--      → Replace :start_date / :end_date. fct_sessions and dim_session_mapping
--        scale linearly; the fct_events × mixpanel.export join is the cost
--        driver. Date-scope BOTH sides; do not skip the mx.time::date predicate.


-- ===================================================================
-- COST PROFILE (X-Small DATA_SCIENCE warehouse)
-- ===================================================================
--
-- Estimated cost for a 7-day window with the full template above:
--   - fct_sessions filter:                ~1-2 GB scanned, < 5s
--   - dim_session_mapping bridge:         ~5-10 GB, ~10s
--   - fct_events 7-day pull:              ~30-50M rows, ~30-60s
--   - mixpanel.export 7-day join:         ~30-50M rows, ~30-60s
--   - Per-user fold (GROUP BY):           ~5-15s
--   Total: ~2-3 minutes on X-Small for 7-day; scales roughly linearly for longer windows.
--   30-day window approaches the 2-minute MCP discipline ceiling — split into
--   pre-aggregated daily snapshots if needed, or escalate to a dbt mart.


-- ===================================================================
-- JOIN-TYPE DISCIPLINE (sql-snowflake.md §1)
-- ===================================================================
--
-- Every JOIN in this template is INNER. The denominator IS the merged-user
-- population in fct_sessions for the window. Switching any join to LEFT
-- changes the population — for example, a LEFT JOIN to fct_events would
-- include sessions with NO matching events, which is impossible by
-- construction (sessions are derived from events) but would break the fold's
-- assumptions if it ever returned a row.
--
-- If you need a different denominator (e.g., "all authenticated users," not
-- "all users with sessions in window"), START with the right driving table
-- (dim_users) and bridge IN to events. Do NOT flip a LEFT JOIN to INNER
-- after the fact.
