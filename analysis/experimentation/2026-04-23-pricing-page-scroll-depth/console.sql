-- =============================================================================
-- Purpose:       Main query set for pricing-page banner-shrink pre/post
--                analysis.
-- Task:          analysis/experimentation/2026-04-23-pricing-page-scroll-depth/
-- Author:        Devon Bennett
-- Date:          2026-04-23
-- Dependencies:  soundstripe_prod.core.fct_events       (event='Viewed Pricing Page', 'Created Subscription')
--                pc_stitch_db.mixpanel.export           ($mp_page_leave scroll, Clicked Element labels)
--
-- Usage:         Run each labeled Qn as its own SELECT. Export each result
--                as q<N>.csv in the task root directory. Single file,
--                single-SELECT per label (feedback_one_sql_file_per_query_set).
--
-- Windows:
--   1_pre             2026-01-07 .. 2026-02-06   (31d, product team baseline)
--   2_post_2wk        2026-02-24 .. 2026-03-10   (15d, original due-date intent)
--   3_post_8wk        2026-02-24 .. 2026-04-23   (59d, persistence)
--   4_post_8wk_clean  3_post_8wk EXCLUDING 2026-03-05..2026-03-25
--                                                (40d, contamination window removed
--                                                 per 2026-04-01 direct-traffic-spike
--                                                 correction pattern)
--
-- Visitor gate:  event = 'Viewed Pricing Page'. `page_category = 'pricing'`
--                is BROKEN post-domain-consolidation (paths moved from
--                'pricing' to 'library/pricing'; stg_events.sql classifier
--                is exact-match). Do not use page_category in this task.
--
-- Path filter (raw Mixpanel): path IN ('pricing','library/pricing',
--                'pricing/','library/pricing/').
-- =============================================================================


-- =============================================================================
-- Q1: Daily pricing-page visitors — full time series (continuous)
-- -----------------------------------------------------------------------------
-- Question:      What does daily pricing-page visitor volume look like
--                end-to-end Jan 1 – Apr 23? Useful as a shape check and to
--                surface any unexpected daily spikes/drops beyond the
--                known Mar/Apr contamination.
-- Rate:          n/a (counts only)
-- Export:        q1.csv
-- =============================================================================

SELECT
    event_ts::date                AS event_date
  , COUNT(DISTINCT distinct_id)   AS distinct_users
  , COUNT(DISTINCT session_id)    AS distinct_sessions
  , COUNT(*)                      AS events
FROM soundstripe_prod.core.fct_events
WHERE event = 'Viewed Pricing Page'
  AND event_ts::date BETWEEN '2026-01-01' AND '2026-04-23'
  AND path IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
GROUP BY event_date
ORDER BY event_date
;


-- =============================================================================
-- Q2: Scroll-depth distribution per window (user-level)
-- -----------------------------------------------------------------------------
-- Rate:          scroll_depth_share_at_T (see findings.md §1). Numerator is
--                distinct users with max scroll pct >= T on a pricing URL;
--                denominator is distinct users with ANY $mp_page_leave on
--                a pricing URL in the window.
-- Method:        Clip to 100 (values of 109 are overscroll). Take per-user
--                MAX across all pricing page-leave events in window. Then
--                compute cumulative-share thresholds.
-- Export:        q2.csv
-- =============================================================================

WITH windows AS (
    SELECT '1_pre'            AS window_label, '2026-01-07'::date AS start_d, '2026-02-06'::date AS end_d
    UNION ALL SELECT '2_post_2wk'      , '2026-02-24'::date, '2026-03-10'::date
    UNION ALL SELECT '3_post_8wk'      , '2026-02-24'::date, '2026-04-23'::date
    UNION ALL SELECT '4_post_8wk_clean', '2026-02-24'::date, '2026-04-23'::date
)
, scroll_events AS (
    SELECT
        w.window_label
      , e.distinct_id
      , LEAST(100, GREATEST(0, TRY_CAST(e.mp_reserved_max_scroll_percentage AS FLOAT))) AS scroll_pct
    FROM windows w
    INNER JOIN pc_stitch_db.mixpanel.export e
        ON e.time::date BETWEEN w.start_d AND w.end_d
       AND NOT (w.window_label = '4_post_8wk_clean'
                AND e.time::date BETWEEN '2026-03-05' AND '2026-03-25')
    WHERE e.event = '$mp_page_leave'
      AND PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
      AND e.mp_reserved_max_scroll_percentage IS NOT NULL
)
, per_user_max AS (
    SELECT
        window_label
      , distinct_id
      , MAX(scroll_pct) AS max_scroll
    FROM scroll_events
    GROUP BY window_label, distinct_id
)
SELECT
    window_label
  , COUNT(*)                                                                    AS page_leavers
  , AVG(max_scroll)                                                             AS avg_scroll_pct
  , SUM(CASE WHEN max_scroll >=   5 THEN 1 ELSE 0 END)::FLOAT / COUNT(*)        AS share_at_ge_5
  , SUM(CASE WHEN max_scroll >=  20 THEN 1 ELSE 0 END)::FLOAT / COUNT(*)        AS share_at_ge_20
  , SUM(CASE WHEN max_scroll >=  50 THEN 1 ELSE 0 END)::FLOAT / COUNT(*)        AS share_at_ge_50
  , SUM(CASE WHEN max_scroll >=  95 THEN 1 ELSE 0 END)::FLOAT / COUNT(*)        AS share_at_ge_95
  , SUM(CASE WHEN max_scroll  = 100 THEN 1 ELSE 0 END)::FLOAT / COUNT(*)        AS share_at_100
  , SUM(CASE WHEN max_scroll  <   5 THEN 1 ELSE 0 END)::FLOAT / COUNT(*)        AS share_below_5
FROM per_user_max
GROUP BY window_label
ORDER BY window_label
;


-- =============================================================================
-- Q3: 5-step persona-card funnel — user counts per step per window
-- -----------------------------------------------------------------------------
-- Rate:          entered_persona_flow_rate, step_entered_flow_to_persona,
--                step_persona_to_plan, step_plan_to_subscribe,
--                cumulative_pricing_to_subscribe. See findings.md §1.
-- Method:        Per user, per window: (1) visited pricing,
--                (2) clicked View Pricing OR Choose a Plan on pricing URL
--                — D15 surfaced that the 2/24 deploy added a `Choose a
--                Plan` CTA alongside `View Pricing` as the entry into the
--                persona flow; treating the pair as a union preserves the
--                step's intent (user engaged the persona-selection CTA)
--                across the deploy boundary — (3) selected any persona,
--                (4) clicked any plan, (5) Created Subscription within
--                7 days of a pricing view in window.
--                Step rate = users_at_step / users_at_prior_step.
--                Cumulative = users_at_step / visitors.
-- Export:        q3.csv
-- =============================================================================

WITH windows AS (
    SELECT '1_pre'            AS window_label, '2026-01-07'::date AS start_d, '2026-02-06'::date AS end_d
    UNION ALL SELECT '2_post_2wk'      , '2026-02-24'::date, '2026-03-10'::date
    UNION ALL SELECT '3_post_8wk'      , '2026-02-24'::date, '2026-04-23'::date
    UNION ALL SELECT '4_post_8wk_clean', '2026-02-24'::date, '2026-04-23'::date
)
, visitors AS (
    SELECT DISTINCT w.window_label, e.distinct_id
    FROM windows w
    INNER JOIN soundstripe_prod.core.fct_events e
        ON e.event_ts::date BETWEEN w.start_d AND w.end_d
       AND NOT (w.window_label = '4_post_8wk_clean'
                AND e.event_ts::date BETWEEN '2026-03-05' AND '2026-03-25')
    WHERE e.event = 'Viewed Pricing Page'
      AND e.path IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
)
, entered_persona_flow AS (
    -- Union of View Pricing and Choose a Plan click events on pricing URL,
    -- per user per window. Both route users into the persona-selection UX.
    SELECT DISTINCT w.window_label, e.distinct_id
    FROM windows w
    INNER JOIN pc_stitch_db.mixpanel.export e
        ON e.time::date BETWEEN w.start_d AND w.end_d
       AND NOT (w.window_label = '4_post_8wk_clean'
                AND e.time::date BETWEEN '2026-03-05' AND '2026-03-25')
    WHERE e.event = 'Clicked Element'
      AND e.element IN ('View Pricing', 'Choose a Plan')
      AND PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
)
, persona_selectors AS (
    SELECT DISTINCT w.window_label, e.distinct_id
    FROM windows w
    INNER JOIN pc_stitch_db.mixpanel.export e
        ON e.time::date BETWEEN w.start_d AND w.end_d
       AND NOT (w.window_label = '4_post_8wk_clean'
                AND e.time::date BETWEEN '2026-03-05' AND '2026-03-25')
    WHERE e.event = 'Clicked Element'
      AND e.element IN ('Youtuber/Content Creator', 'Student/Hobbyist', 'Freelancer',
                         'Other', 'Podcast', 'Wedding Filmmaker')
      AND PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
)
, plan_clickers AS (
    SELECT DISTINCT w.window_label, e.distinct_id
    FROM windows w
    INNER JOIN pc_stitch_db.mixpanel.export e
        ON e.time::date BETWEEN w.start_d AND w.end_d
       AND NOT (w.window_label = '4_post_8wk_clean'
                AND e.time::date BETWEEN '2026-03-05' AND '2026-03-25')
    WHERE e.event = 'Clicked Element'
      AND e.element IN ('Pro Yearly', 'Pro Monthly',
                         'Personal Yearly', 'Personal Monthly',
                         'Pro Plus Yearly', 'Pro Plus Monthly',
                         'Business Quarterly', 'Business Yearly',
                         'Pro Yearly with Warner Chappell Production Music',
                         'Pro Monthly with Warner Chappell Production Music',
                         'Pro Plus with Warner Chappell Production Music Yearly',
                         'Pro Plus with Warner Chappell Production Music Monthly')
      AND PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
)
, subscribers AS (
    SELECT DISTINCT w.window_label, v.distinct_id
    FROM windows w
    INNER JOIN soundstripe_prod.core.fct_events v
        ON v.event_ts::date BETWEEN w.start_d AND w.end_d
       AND NOT (w.window_label = '4_post_8wk_clean'
                AND v.event_ts::date BETWEEN '2026-03-05' AND '2026-03-25')
       AND v.event = 'Viewed Pricing Page'
       AND v.path IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
    INNER JOIN soundstripe_prod.core.fct_events s
        ON s.distinct_id = v.distinct_id
       AND s.event      = 'Created Subscription'
       AND s.event_ts  >= v.event_ts
       AND s.event_ts  <  DATEADD('day', 7, v.event_ts)
)
, steps AS (
    SELECT window_label, 1 AS step_order, 'Pricing Visitors'     AS step, COUNT(*) AS n FROM visitors             GROUP BY window_label
    UNION ALL SELECT window_label, 2, 'Entered Persona Flow', COUNT(*) FROM entered_persona_flow GROUP BY window_label
    UNION ALL SELECT window_label, 3, 'Selected Persona'    , COUNT(*) FROM persona_selectors    GROUP BY window_label
    UNION ALL SELECT window_label, 4, 'Clicked Plan'        , COUNT(*) FROM plan_clickers        GROUP BY window_label
    UNION ALL SELECT window_label, 5, 'Subscribed'          , COUNT(*) FROM subscribers          GROUP BY window_label
)
SELECT
    window_label
  , step_order
  , step
  , n
  , n::FLOAT / FIRST_VALUE(n) OVER (PARTITION BY window_label ORDER BY step_order)                  AS cumulative_rate
  , n::FLOAT / LAG(n)        OVER (PARTITION BY window_label ORDER BY step_order)                   AS step_rate
FROM steps
ORDER BY window_label, step_order
;


-- =============================================================================
-- Q4: Persona breakdown per window — share and conversion by persona
-- -----------------------------------------------------------------------------
-- Rate:          persona_share, per-persona conversion (see findings.md §1).
-- Method:        Per user, per window: first persona clicked on pricing URL
--                (using MIN event_ts tiebreak). Then compute shares across
--                persona selectors, and per-persona conversion to
--                subscription within 7 days of the persona click.
-- Export:        q4.csv
-- =============================================================================

WITH windows AS (
    SELECT '1_pre'            AS window_label, '2026-01-07'::date AS start_d, '2026-02-06'::date AS end_d
    UNION ALL SELECT '2_post_2wk'      , '2026-02-24'::date, '2026-03-10'::date
    UNION ALL SELECT '3_post_8wk'      , '2026-02-24'::date, '2026-04-23'::date
    UNION ALL SELECT '4_post_8wk_clean', '2026-02-24'::date, '2026-04-23'::date
)
, persona_click_events AS (
    SELECT
        w.window_label
      , e.distinct_id
      , e.element AS persona
      , e.time::timestamp AS click_ts
    FROM windows w
    INNER JOIN pc_stitch_db.mixpanel.export e
        ON e.time::date BETWEEN w.start_d AND w.end_d
       AND NOT (w.window_label = '4_post_8wk_clean'
                AND e.time::date BETWEEN '2026-03-05' AND '2026-03-25')
    WHERE e.event = 'Clicked Element'
      AND e.element IN ('Youtuber/Content Creator', 'Student/Hobbyist', 'Freelancer',
                         'Other', 'Podcast', 'Wedding Filmmaker')
      AND PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
)
, first_persona AS (
    -- A user's first persona click in the window (ties broken by smallest click_ts)
    SELECT window_label, distinct_id, persona, click_ts
    FROM persona_click_events
    QUALIFY ROW_NUMBER() OVER (PARTITION BY window_label, distinct_id ORDER BY click_ts) = 1
)
, persona_subs AS (
    SELECT DISTINCT fp.window_label, fp.distinct_id, fp.persona
    FROM first_persona fp
    INNER JOIN soundstripe_prod.core.fct_events s
        ON s.distinct_id = fp.distinct_id
       AND s.event       = 'Created Subscription'
       AND s.event_ts   >= fp.click_ts
       AND s.event_ts   <  DATEADD('day', 7, fp.click_ts)
)
, window_totals AS (
    SELECT window_label, COUNT(*) AS total_persona_selectors
    FROM first_persona
    GROUP BY window_label
)
SELECT
    fp.window_label
  , fp.persona
  , COUNT(DISTINCT fp.distinct_id)                                                            AS persona_selectors
  , COUNT(DISTINCT fp.distinct_id)::FLOAT / MAX(wt.total_persona_selectors)                   AS persona_share
  , COUNT(DISTINCT ps.distinct_id)                                                            AS subscribers
  , COUNT(DISTINCT ps.distinct_id)::FLOAT / NULLIF(COUNT(DISTINCT fp.distinct_id), 0)         AS per_persona_conversion
FROM first_persona fp
LEFT JOIN persona_subs  ps USING (window_label, distinct_id, persona)
LEFT JOIN window_totals wt USING (window_label)
GROUP BY fp.window_label, fp.persona
ORDER BY fp.window_label, persona_selectors DESC
;


-- =============================================================================
-- Q5: Plan breakdown per window — click share and conversion by plan
-- -----------------------------------------------------------------------------
-- Rate:          per_plan_click_share, per_plan_conversion (see findings.md §1).
-- Method:        Per user, per window: each plan clicked (users can click
--                multiple plans — comparison-shopping is explicit in the
--                product team's data). Count unique users per plan; compute
--                plan-share of plan-clicker population; conversion = user
--                subscribed within 7d of any click on that plan.
-- Export:        q5.csv
-- =============================================================================

WITH windows AS (
    SELECT '1_pre'            AS window_label, '2026-01-07'::date AS start_d, '2026-02-06'::date AS end_d
    UNION ALL SELECT '2_post_2wk'      , '2026-02-24'::date, '2026-03-10'::date
    UNION ALL SELECT '3_post_8wk'      , '2026-02-24'::date, '2026-04-23'::date
    UNION ALL SELECT '4_post_8wk_clean', '2026-02-24'::date, '2026-04-23'::date
)
, plan_click_events AS (
    SELECT
        w.window_label
      , e.distinct_id
      , e.element AS plan_name
      , e.time::timestamp AS click_ts
    FROM windows w
    INNER JOIN pc_stitch_db.mixpanel.export e
        ON e.time::date BETWEEN w.start_d AND w.end_d
       AND NOT (w.window_label = '4_post_8wk_clean'
                AND e.time::date BETWEEN '2026-03-05' AND '2026-03-25')
    WHERE e.event = 'Clicked Element'
      AND e.element IN ('Pro Yearly', 'Pro Monthly',
                         'Personal Yearly', 'Personal Monthly',
                         'Pro Plus Yearly', 'Pro Plus Monthly',
                         'Business Quarterly', 'Business Yearly',
                         'Pro Yearly with Warner Chappell Production Music',
                         'Pro Monthly with Warner Chappell Production Music',
                         'Pro Plus with Warner Chappell Production Music Yearly',
                         'Pro Plus with Warner Chappell Production Music Monthly')
      AND PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
)
, user_first_plan_click AS (
    -- Per (window, user, plan): earliest click_ts for attribution
    SELECT window_label, distinct_id, plan_name, MIN(click_ts) AS first_click_ts
    FROM plan_click_events
    GROUP BY window_label, distinct_id, plan_name
)
, plan_subs AS (
    SELECT DISTINCT ufpc.window_label, ufpc.distinct_id, ufpc.plan_name
    FROM user_first_plan_click ufpc
    INNER JOIN soundstripe_prod.core.fct_events s
        ON s.distinct_id = ufpc.distinct_id
       AND s.event       = 'Created Subscription'
       AND s.event_ts   >= ufpc.first_click_ts
       AND s.event_ts   <  DATEADD('day', 7, ufpc.first_click_ts)
)
, window_totals AS (
    SELECT window_label, COUNT(DISTINCT distinct_id) AS total_plan_clickers
    FROM user_first_plan_click
    GROUP BY window_label
)
SELECT
    ufpc.window_label
  , ufpc.plan_name
  , COUNT(DISTINCT ufpc.distinct_id)                                                          AS plan_clickers
  , COUNT(DISTINCT ufpc.distinct_id)::FLOAT / MAX(wt.total_plan_clickers)                     AS plan_click_share
  , COUNT(DISTINCT ps.distinct_id)                                                            AS subscribers
  , COUNT(DISTINCT ps.distinct_id)::FLOAT / NULLIF(COUNT(DISTINCT ufpc.distinct_id), 0)       AS per_plan_conversion
FROM user_first_plan_click ufpc
LEFT JOIN plan_subs     ps USING (window_label, distinct_id, plan_name)
LEFT JOIN window_totals wt USING (window_label)
GROUP BY ufpc.window_label, ufpc.plan_name
ORDER BY ufpc.window_label, plan_clickers DESC
;


-- =============================================================================
-- Q6: Character diagnostic — composition of pricing visitors per window
-- -----------------------------------------------------------------------------
-- Purpose:       Test whether the pre / post_2wk / post_8wk / post_8wk_clean
--                visitor populations have similar composition on device,
--                country, channel, and logged-in-status axes. If composition
--                drifts materially, naive pre/post deltas are biased.
-- Method:        Per-population share across each rollup dimension. UNION
--                ALL with a discriminator column per
--                feedback_distribution_rollup_substantiation.
-- Export:        q6.csv
-- =============================================================================

WITH windows AS (
    SELECT '1_pre'            AS window_label, '2026-01-07'::date AS start_d, '2026-02-06'::date AS end_d
    UNION ALL SELECT '2_post_2wk'      , '2026-02-24'::date, '2026-03-10'::date
    UNION ALL SELECT '3_post_8wk'      , '2026-02-24'::date, '2026-04-23'::date
    UNION ALL SELECT '4_post_8wk_clean', '2026-02-24'::date, '2026-04-23'::date
)
, visitor_attrs AS (
    -- One row per (window, visitor, event); pick the first pricing-page view's attributes
    SELECT
        w.window_label
      , e.distinct_id
      , e.device
      , e.country
      , e.channel
      , e.is_existing_subscriber
    FROM windows w
    INNER JOIN soundstripe_prod.core.fct_events e
        ON e.event_ts::date BETWEEN w.start_d AND w.end_d
       AND NOT (w.window_label = '4_post_8wk_clean'
                AND e.event_ts::date BETWEEN '2026-03-05' AND '2026-03-25')
    WHERE e.event = 'Viewed Pricing Page'
      AND e.path IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
    QUALIFY ROW_NUMBER() OVER (PARTITION BY w.window_label, e.distinct_id ORDER BY e.event_ts) = 1
)
, window_totals AS (
    SELECT window_label, COUNT(*) AS total_visitors FROM visitor_attrs GROUP BY window_label
)
, device_rollup AS (
    SELECT 'device' AS rollup_dim, window_label, COALESCE(device, '(null)') AS rollup_value, COUNT(*) AS n
    FROM visitor_attrs GROUP BY window_label, rollup_value
)
, country_rollup AS (
    SELECT 'country' AS rollup_dim, window_label, COALESCE(country, '(null)') AS rollup_value, COUNT(*) AS n
    FROM visitor_attrs GROUP BY window_label, rollup_value
)
, channel_rollup AS (
    SELECT 'channel' AS rollup_dim, window_label, COALESCE(channel, '(null/direct)') AS rollup_value, COUNT(*) AS n
    FROM visitor_attrs GROUP BY window_label, rollup_value
)
, existing_sub_rollup AS (
    SELECT 'existing_sub' AS rollup_dim, window_label,
           CASE WHEN is_existing_subscriber = 1 THEN 'existing' ELSE 'non_existing' END AS rollup_value,
           COUNT(*) AS n
    FROM visitor_attrs GROUP BY window_label, rollup_value
)
, combined AS (
    SELECT * FROM device_rollup
    UNION ALL SELECT * FROM country_rollup
    UNION ALL SELECT * FROM channel_rollup
    UNION ALL SELECT * FROM existing_sub_rollup
)
SELECT
    c.rollup_dim
  , c.window_label
  , c.rollup_value
  , c.n
  , c.n::FLOAT / MAX(wt.total_visitors) OVER (PARTITION BY c.window_label)                  AS share_of_visitors
FROM combined c
INNER JOIN window_totals wt USING (window_label)
QUALIFY ROW_NUMBER() OVER (PARTITION BY c.rollup_dim, c.window_label ORDER BY c.n DESC) <= 12
ORDER BY c.rollup_dim, c.window_label, c.n DESC
;


-- =============================================================================
-- Q7: Engagement-based bounce rate (scroll-depth proxy)
-- -----------------------------------------------------------------------------
-- Purpose:       D9 confirmed scroll-depth capture on $mp_page_leave stopped
--                on 2026-02-25 (events still fire at normal volume, property
--                is null). The scroll-based bounce rate the product team
--                reported (39% scrolled <5%) cannot be reproduced for any
--                post window.
--                Q7 substitutes a behavior-based bounce: a pricing-page
--                visitor whose window contains no downstream pricing
--                interaction (no View Pricing click, no persona click, no
--                plan click, no plan-screen control click, no coverage
--                click, no Cart Slideout view, no Checkout Button click).
-- Rate:          engagement_bounce_rate = bouncers / pricing_visitors
--                  NUMERATOR   = distinct_ids with Viewed Pricing Page in
--                                window AND NO engagement event from the
--                                element/event list below in window
--                  DENOMINATOR = distinct_ids with Viewed Pricing Page in window
--                  NOT: scroll-depth bounce (product team's 39%) — that
--                  metric is unrecoverable; this is an engagement-based proxy.
-- Export:        q7.csv
-- =============================================================================

WITH windows AS (
    SELECT '1_pre'            AS window_label, '2026-01-07'::date AS start_d, '2026-02-06'::date AS end_d
    UNION ALL SELECT '2_post_2wk'      , '2026-02-24'::date, '2026-03-10'::date
    UNION ALL SELECT '3_post_8wk'      , '2026-02-24'::date, '2026-04-23'::date
    UNION ALL SELECT '4_post_8wk_clean', '2026-02-24'::date, '2026-04-23'::date
)
, visitors AS (
    SELECT DISTINCT w.window_label, e.distinct_id
    FROM windows w
    INNER JOIN soundstripe_prod.core.fct_events e
        ON e.event_ts::date BETWEEN w.start_d AND w.end_d
       AND NOT (w.window_label = '4_post_8wk_clean'
                AND e.event_ts::date BETWEEN '2026-03-05' AND '2026-03-25')
    WHERE e.event = 'Viewed Pricing Page'
      AND e.path IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
)
, engaged AS (
    SELECT DISTINCT w.window_label, e.distinct_id
    FROM windows w
    INNER JOIN pc_stitch_db.mixpanel.export e
        ON e.time::date BETWEEN w.start_d AND w.end_d
       AND NOT (w.window_label = '4_post_8wk_clean'
                AND e.time::date BETWEEN '2026-03-05' AND '2026-03-25')
    WHERE PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
      AND (
           (e.event = 'Clicked Element' AND e.element IN (
               'View Pricing', 'Choose a Plan',
               'Youtuber/Content Creator', 'Student/Hobbyist', 'Freelancer',
               'Other', 'Podcast', 'Wedding Filmmaker',
               'Pro Yearly', 'Pro Monthly',
               'Personal Yearly', 'Personal Monthly',
               'Pro Plus Yearly', 'Pro Plus Monthly',
               'Business Quarterly', 'Business Yearly',
               'Pro Yearly with Warner Chappell Production Music',
               'Pro Monthly with Warner Chappell Production Music',
               'Pro Plus with Warner Chappell Production Music Yearly',
               'Pro Plus with Warner Chappell Production Music Monthly',
               'Plan tier toggle', 'Open Interval dropdown', 'Interval dropdown option',
               'Checkout Button', 'View Single-use Licenses', 'View Subscriptions',
               'Standard Coverage', 'Extended Coverage'
           ))
        OR (e.event = 'Viewed Cart Slideout')
      )
)
, classified AS (
    SELECT
        v.window_label
      , v.distinct_id
      , CASE WHEN eg.distinct_id IS NULL THEN 1 ELSE 0 END AS is_bouncer
    FROM visitors v
    LEFT JOIN engaged eg USING (window_label, distinct_id)
)
SELECT
    window_label
  , COUNT(*)                                                AS pricing_visitors
  , SUM(is_bouncer)                                         AS bouncers
  , SUM(is_bouncer)::FLOAT / COUNT(*)                       AS engagement_bounce_rate
FROM classified
GROUP BY window_label
ORDER BY window_label
;


-- =============================================================================
-- Q8: Within-cohort decomposition of the funnel by plan_id bucket
-- -----------------------------------------------------------------------------
-- Purpose:       D18 revealed that the +8pp "existing subscriber" visitor-mix
--                shift is really +9pp free-account + -1pp paid. Step 5
--                (Plan → Subscribe) rose from 27.5% to 35.5% cumulatively.
--                This query decomposes every funnel step by the visitor's
--                plan_id bucket (anon / free / paid) at their first Viewed
--                Pricing Page event in window, for pre and post-8wk-clean.
--                Settles whether within-cohort step rates changed or whether
--                the lift is pure composition drift.
-- Rate:          Per (window, plan_bucket, step): users_at_step / visitors_in_bucket
--                for cumulative; users_at_step / users_at_prior_step for step.
-- Export:        q8.csv
-- =============================================================================

WITH windows AS (
    SELECT '1_pre'            AS window_label, '2026-01-07'::date AS start_d, '2026-02-06'::date AS end_d
    UNION ALL SELECT '4_post_8wk_clean', '2026-02-24'::date, '2026-04-23'::date
)
, visitor_attrs AS (
    -- Earliest Viewed Pricing Page per (window, user); carry current_plan_id at that event.
    SELECT
        w.window_label
      , e.distinct_id
      , CASE
            WHEN e.current_plan_id IS NULL                         THEN '1_anon'
            WHEN e.current_plan_id = 'free'                        THEN '2_free'
            ELSE                                                       '3_paid'
        END AS plan_bucket
      , e.time::timestamp AS first_view_ts
    FROM windows w
    INNER JOIN pc_stitch_db.mixpanel.export e
        ON e.time::date BETWEEN w.start_d AND w.end_d
       AND NOT (w.window_label = '4_post_8wk_clean'
                AND e.time::date BETWEEN '2026-03-05' AND '2026-03-25')
    WHERE e.event = 'Viewed Pricing Page'
      AND PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
    QUALIFY ROW_NUMBER() OVER (PARTITION BY w.window_label, e.distinct_id ORDER BY e.time) = 1
)
, entered_flow AS (
    SELECT DISTINCT va.window_label, va.distinct_id, va.plan_bucket
    FROM visitor_attrs va
    INNER JOIN pc_stitch_db.mixpanel.export e
        ON e.distinct_id = va.distinct_id
    INNER JOIN windows w
        ON va.window_label = w.window_label
       AND e.time::date BETWEEN w.start_d AND w.end_d
       AND NOT (w.window_label = '4_post_8wk_clean'
                AND e.time::date BETWEEN '2026-03-05' AND '2026-03-25')
    WHERE e.event = 'Clicked Element'
      AND e.element IN ('View Pricing', 'Choose a Plan')
      AND PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
)
, persona_selectors AS (
    SELECT DISTINCT va.window_label, va.distinct_id, va.plan_bucket
    FROM visitor_attrs va
    INNER JOIN pc_stitch_db.mixpanel.export e
        ON e.distinct_id = va.distinct_id
    INNER JOIN windows w
        ON va.window_label = w.window_label
       AND e.time::date BETWEEN w.start_d AND w.end_d
       AND NOT (w.window_label = '4_post_8wk_clean'
                AND e.time::date BETWEEN '2026-03-05' AND '2026-03-25')
    WHERE e.event = 'Clicked Element'
      AND e.element IN ('Youtuber/Content Creator', 'Student/Hobbyist', 'Freelancer',
                         'Other', 'Podcast', 'Wedding Filmmaker')
      AND PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
)
, plan_clickers AS (
    SELECT DISTINCT va.window_label, va.distinct_id, va.plan_bucket
    FROM visitor_attrs va
    INNER JOIN pc_stitch_db.mixpanel.export e
        ON e.distinct_id = va.distinct_id
    INNER JOIN windows w
        ON va.window_label = w.window_label
       AND e.time::date BETWEEN w.start_d AND w.end_d
       AND NOT (w.window_label = '4_post_8wk_clean'
                AND e.time::date BETWEEN '2026-03-05' AND '2026-03-25')
    WHERE e.event = 'Clicked Element'
      AND e.element IN ('Pro Yearly', 'Pro Monthly',
                         'Personal Yearly', 'Personal Monthly',
                         'Pro Plus Yearly', 'Pro Plus Monthly',
                         'Business Quarterly', 'Business Yearly',
                         'Pro Yearly with Warner Chappell Production Music',
                         'Pro Monthly with Warner Chappell Production Music',
                         'Pro Plus with Warner Chappell Production Music Yearly',
                         'Pro Plus with Warner Chappell Production Music Monthly')
      AND PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
)
, subscribers AS (
    SELECT DISTINCT va.window_label, va.distinct_id, va.plan_bucket
    FROM visitor_attrs va
    INNER JOIN soundstripe_prod.core.fct_events s
        ON s.distinct_id = va.distinct_id
       AND s.event       = 'Created Subscription'
       AND s.event_ts   >= va.first_view_ts
       AND s.event_ts   <  DATEADD('day', 7, va.first_view_ts)
)
, steps AS (
    SELECT window_label, plan_bucket, 1 AS step_order, 'Pricing Visitors'     AS step, COUNT(*) AS n FROM visitor_attrs     GROUP BY window_label, plan_bucket
    UNION ALL SELECT window_label, plan_bucket, 2, 'Entered Persona Flow', COUNT(*) FROM entered_flow      GROUP BY window_label, plan_bucket
    UNION ALL SELECT window_label, plan_bucket, 3, 'Selected Persona'    , COUNT(*) FROM persona_selectors GROUP BY window_label, plan_bucket
    UNION ALL SELECT window_label, plan_bucket, 4, 'Clicked Plan'        , COUNT(*) FROM plan_clickers     GROUP BY window_label, plan_bucket
    UNION ALL SELECT window_label, plan_bucket, 5, 'Subscribed'          , COUNT(*) FROM subscribers       GROUP BY window_label, plan_bucket
)
SELECT
    window_label
  , plan_bucket
  , step_order
  , step
  , n
  , n::FLOAT / FIRST_VALUE(n) OVER (PARTITION BY window_label, plan_bucket ORDER BY step_order)  AS cumulative_rate
  , n::FLOAT / LAG(n)         OVER (PARTITION BY window_label, plan_bucket ORDER BY step_order)  AS step_rate
FROM steps
ORDER BY window_label, plan_bucket, step_order
;


-- =============================================================================
-- Q9: Correctly-attributed plan-click → subscribe rate
-- -----------------------------------------------------------------------------
-- CONTEXT:       Q3 and Q8 computed step 5 (plan-clicker → subscriber) by
--                dividing total subscribers (= pricing visitors who
--                subscribed within 7d of any pricing VIEW) by total plan-
--                clickers. The numerator does NOT require plan-click
--                precedent — users who subscribed via account / email /
--                dashboard upgrades without clicking a plan on pricing
--                were counted. The result was implausibly high step-5
--                rates (27.5% → 35.5% aggregate; 53-65% for free cohort)
--                compared to product team's 7.3% — the tell I missed.
-- Purpose:       Proper plan-click → subscribe attribution: count users
--                who (a) clicked a plan-name element on a pricing URL in
--                window AND (b) created a subscription within 7 days of
--                THAT plan click. Subscribe attributes to the plan click,
--                not the pricing view.
-- Rate:          plan_click_to_subscribe = users_in_both / plan_clickers
-- Export:        q9.csv
-- =============================================================================

WITH windows AS (
    SELECT '1_pre'            AS window_label, '2026-01-07'::date AS start_d, '2026-02-06'::date AS end_d
    UNION ALL SELECT '2_post_2wk'      , '2026-02-24'::date, '2026-03-10'::date
    UNION ALL SELECT '3_post_8wk'      , '2026-02-24'::date, '2026-04-23'::date
    UNION ALL SELECT '4_post_8wk_clean', '2026-02-24'::date, '2026-04-23'::date
)
, visitor_attrs AS (
    SELECT
        w.window_label
      , e.distinct_id
      , CASE
            WHEN e.current_plan_id IS NULL                         THEN '1_anon'
            WHEN e.current_plan_id = 'free'                        THEN '2_free'
            ELSE                                                       '3_paid'
        END                                       AS plan_bucket
    FROM windows w
    INNER JOIN pc_stitch_db.mixpanel.export e
        ON e.time::date BETWEEN w.start_d AND w.end_d
       AND NOT (w.window_label = '4_post_8wk_clean'
                AND e.time::date BETWEEN '2026-03-05' AND '2026-03-25')
    WHERE e.event = 'Viewed Pricing Page'
      AND PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
    QUALIFY ROW_NUMBER() OVER (PARTITION BY w.window_label, e.distinct_id ORDER BY e.time) = 1
)
, plan_click_events AS (
    -- Per (window, user, plan_bucket): earliest plan-name element click on a
    -- pricing URL in window.
    SELECT
        va.window_label
      , va.distinct_id
      , va.plan_bucket
      , MIN(e.time)::timestamp                    AS first_plan_click_ts
    FROM visitor_attrs va
    INNER JOIN windows w
        ON va.window_label = w.window_label
    INNER JOIN pc_stitch_db.mixpanel.export e
        ON e.distinct_id = va.distinct_id
       AND e.time::date BETWEEN w.start_d AND w.end_d
       AND NOT (va.window_label = '4_post_8wk_clean'
                AND e.time::date BETWEEN '2026-03-05' AND '2026-03-25')
    WHERE e.event = 'Clicked Element'
      AND e.element IN ('Pro Yearly', 'Pro Monthly',
                         'Personal Yearly', 'Personal Monthly',
                         'Pro Plus Yearly', 'Pro Plus Monthly',
                         'Business Quarterly', 'Business Yearly',
                         'Pro Yearly with Warner Chappell Production Music',
                         'Pro Monthly with Warner Chappell Production Music',
                         'Pro Plus with Warner Chappell Production Music Yearly',
                         'Pro Plus with Warner Chappell Production Music Monthly')
      AND PARSE_URL(COALESCE(e.current_url, e.mp_reserved_current_url, e.url)):path::string
          IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')
    GROUP BY va.window_label, va.distinct_id, va.plan_bucket
)
, plan_click_subs AS (
    -- Plan-clickers who then created a subscription within 7 days of their
    -- plan click.
    SELECT DISTINCT
        pce.window_label
      , pce.distinct_id
      , pce.plan_bucket
    FROM plan_click_events pce
    INNER JOIN soundstripe_prod.core.fct_events s
        ON s.distinct_id = pce.distinct_id
       AND s.event       = 'Created Subscription'
       AND s.event_ts   >= pce.first_plan_click_ts
       AND s.event_ts   <  DATEADD('day', 7, pce.first_plan_click_ts)
)
SELECT
    pce.window_label
  , pce.plan_bucket
  , COUNT(DISTINCT pce.distinct_id)                                                     AS plan_clickers
  , COUNT(DISTINCT pcs.distinct_id)                                                     AS plan_click_to_sub
  , COUNT(DISTINCT pcs.distinct_id)::FLOAT / NULLIF(COUNT(DISTINCT pce.distinct_id), 0) AS plan_click_to_subscribe_rate
FROM plan_click_events pce
LEFT JOIN plan_click_subs pcs USING (window_label, distinct_id, plan_bucket)
GROUP BY pce.window_label, pce.plan_bucket

UNION ALL

-- Aggregate row per window (ignore bucket)
SELECT
    pce.window_label
  , '0_all' AS plan_bucket
  , COUNT(DISTINCT pce.distinct_id)
  , COUNT(DISTINCT pcs.distinct_id)
  , COUNT(DISTINCT pcs.distinct_id)::FLOAT / NULLIF(COUNT(DISTINCT pce.distinct_id), 0)
FROM plan_click_events pce
LEFT JOIN plan_click_subs pcs USING (window_label, distinct_id, plan_bucket)
GROUP BY pce.window_label

ORDER BY window_label, plan_bucket
;
