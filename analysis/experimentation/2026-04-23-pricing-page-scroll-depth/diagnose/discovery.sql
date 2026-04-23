-- =============================================================================
-- Purpose:       Discovery queries for pricing-page scroll-depth analysis
-- Task:          analysis/experimentation/2026-04-23-pricing-page-scroll-depth/
-- Author:        Devon Bennett
-- Date:          2026-04-23
-- Dependencies:  soundstripe_prod.core.fct_events
--                pc_stitch_db.mixpanel.export (raw source)
--                pc_stitch_db.information_schema.columns
-- Phase:         Phase 1 (discovery) per the task plan
--
-- Usage:         Run each labeled section as its own SELECT. Export each
--                result as d<N>.csv in this directory. One file, one labeled
--                query per feedback_one_sql_file_per_query_set.
--
-- GATE:          If D1+D2 cannot confirm event names for "Clicked View
--                Pricing" / "Selected Persona" and a scroll-depth property,
--                stop and escalate before writing the main console.sql.
-- =============================================================================


-- =============================================================================
-- D1: Distinct event names on /pricing during the pre-change baseline
-- -----------------------------------------------------------------------------
-- Question:      Which fct_events.event values fire on the pricing page during
--                the product team's baseline window? Settles the event names
--                for "Clicked View Pricing" and "Selected Persona".
-- Expected:      'Clicked Pricing Product' should be near the top (confirmed
--                by prior exploration). Unknown whether persona-card and
--                view-pricing events exist as distinct event names, or whether
--                they are distinguishable only via url/path/properties.
-- Export:        d1.csv
-- =============================================================================

SELECT
    event
  , COUNT(*)                      AS event_count
  , COUNT(DISTINCT distinct_id)   AS distinct_users
  , COUNT(DISTINCT session_id)    AS distinct_sessions
  , MIN(event_ts)                 AS first_seen
  , MAX(event_ts)                 AS last_seen
FROM soundstripe_prod.core.fct_events
WHERE page_category = 'pricing'
  AND event_ts::date BETWEEN '2026-01-07' AND '2026-02-06'
GROUP BY event
ORDER BY event_count DESC
;


-- =============================================================================
-- D1b: Element-identifying columns in the raw Mixpanel source
-- -----------------------------------------------------------------------------
-- Question:      D1 showed 'Clicked Element' at 69K events and 'Display
--                Element' at 917 events on the pricing path, but
--                'Clicked Pricing Product' fires only 2 times in the whole
--                baseline. The product team's "5,507 plan clicks",
--                "6,649 View Pricing clicks", "6,360 persona selections"
--                must be derived from Clicked Element properties (element
--                label / text / class / id). fct_events does not retain
--                these columns, so probe the raw source for element
--                identifiers.
-- Expected:      Columns like $element_id, $text, element_class,
--                element_label, TARGET_ELEMENT_*, PERSONA, or similar. If
--                zero matches, Clicked Element cannot distinguish View
--                Pricing vs Persona vs Plan clicks in our warehouse —
--                funnel is blocked and we escalate.
-- Export:        d1b.csv
-- =============================================================================

SELECT
    column_name
  , data_type
FROM pc_stitch_db.information_schema.columns
WHERE table_schema = 'MIXPANEL'
  AND table_name   = 'EXPORT'
  AND (
       column_name ILIKE '%element%'
    OR column_name ILIKE '%target%'
    OR column_name ILIKE '%selector%'
    OR column_name ILIKE '%text%'
    OR column_name ILIKE '%label%'
    OR column_name ILIKE '%button%'
    OR column_name ILIKE '%persona%'
    OR column_name ILIKE '%card%'
    OR column_name ILIKE '%cta%'
  )
ORDER BY column_name
;


-- =============================================================================
-- D2a: Scroll-related columns in the raw Mixpanel source
-- -----------------------------------------------------------------------------
-- Question:      What columns in pc_stitch_db.mixpanel.export are named with
--                scroll / depth / page_leave semantics? Needed because
--                fct_events filters out $mp_page_leave (stg_events.sql line
--                90), where scroll properties commonly live.
-- Result:        MP_RESERVED_MAX_SCROLL_PERCENTAGE,
--                MP_RESERVED_MAX_SCROLL_VIEW_DEPTH,
--                MP_RESERVED_SCROLL_HEIGHT — all TEXT. D2c uses the %
--                column as the primary measure.
-- Export:        d2a.csv
-- =============================================================================

SELECT
    column_name
  , data_type
FROM pc_stitch_db.information_schema.columns
WHERE table_schema = 'MIXPANEL'
  AND table_name   = 'EXPORT'
  AND (
       column_name ILIKE '%scroll%'
    OR column_name ILIKE '%depth%'
    OR column_name ILIKE '%page_leave%'
    OR column_name ILIKE '%pct%'
  )
ORDER BY column_name
;


-- =============================================================================
-- D2b: Scroll-dedicated event names in the raw Mixpanel source
-- -----------------------------------------------------------------------------
-- Question:      Are there events with "scroll" in the event name (e.g.,
--                "Scrolled", "Page Scrolled", "$mp_page_leave")? These may
--                carry scroll depth even if no dedicated column exists.
-- Expected:      $mp_page_leave fires on every page navigation and may carry
--                scroll_depth as a property. If Soundstripe ships a custom
--                scroll event, it appears here.
-- Export:        d2b.csv
-- =============================================================================

SELECT
    event
  , COUNT(*)                      AS event_count
  , COUNT(DISTINCT distinct_id)   AS distinct_users
FROM pc_stitch_db.mixpanel.export
WHERE time::date BETWEEN '2026-01-07' AND '2026-02-06'
  AND (
       event ILIKE '%scroll%'
    OR event = '$mp_page_leave'
  )
GROUP BY event
ORDER BY event_count DESC
;


-- =============================================================================
-- D2c: Scroll-property coverage by event on the pricing path (raw source)
-- -----------------------------------------------------------------------------
-- Question:      On which events does MP_RESERVED_MAX_SCROLL_PERCENTAGE
--                actually populate when the event URL is the pricing page?
-- Expected:      $mp_page_leave should carry the property on every pricing
--                session-end; other events may be null or sparsely populated.
--                Also returns the numeric range (column is TEXT — cast for
--                avg/max).
-- Export:        d2c.csv
-- =============================================================================

SELECT
    event
  , COUNT(*)                                                                            AS event_count
  , COUNT_IF(mp_reserved_max_scroll_percentage IS NOT NULL)                             AS with_scroll
  , MIN(TRY_CAST(mp_reserved_max_scroll_percentage AS FLOAT))                           AS min_scroll_pct
  , AVG(TRY_CAST(mp_reserved_max_scroll_percentage AS FLOAT))                           AS avg_scroll_pct
  , MAX(TRY_CAST(mp_reserved_max_scroll_percentage AS FLOAT))                           AS max_scroll_pct
FROM pc_stitch_db.mixpanel.export
WHERE time::date BETWEEN '2026-01-07' AND '2026-02-06'
  AND PARSE_URL(COALESCE(current_url, mp_reserved_current_url, url)):path::string = 'pricing'
GROUP BY event
ORDER BY event_count DESC
;


-- =============================================================================
-- D3: Clicked Pricing Product — plan_id / plan_name distribution
-- -----------------------------------------------------------------------------
-- Question:      Confirm the plan_id / plan_name populations that back the
--                plan-level funnel step.
-- Expected:      Top plans should include Pro Yearly, Pro Monthly, Creator
--                Yearly/Monthly, Pro+ Y/M, Enterprise Business Q/Y (per
--                product team analysis).
-- Export:        d3.csv
-- =============================================================================

SELECT
    plan_id
  , plan_name
  , COUNT(*)                      AS click_count
  , COUNT(DISTINCT distinct_id)   AS distinct_users
  , COUNT(DISTINCT session_id)    AS distinct_sessions
FROM soundstripe_prod.core.fct_events
WHERE event = 'Clicked Pricing Product'
  AND event_ts::date BETWEEN '2026-01-07' AND '2026-02-06'
GROUP BY plan_id, plan_name
ORDER BY click_count DESC
;


-- =============================================================================
-- D4: Sign Up / Sign In event enumeration
-- -----------------------------------------------------------------------------
-- Question:      What event names fire on the signup / sign-in pages? The
--                product team references "Sign Up Form view", "Signed Up",
--                and "Signed In" — need to confirm the exact strings.
-- Export:        d4.csv
-- =============================================================================

SELECT
    page_category
  , event
  , COUNT(*)                      AS event_count
  , COUNT(DISTINCT distinct_id)   AS distinct_users
FROM soundstripe_prod.core.fct_events
WHERE page_category IN ('signup', 'sign in')
  AND event_ts::date BETWEEN '2026-01-07' AND '2026-02-06'
GROUP BY page_category, event
ORDER BY event_count DESC
;


-- =============================================================================
-- D5: Daily pricing-page visitor counts — baseline through today
-- -----------------------------------------------------------------------------
-- Question:      What does the daily volume of pricing-page sessions and
--                distinct_ids look like from Jan 1 to today? Locates
--                contamination windows empirically and sizes the denominator
--                for each comparison window.
-- Expected:      ~500/day baseline per product team. Watch for the
--                Mar 5 – Mar 25 inflation window (confirmed ~200K artifact
--                sessions during domain-consolidation rollout). Also watch
--                for 2026-04-13+ elevation (OPEN direct-traffic spike).
-- Export:        d5.csv
-- =============================================================================

SELECT
    event_ts::date                AS event_date
  , COUNT(DISTINCT session_id)    AS pricing_sessions
  , COUNT(DISTINCT distinct_id)   AS pricing_distinct_ids
  , COUNT(*)                      AS pricing_events
FROM soundstripe_prod.core.fct_events
WHERE page_category = 'pricing'
  AND event_ts::date BETWEEN '2026-01-01' AND '2026-04-23'
GROUP BY event_date
ORDER BY event_date
;


-- =============================================================================
-- D6: Where did the pricing-page traffic go? (event-name + URL probe)
-- -----------------------------------------------------------------------------
-- Question:      D5 showed pricing_distinct_ids collapse from ~400–870/day
--                to 1–4/day starting 2026-03-17. The `Viewed Pricing Page`
--                event name is durable across URL changes. Count daily
--                `Viewed Pricing Page` events regardless of page_category.
--                If the event-level count stays healthy but page_category
--                drops, the bug is in fct_events' path-matching classifier
--                (stg_events.sql line 117). If the event-level count also
--                drops, the issue is upstream (Mixpanel SDK, tracking plan,
--                or actual traffic).
-- Expected:      If healthy: we recover the post-8wk window by using
--                event='Viewed Pricing Page' as the visitor gate instead
--                of page_category='pricing'. If collapsed: the cause is
--                deeper and escalation to engineering follows.
-- Export:        d6.csv
-- =============================================================================

SELECT
    event_ts::date                AS event_date
  , COUNT(DISTINCT session_id)    AS sessions_with_pricing_event
  , COUNT(DISTINCT distinct_id)   AS distinct_users_with_pricing_event
  , COUNT(*)                      AS pricing_events
FROM soundstripe_prod.core.fct_events
WHERE event = 'Viewed Pricing Page'
  AND event_ts::date BETWEEN '2026-01-01' AND '2026-04-23'
GROUP BY event_date
ORDER BY event_date
;


-- =============================================================================
-- D7: Pricing URL drift — path/host distribution for Viewed Pricing Page
-- -----------------------------------------------------------------------------
-- Question:      For the `Viewed Pricing Page` event, what path and host
--                values dominate across the pre (Jan 7 – Feb 6), rollout
--                (Mar 5 – Mar 25), and post-rollout (Mar 26 – Apr 23)
--                windows? If the path string shifts away from exactly
--                'pricing' in March, that explains the page_category
--                classifier break and gives us the post-change URL.
-- Export:        d7.csv
-- =============================================================================

SELECT
    CASE
        WHEN event_ts::date BETWEEN '2026-01-07' AND '2026-02-06' THEN '1_pre'
        WHEN event_ts::date BETWEEN '2026-03-05' AND '2026-03-25' THEN '2_rollout'
        WHEN event_ts::date BETWEEN '2026-03-26' AND '2026-04-23' THEN '3_post_rollout'
        ELSE '9_other'
    END                           AS window_label
  , host
  , path
  , COUNT(*)                      AS event_count
  , COUNT(DISTINCT distinct_id)   AS distinct_users
FROM soundstripe_prod.core.fct_events
WHERE event = 'Viewed Pricing Page'
  AND event_ts::date BETWEEN '2026-01-07' AND '2026-04-23'
GROUP BY window_label, host, path
ORDER BY window_label, event_count DESC
;


-- =============================================================================
-- D8: Clicked Element property distribution on pricing URL (raw source)
-- -----------------------------------------------------------------------------
-- Question:      What values populate CTA_NAME, CTA_ID, ELEMENT,
--                ELEMENT_TEXT, and PERSONA on `Clicked Element` events fired
--                from a pricing URL during the baseline? These label the
--                funnel-step clicks (View Pricing, Persona, Plan).
--                Uses UNION ALL with a side discriminator per
--                feedback_one_sql_file_per_query_set so one export carries
--                all five columns' top values.
-- Scope:         Baseline (Jan 7 – Feb 6 2026) only. Path filter accepts
--                both `pricing` and `library/pricing` (post-consolidation).
-- Expected:      CTA_NAME / ELEMENT_TEXT should carry labels like "View
--                Pricing", "Select Plan", persona names ("Freelancer",
--                "YouTuber", etc.). PERSONA should carry the persona name
--                directly on persona-selection clicks.
-- Export:        d8.csv
-- =============================================================================

WITH base AS (
    SELECT
        cta_name
      , cta_id
      , element
      , element_text
      , persona
    FROM pc_stitch_db.mixpanel.export
    WHERE time::date BETWEEN '2026-01-07' AND '2026-02-06'
      AND event = 'Clicked Element'
      AND PARSE_URL(COALESCE(current_url, mp_reserved_current_url, url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
)
SELECT 'cta_name'     AS property_name, COALESCE(cta_name, '(null)')     AS property_value, COUNT(*) AS n FROM base GROUP BY cta_name
UNION ALL
SELECT 'cta_id'       AS property_name, COALESCE(cta_id, '(null)')       AS property_value, COUNT(*) AS n FROM base GROUP BY cta_id
UNION ALL
SELECT 'element'      AS property_name, COALESCE(element, '(null)')      AS property_value, COUNT(*) AS n FROM base GROUP BY element
UNION ALL
SELECT 'element_text' AS property_name, COALESCE(element_text, '(null)') AS property_value, COUNT(*) AS n FROM base GROUP BY element_text
UNION ALL
SELECT 'persona'      AS property_name, COALESCE(persona, '(null)')      AS property_value, COUNT(*) AS n FROM base GROUP BY persona
ORDER BY property_name, n DESC
;


-- =============================================================================
-- D9: $mp_page_leave firing on pricing URL — daily timeline
-- -----------------------------------------------------------------------------
-- Question:      Q2 showed scroll-depth page-leavers dropped from 4,013 in
--                the pre window (31d) to 83 total across Feb 24 – Apr 23
--                (59d). Is this real traffic or did $mp_page_leave firing
--                on pricing break? Daily counts locate the breakpoint.
-- Expected:      If the change is instrumentation, we'll see a sharp cliff
--                on or near 2026-02-24. If the change is real (e.g., path
--                filter misses the post-consolidation URL), the cliff will
--                align with the URL transition (Mar 5 / Mar 17).
-- Export:        d9.csv
-- =============================================================================

SELECT
    time::date                    AS event_date
  , PARSE_URL(COALESCE(current_url, mp_reserved_current_url, url)):host::string AS host
  , PARSE_URL(COALESCE(current_url, mp_reserved_current_url, url)):path::string AS path
  , COUNT(*)                      AS page_leave_events
  , COUNT(DISTINCT distinct_id)   AS distinct_users
  , COUNT_IF(mp_reserved_max_scroll_percentage IS NOT NULL) AS with_scroll
FROM pc_stitch_db.mixpanel.export
WHERE time::date BETWEEN '2026-01-01' AND '2026-04-23'
  AND event = '$mp_page_leave'
  AND PARSE_URL(COALESCE(current_url, mp_reserved_current_url, url)):path::string
      IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
GROUP BY all
ORDER BY event_date, page_leave_events DESC
;


-- =============================================================================
-- D10: Full column inventory of pc_stitch_db.mixpanel.export
-- -----------------------------------------------------------------------------
-- Question:      D2a was narrow (searched %scroll% / %depth% / %page_leave% /
--                %pct%). What else is on this table? A full column dump
--                lets us scan for scroll-adjacent columns we might have
--                missed (viewport, visible, fold, y, position, read,
--                engagement, max, height) and for new columns Stitch may
--                have added via schema drift after Feb 24.
-- Export:        d10.csv
-- =============================================================================

SELECT
    column_name
  , data_type
FROM pc_stitch_db.information_schema.columns
WHERE table_schema = 'MIXPANEL'
  AND table_name   = 'EXPORT'
ORDER BY column_name
;


-- =============================================================================
-- D11: Taxonomy diff — events on pricing URLs post-2/25 that didn't exist
--      in the pre baseline
-- -----------------------------------------------------------------------------
-- Question:      Did NEW event types start firing on pricing URLs after
--                the 2/24 deploy? An SDK or tracking-plan change could have
--                moved scroll (or a scroll surrogate) to a new event name
--                (e.g., 'Viewed Section', 'Reached Bottom', 'Element
--                Visible', 'Scroll Complete'). This LEFT ANTI-JOIN reveals
--                any additions.
-- Interpretation: If nothing new shows up, scroll truly left the taxonomy
--                 and Q7's engagement proxy is the honest answer. If
--                 a new high-volume event appears, it becomes the next
--                 discovery target.
-- Export:        d11.csv
-- =============================================================================

WITH pre_events AS (
    SELECT DISTINCT event
    FROM pc_stitch_db.mixpanel.export
    WHERE time::date BETWEEN '2026-01-07' AND '2026-02-06'
      AND PARSE_URL(COALESCE(current_url, mp_reserved_current_url, url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
)
, post_events AS (
    SELECT
        event
      , COUNT(*)                    AS event_count
      , COUNT(DISTINCT distinct_id) AS distinct_users
      , MIN(time)                   AS first_seen_post
      , MAX(time)                   AS last_seen_post
    FROM pc_stitch_db.mixpanel.export
    WHERE time::date BETWEEN '2026-02-25' AND '2026-04-23'
      AND PARSE_URL(COALESCE(current_url, mp_reserved_current_url, url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
    GROUP BY event
)
SELECT
    post_events.event
  , CASE WHEN pre_events.event IS NOT NULL THEN 'existing' ELSE 'NEW_POST_2_25' END AS taxonomy_status
  , post_events.event_count
  , post_events.distinct_users
  , post_events.first_seen_post
  , post_events.last_seen_post
FROM post_events
LEFT JOIN pre_events USING (event)
ORDER BY taxonomy_status DESC, post_events.event_count DESC
;


-- =============================================================================
-- D12: Display Element — firing pattern by element value, pre vs post
-- -----------------------------------------------------------------------------
-- Question:      `Display Element` fired 917 times on pricing during the
--                pre baseline (D1), with values like "Standard Coverage",
--                "Extended Coverage", persona labels. If this event fires
--                when a pricing component becomes visible in the user's
--                viewport, the element value is a categorical scroll proxy
--                — users who triggered Display Element for a below-fold
--                element scrolled to that depth. Compare firing pattern
--                pre vs post to see whether Display Element carries a
--                scroll surrogate.
-- Export:        d12.csv
-- =============================================================================

WITH labeled AS (
    SELECT
        CASE
            WHEN time::date BETWEEN '2026-01-07' AND '2026-02-06'                         THEN '1_pre'
            WHEN time::date BETWEEN '2026-02-25' AND '2026-03-10'                         THEN '2_post_2wk'
            WHEN time::date BETWEEN '2026-02-25' AND '2026-04-23'
                 AND NOT (time::date BETWEEN '2026-03-05' AND '2026-03-25')               THEN '4_post_8wk_clean'
            ELSE '9_other'
        END                         AS window_label
      , element
      , distinct_id
    FROM pc_stitch_db.mixpanel.export
    WHERE event = 'Display Element'
      AND time::date BETWEEN '2026-01-07' AND '2026-04-23'
      AND PARSE_URL(COALESCE(current_url, mp_reserved_current_url, url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
)
SELECT
    window_label
  , COALESCE(element, '(null)')   AS element_value
  , COUNT(*)                      AS event_count
  , COUNT(DISTINCT distinct_id)   AS distinct_users
FROM labeled
WHERE window_label != '9_other'
GROUP BY window_label, element_value
ORDER BY window_label, event_count DESC
;


-- =============================================================================
-- D13: Click vertical-position distribution on pricing URL, pre vs post
-- -----------------------------------------------------------------------------
-- Question:      MP_RESERVED_PAGEY + MP_RESERVED_PAGEHEIGHT on click events
--                give a click-by-scroll-depth proxy: PAGEY / PAGEHEIGHT is
--                where on the page the user clicked. A click at ratio 0.1
--                is near top; 0.5 middle; 0.9 near bottom. If post-change
--                clicks concentrate higher (lower ratios), users engaged
--                with content closer to the top — which is what the banner
--                shrink was supposed to enable.
--                MP_RESERVED_FOLD_LINE_PERCENTAGE is the viewport fold;
--                clicks below that ratio are below the fold.
--                D2c showed scroll capture broke 2/25; click-coordinate
--                capture lives on every click event and should not have
--                broken. Restores a scroll-like comparison.
-- Method:        Deepest-click-ratio per user per window, then threshold
--                shares at 5/20/50/95/below-5 (matching Q2's thresholds so
--                the two frames are directly comparable in pre where both
--                signals exist).
-- Export:        d13.csv
-- =============================================================================

WITH click_events AS (
    SELECT
        CASE
            WHEN time::date BETWEEN '2026-01-07' AND '2026-02-06'                         THEN '1_pre'
            WHEN time::date BETWEEN '2026-02-25' AND '2026-03-10'                         THEN '2_post_2wk'
            WHEN time::date BETWEEN '2026-02-25' AND '2026-04-23'
                 AND NOT (time::date BETWEEN '2026-03-05' AND '2026-03-25')               THEN '4_post_8wk_clean'
            ELSE '9_other'
        END                                                    AS window_label
      , distinct_id
      , TRY_CAST(mp_reserved_pagey       AS FLOAT)             AS page_y
      , TRY_CAST(mp_reserved_pageheight  AS FLOAT)             AS page_h
    FROM pc_stitch_db.mixpanel.export
    WHERE event IN ('Clicked Element', '$mp_click')
      AND time::date BETWEEN '2026-01-07' AND '2026-04-23'
      AND PARSE_URL(COALESCE(current_url, mp_reserved_current_url, url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
)
, ratio_events AS (
    SELECT
        window_label
      , distinct_id
      , page_y / NULLIF(page_h, 0)  AS click_ratio
    FROM click_events
    WHERE window_label != '9_other'
      AND page_y  IS NOT NULL
      AND page_h  IS NOT NULL
      AND page_h  > 0
)
, per_user_deepest AS (
    SELECT window_label, distinct_id, MAX(click_ratio) AS deepest_click_ratio
    FROM ratio_events
    GROUP BY window_label, distinct_id
)
SELECT
    window_label
  , COUNT(*)                                                                                AS users_with_click
  , AVG(deepest_click_ratio)                                                                AS avg_deepest_ratio
  , SUM(CASE WHEN deepest_click_ratio >= 0.05 THEN 1 ELSE 0 END)::FLOAT / COUNT(*)          AS share_deepest_ge_05
  , SUM(CASE WHEN deepest_click_ratio >= 0.20 THEN 1 ELSE 0 END)::FLOAT / COUNT(*)          AS share_deepest_ge_20
  , SUM(CASE WHEN deepest_click_ratio >= 0.50 THEN 1 ELSE 0 END)::FLOAT / COUNT(*)          AS share_deepest_ge_50
  , SUM(CASE WHEN deepest_click_ratio >= 0.95 THEN 1 ELSE 0 END)::FLOAT / COUNT(*)          AS share_deepest_ge_95
  , SUM(CASE WHEN deepest_click_ratio  < 0.05 THEN 1 ELSE 0 END)::FLOAT / COUNT(*)          AS share_deepest_below_05
FROM per_user_deepest
GROUP BY window_label
ORDER BY window_label
;


-- =============================================================================
-- D14: Pricing-panel experiment and Convert.com enrollment probe
-- -----------------------------------------------------------------------------
-- Question:      D10 revealed PRICING_PANEL_EXPERIMENT_ID,
--                PRICING_PANEL_VARIANT, USER_PRICING_FUNNEL, and
--                CONVERT_CURRENT_EXPERIENCES columns on the raw table —
--                columns I hadn't surfaced in earlier discovery. If the
--                banner shrink shipped as a Convert.com experiment, these
--                columns will show variant assignment and the deployment
--                story moves from "site-wide" to "A/B tested". Even if not,
--                USER_PRICING_FUNNEL may carry the explicit funnel state
--                that would replace our element-name reconstruction.
-- Method:        Per-window distinct-value counts for each of the four
--                columns, UNION ALL'd with a property discriminator.
-- Export:        d14.csv
-- =============================================================================

WITH base AS (
    SELECT
        CASE
            WHEN time::date BETWEEN '2026-01-07' AND '2026-02-06'                         THEN '1_pre'
            WHEN time::date BETWEEN '2026-02-25' AND '2026-04-23'
                 AND NOT (time::date BETWEEN '2026-03-05' AND '2026-03-25')               THEN '4_post_8wk_clean'
            ELSE '9_other'
        END                                    AS window_label
      , pricing_panel_experiment_id
      , pricing_panel_variant
      , user_pricing_funnel
      , convert_current_experiences
      , distinct_id
    FROM pc_stitch_db.mixpanel.export
    WHERE time::date BETWEEN '2026-01-07' AND '2026-04-23'
      AND PARSE_URL(COALESCE(current_url, mp_reserved_current_url, url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
)
SELECT 'pricing_panel_experiment_id' AS property, window_label, COALESCE(pricing_panel_experiment_id, '(null)') AS property_value,
       COUNT(*) AS n, COUNT(DISTINCT distinct_id) AS users
FROM base WHERE window_label != '9_other'
GROUP BY window_label, pricing_panel_experiment_id
UNION ALL
SELECT 'pricing_panel_variant', window_label, COALESCE(pricing_panel_variant, '(null)'),
       COUNT(*), COUNT(DISTINCT distinct_id)
FROM base WHERE window_label != '9_other'
GROUP BY window_label, pricing_panel_variant
UNION ALL
SELECT 'user_pricing_funnel', window_label, COALESCE(user_pricing_funnel, '(null)'),
       COUNT(*), COUNT(DISTINCT distinct_id)
FROM base WHERE window_label != '9_other'
GROUP BY window_label, user_pricing_funnel
UNION ALL
SELECT 'convert_current_experiences', window_label, COALESCE(convert_current_experiences, '(null)'),
       COUNT(*), COUNT(DISTINCT distinct_id)
FROM base WHERE window_label != '9_other'
GROUP BY window_label, convert_current_experiences
ORDER BY property, window_label, n DESC
;


-- =============================================================================
-- D15: "View Pricing" / "See Pricing" click disambiguation
-- -----------------------------------------------------------------------------
-- Question:      My earlier analysis treated `Clicked Element` with
--                `element='View Pricing'` as a single CTA. With 64,857
--                events / 8,633 users (~7.5 events/user) in baseline, that
--                is implausible for one button — multiple CTAs across the
--                pricing page likely share the 'View Pricing' label. Also,
--                "See Pricing" in the header fires `Clicked Sign Up
--                Button` with `Link Text: "See Pricing"` (user-confirmed
--                example), an event I didn't probe at all.
-- Method:        Breakdown of click events on pricing URL by (event,
--                element, context, link_text) pre vs post-8wk-clean.
--                Covers Clicked Element, Clicked Sign Up Button, Clicked
--                Sign Up Link, Clicked Pricing Link — the four click
--                streams relevant to pricing CTAs.
-- Export:        d15.csv
-- =============================================================================

WITH labeled AS (
    SELECT
        CASE
            WHEN time::date BETWEEN '2026-01-07' AND '2026-02-06'                         THEN '1_pre'
            WHEN time::date BETWEEN '2026-02-25' AND '2026-04-23'
                 AND NOT (time::date BETWEEN '2026-03-05' AND '2026-03-25')               THEN '4_post_8wk_clean'
            ELSE '9_other'
        END                                             AS window_label
      , event
      , COALESCE(element, '(null)')                     AS element
      , COALESCE(context, '(null)')                     AS context
      , COALESCE(link_text, '(null)')                   AS link_text
      , distinct_id
    FROM pc_stitch_db.mixpanel.export
    WHERE event IN ('Clicked Element', 'Clicked Sign Up Button',
                     'Clicked Sign Up Link', 'Clicked Pricing Link')
      AND time::date BETWEEN '2026-01-07' AND '2026-04-23'
      AND PARSE_URL(COALESCE(current_url, mp_reserved_current_url, url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
)
SELECT
    window_label
  , event
  , element
  , context
  , link_text
  , COUNT(*)                    AS event_count
  , COUNT(DISTINCT distinct_id) AS distinct_users
FROM labeled
WHERE window_label != '9_other'
GROUP BY ALL
QUALIFY ROW_NUMBER() OVER (PARTITION BY window_label ORDER BY event_count DESC) <= 40
ORDER BY window_label, event_count DESC
;


-- =============================================================================
-- D16: Upstream arrival flow — "See Pricing" clicks from OTHER pages
-- -----------------------------------------------------------------------------
-- Question:      User example shows `Clicked Sign Up Button` with
--                `Link Text: "See Pricing"` and `Context: "Header"` is how
--                the dashboard/header "See Pricing" link is captured. That
--                event fires from the SOURCE page (dashboard, marketing
--                page, etc.), not pricing. How many of these fire pre vs
--                post, and from which surface? Did the arrival funnel into
--                pricing change?
-- Method:        All events with link_text ILIKE '%pricing%' OR
--                link_text = 'See Pricing' regardless of URL path;
--                bucketed by source path + context + link_text, per window.
-- Export:        d16.csv
-- =============================================================================

WITH arrivals AS (
    SELECT
        CASE
            WHEN time::date BETWEEN '2026-01-07' AND '2026-02-06'                         THEN '1_pre'
            WHEN time::date BETWEEN '2026-02-25' AND '2026-04-23'
                 AND NOT (time::date BETWEEN '2026-03-05' AND '2026-03-25')               THEN '4_post_8wk_clean'
            ELSE '9_other'
        END                                                           AS window_label
      , event
      , COALESCE(context, '(null)')                                   AS context
      , COALESCE(link_text, '(null)')                                 AS link_text
      , PARSE_URL(COALESCE(current_url, mp_reserved_current_url, url)):path::string AS source_path
      , distinct_id
    FROM pc_stitch_db.mixpanel.export
    WHERE time::date BETWEEN '2026-01-07' AND '2026-04-23'
      AND (link_text ILIKE '%pricing%'
           OR element ILIKE '%pricing%'
           OR cta_name ILIKE '%pricing%')
      AND event IN ('Clicked Element', 'Clicked Sign Up Button',
                     'Clicked Sign Up Link', 'Clicked Pricing Link')
)
SELECT
    window_label
  , event
  , source_path
  , context
  , link_text
  , COUNT(*)                    AS event_count
  , COUNT(DISTINCT distinct_id) AS distinct_users
FROM arrivals
WHERE window_label != '9_other'
GROUP BY ALL
QUALIFY ROW_NUMBER() OVER (PARTITION BY window_label ORDER BY event_count DESC) <= 40
ORDER BY window_label, event_count DESC
;


-- =============================================================================
-- D17: Events-per-user for Viewed Pricing Page — does SPA behavior differ?
-- -----------------------------------------------------------------------------
-- Question:      Do pricing visitors fire `Viewed Pricing Page` more times
--                per session/user post-change than pre? If so, the
--                denominator of our rate calculations is qualitatively
--                different pre vs post — post might be counting more
--                brief/ambient visits (e.g., modal open/close firing the
--                event repeatedly) against the same click denominator.
-- Method:        Per user per window: count of `Viewed Pricing Page`
--                events. Then distribution: users with 1 event, 2, 3-5,
--                6-10, 11+. Plus average and median.
-- Export:        d17.csv
-- =============================================================================

WITH per_user AS (
    SELECT
        CASE
            WHEN event_ts::date BETWEEN '2026-01-07' AND '2026-02-06'                     THEN '1_pre'
            WHEN event_ts::date BETWEEN '2026-02-25' AND '2026-03-10'                     THEN '2_post_2wk'
            WHEN event_ts::date BETWEEN '2026-02-25' AND '2026-04-23'
                 AND NOT (event_ts::date BETWEEN '2026-03-05' AND '2026-03-25')           THEN '4_post_8wk_clean'
            ELSE '9_other'
        END                                   AS window_label
      , distinct_id
      , COUNT(*)                              AS events_for_user
    FROM soundstripe_prod.core.fct_events
    WHERE event = 'Viewed Pricing Page'
      AND event_ts::date BETWEEN '2026-01-07' AND '2026-04-23'
      AND path IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
    GROUP BY 1, 2
)
SELECT
    window_label
  , COUNT(*)                                                                                       AS distinct_users
  , SUM(events_for_user)                                                                           AS total_events
  , AVG(events_for_user)                                                                           AS avg_events_per_user
  , MEDIAN(events_for_user)                                                                        AS median_events_per_user
  , SUM(CASE WHEN events_for_user =  1 THEN 1 ELSE 0 END)::FLOAT / COUNT(*)                        AS share_1_event
  , SUM(CASE WHEN events_for_user =  2 THEN 1 ELSE 0 END)::FLOAT / COUNT(*)                        AS share_2_events
  , SUM(CASE WHEN events_for_user BETWEEN 3 AND 5  THEN 1 ELSE 0 END)::FLOAT / COUNT(*)            AS share_3_to_5
  , SUM(CASE WHEN events_for_user BETWEEN 6 AND 10 THEN 1 ELSE 0 END)::FLOAT / COUNT(*)            AS share_6_to_10
  , SUM(CASE WHEN events_for_user >= 11 THEN 1 ELSE 0 END)::FLOAT / COUNT(*)                       AS share_11_plus
FROM per_user
WHERE window_label != '9_other'
GROUP BY window_label
ORDER BY window_label
;
