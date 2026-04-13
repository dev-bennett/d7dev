-- XmR Process Behavior Charts -- dim_daily_kpis
-- Purpose: Wheeler XmR (Individuals & Moving Range) for systematic signal detection
-- Author: d7admin
-- Date: 2026-04-03
-- Source: soundstripe_prod.core.dim_daily_kpis
-- Methodology: Wheeler "Understanding Variation" -- natural process limits via average moving range
-- Reference: 2.66 = 3/d2 (d2=1.128 for n=2); 3.267 = D4 for n=2; 1.77 = 2/d2

-- ============================================================================
-- Q1: Single-Metric XmR -- VISITORS (proof of concept)
-- ============================================================================
-- Full XmR chart for one metric. Validates the methodology before scaling.
-- Configurable baseline window at the top of the CTE chain.

WITH config AS (
    SELECT
        '2025-01-01'::DATE AS baseline_start
        ,'2025-03-31'::DATE AS baseline_end
        ,'2025-01-01'::DATE AS data_start
)

,source_data AS (
    SELECT
        k.date
        ,NVL(k.visitors, 0) AS value
    FROM soundstripe_prod.core.dim_daily_kpis k
        CROSS JOIN config c
    WHERE k.date >= c.data_start
)

,with_moving_range AS (
    SELECT
        s.date
        ,s.value
        ,ABS(s.value - LAG(s.value, 1) OVER (ORDER BY s.date)) AS mr
    FROM source_data s
)

,baseline_stats AS (
    SELECT
        AVG(w.value) AS x_bar
        ,AVG(w.mr) AS mr_bar
    FROM with_moving_range w
        CROSS JOIN config c
    WHERE w.date BETWEEN c.baseline_start AND c.baseline_end
      AND w.mr IS NOT NULL
)

,xmr_chart AS (
    SELECT
        w.date
        ,w.value
        ,w.mr
        ,b.x_bar
        ,b.mr_bar
        ,b.x_bar + 2.66 * b.mr_bar AS unpl
        ,GREATEST(0, b.x_bar - 2.66 * b.mr_bar) AS lnpl
        ,3.267 * b.mr_bar AS url
        ,b.x_bar + 1.77 * b.mr_bar AS two_sigma_upper
        ,GREATEST(0, b.x_bar - 1.77 * b.mr_bar) AS two_sigma_lower
        -- Rule 1: point beyond natural process limits
        ,CASE
            WHEN w.value > b.x_bar + 2.66 * b.mr_bar THEN TRUE
            WHEN w.value < GREATEST(0, b.x_bar - 2.66 * b.mr_bar) THEN TRUE
            ELSE FALSE
         END AS signal_rule_1
        -- mR signal: moving range exceeds upper range limit
        ,CASE WHEN w.mr > 3.267 * b.mr_bar THEN TRUE ELSE FALSE END AS mr_signal
        -- Prep for Rule 2 (run of 8)
        ,CASE
            WHEN w.value > b.x_bar THEN 1
            WHEN w.value < b.x_bar THEN -1
            ELSE 0
         END AS side_of_center
        -- Prep for Rule 3 (2 of 3 beyond 2-sigma)
        ,CASE
            WHEN w.value > b.x_bar + 1.77 * b.mr_bar
              OR w.value < GREATEST(0, b.x_bar - 1.77 * b.mr_bar)
            THEN 1 ELSE 0
         END AS beyond_2sigma
    FROM with_moving_range w
        CROSS JOIN baseline_stats b
)

,with_runs AS (
    SELECT
        x.*
        ,ROW_NUMBER() OVER (ORDER BY x.date)
         - ROW_NUMBER() OVER (PARTITION BY x.side_of_center ORDER BY x.date) AS run_group
    FROM xmr_chart x
)

,with_run_lengths AS (
    SELECT
        r.*
        ,COUNT(*) OVER (PARTITION BY r.side_of_center, r.run_group) AS run_length
    FROM with_runs r
)

SELECT
    rl.date
    ,rl.value
    ,rl.mr
    ,ROUND(rl.x_bar, 2) AS x_bar
    ,ROUND(rl.mr_bar, 2) AS mr_bar
    ,ROUND(rl.unpl, 2) AS unpl
    ,ROUND(rl.lnpl, 2) AS lnpl
    ,ROUND(rl.url, 2) AS url
    ,ROUND(rl.two_sigma_upper, 2) AS two_sigma_upper
    ,ROUND(rl.two_sigma_lower, 2) AS two_sigma_lower
    ,rl.signal_rule_1
    ,CASE WHEN rl.run_length >= 8 AND rl.side_of_center != 0 THEN TRUE ELSE FALSE END AS signal_rule_2
    ,CASE
        WHEN rl.beyond_2sigma = 1
         AND SUM(rl.beyond_2sigma) OVER (ORDER BY rl.date ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) >= 2
        THEN TRUE ELSE FALSE
     END AS signal_rule_3
    ,rl.mr_signal
    ,CASE
        WHEN rl.signal_rule_1
          OR (rl.run_length >= 8 AND rl.side_of_center != 0)
          OR rl.mr_signal
          OR (rl.beyond_2sigma = 1
              AND SUM(rl.beyond_2sigma) OVER (ORDER BY rl.date ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) >= 2)
        THEN TRUE ELSE FALSE
     END AS any_signal
FROM with_run_lengths rl
ORDER BY rl.date
;


-- ============================================================================
-- Q2: Multi-Metric XmR via UNPIVOT
-- ============================================================================
-- Converts the wide table to tall format and computes XmR for ~25 metrics.
-- NVL handles NULLs from LEFT JOINed columns; ABS flips CHURNED_SUBSCRIBERS.

WITH config AS (
    SELECT
        '2025-01-01'::DATE AS baseline_start
        ,'2025-03-31'::DATE AS baseline_end
        ,'2023-01-01'::DATE AS data_start
)

,source_wide AS (
    SELECT
        k.date
        -- All columns cast to FLOAT for UNPIVOT type compatibility
        ,k.active_subscribers::FLOAT AS active_subscribers
        ,k.active_monthly_subscribers::FLOAT AS active_monthly_subscribers
        ,k.active_yearly_subscribers::FLOAT AS active_yearly_subscribers
        ,k.new_subscribers::FLOAT AS new_subscribers
        ,ABS(k.churned_subscribers)::FLOAT AS churned_subscribers
        ,k.net_chg_active_subscribers::FLOAT AS net_chg_active_subscribers
        ,k.mrr::FLOAT AS mrr
        ,k.arr::FLOAT AS arr
        ,k.net_chg_mrr::FLOAT AS net_chg_mrr
        ,NVL(k.visitors, 0)::FLOAT AS visitors
        ,NVL(k.sessions, 0)::FLOAT AS sessions
        ,NVL(k.core_visitors, 0)::FLOAT AS core_visitors
        ,NVL(k.enterprise_form_submissions, 0)::FLOAT AS enterprise_form_submissions
        ,NVL(k.spend, 0)::FLOAT AS spend
        ,NVL(k.core_spend, 0)::FLOAT AS core_spend
        ,NVL(k.impressions, 0)::FLOAT AS impressions
        ,NVL(k.clicks, 0)::FLOAT AS clicks
        ,NVL(k.paid_search_spend, 0)::FLOAT AS paid_search_spend
        ,NVL(k.paid_search_impressions, 0)::FLOAT AS paid_search_impressions
        ,NVL(k.paid_search_clicks, 0)::FLOAT AS paid_search_clicks
        ,NVL(k.paid_social_spend, 0)::FLOAT AS paid_social_spend
        ,NVL(k.paid_social_impressions, 0)::FLOAT AS paid_social_impressions
        ,NVL(k.paid_social_clicks, 0)::FLOAT AS paid_social_clicks
        ,NVL(k.display_spend, 0)::FLOAT AS display_spend
        ,NVL(k.display_impressions, 0)::FLOAT AS display_impressions
        ,NVL(k.display_clicks, 0)::FLOAT AS display_clicks
        ,NVL(k.mixpanel_subscriptions, 0)::FLOAT AS mixpanel_subscriptions
        ,NVL(k.core_mixpanel_subscriptions, 0)::FLOAT AS core_mixpanel_subscriptions
        ,NVL(k.direct_subscriptions, 0)::FLOAT AS direct_subscriptions
        ,NVL(k.organic_search_subscriptions, 0)::FLOAT AS organic_search_subscriptions
        ,NVL(k.paid_search_subscriptions, 0)::FLOAT AS paid_search_subscriptions
        ,NVL(k.total_transactions, 0)::FLOAT AS total_transactions
        ,NVL(k.single_song_rev, 0)::FLOAT AS single_song_rev
    FROM soundstripe_prod.core.dim_daily_kpis k
        CROSS JOIN config c
    WHERE k.date >= c.data_start
)

,unpivoted AS (
    SELECT
        date
        ,metric_name
        ,metric_value
    FROM source_wide
    UNPIVOT (metric_value FOR metric_name IN (
        active_subscribers
        ,active_monthly_subscribers
        ,active_yearly_subscribers
        ,new_subscribers
        ,churned_subscribers
        ,net_chg_active_subscribers
        ,mrr
        ,arr
        ,net_chg_mrr
        ,visitors
        ,sessions
        ,core_visitors
        ,enterprise_form_submissions
        ,spend
        ,core_spend
        ,impressions
        ,clicks
        ,paid_search_spend
        ,paid_search_impressions
        ,paid_search_clicks
        ,paid_social_spend
        ,paid_social_impressions
        ,paid_social_clicks
        ,display_spend
        ,display_impressions
        ,display_clicks
        ,mixpanel_subscriptions
        ,core_mixpanel_subscriptions
        ,direct_subscriptions
        ,organic_search_subscriptions
        ,paid_search_subscriptions
        ,total_transactions
        ,single_song_rev
    ))
)

,with_moving_range AS (
    SELECT
        u.date
        ,u.metric_name
        ,u.metric_value
        ,ABS(u.metric_value - LAG(u.metric_value, 1) OVER (
            PARTITION BY u.metric_name ORDER BY u.date
        )) AS mr
    FROM unpivoted u
)

,baseline_stats AS (
    SELECT
        w.metric_name
        ,AVG(w.metric_value) AS x_bar
        ,AVG(w.mr) AS mr_bar
    FROM with_moving_range w
        CROSS JOIN config c
    WHERE w.date BETWEEN c.baseline_start AND c.baseline_end
      AND w.mr IS NOT NULL
    GROUP BY 1
)

,xmr_chart AS (
    SELECT
        w.date
        ,w.metric_name
        ,w.metric_value
        ,w.mr
        ,b.x_bar
        ,b.mr_bar
        ,b.x_bar + 2.66 * b.mr_bar AS unpl
        ,GREATEST(0, b.x_bar - 2.66 * b.mr_bar) AS lnpl
        ,3.267 * b.mr_bar AS url
        ,CASE
            WHEN w.metric_value > b.x_bar + 2.66 * b.mr_bar THEN TRUE
            WHEN w.metric_value < GREATEST(0, b.x_bar - 2.66 * b.mr_bar) THEN TRUE
            ELSE FALSE
         END AS signal_rule_1
        ,CASE WHEN w.mr > 3.267 * b.mr_bar THEN TRUE ELSE FALSE END AS mr_signal
        ,CASE
            WHEN w.metric_value > b.x_bar THEN 1
            WHEN w.metric_value < b.x_bar THEN -1
            ELSE 0
         END AS side_of_center
        ,CASE
            WHEN w.metric_value > b.x_bar + 1.77 * b.mr_bar
              OR w.metric_value < GREATEST(0, b.x_bar - 1.77 * b.mr_bar)
            THEN 1 ELSE 0
         END AS beyond_2sigma
    FROM with_moving_range w
        INNER JOIN baseline_stats b
            ON w.metric_name = b.metric_name
)

,with_runs AS (
    SELECT
        x.*
        ,ROW_NUMBER() OVER (PARTITION BY x.metric_name ORDER BY x.date)
         - ROW_NUMBER() OVER (PARTITION BY x.metric_name, x.side_of_center ORDER BY x.date) AS run_group
    FROM xmr_chart x
)

,with_run_lengths AS (
    SELECT
        r.*
        ,COUNT(*) OVER (PARTITION BY r.metric_name, r.side_of_center, r.run_group) AS run_length
    FROM with_runs r
)

SELECT
    rl.date
    ,rl.metric_name
    ,rl.metric_value
    ,rl.mr
    ,ROUND(rl.x_bar, 2) AS x_bar
    ,ROUND(rl.mr_bar, 2) AS mr_bar
    ,ROUND(rl.unpl, 2) AS unpl
    ,ROUND(rl.lnpl, 2) AS lnpl
    ,ROUND(rl.url, 2) AS url
    ,rl.signal_rule_1
    ,CASE WHEN rl.run_length >= 8 AND rl.side_of_center != 0 THEN TRUE ELSE FALSE END AS signal_rule_2
    ,CASE
        WHEN rl.beyond_2sigma = 1
         AND SUM(rl.beyond_2sigma) OVER (
             PARTITION BY rl.metric_name ORDER BY rl.date
             ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
         ) >= 2
        THEN TRUE ELSE FALSE
     END AS signal_rule_3
    ,rl.mr_signal
    ,CASE
        WHEN rl.signal_rule_1
          OR (rl.run_length >= 8 AND rl.side_of_center != 0)
          OR rl.mr_signal
          OR (rl.beyond_2sigma = 1
              AND SUM(rl.beyond_2sigma) OVER (
                  PARTITION BY rl.metric_name ORDER BY rl.date
                  ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
              ) >= 2)
        THEN TRUE ELSE FALSE
     END AS any_signal
FROM with_run_lengths rl
ORDER BY rl.metric_name, rl.date
;


-- ============================================================================
-- Q3: DOW-Stratified XmR -- Traffic & Marketing Metrics
-- ============================================================================
-- Compares each Monday to prior Mondays, each Tuesday to prior Tuesdays, etc.
-- Eliminates day-of-week seasonality from the control limits.

WITH config AS (
    SELECT
        '2025-01-01'::DATE AS baseline_start
        ,'2025-03-31'::DATE AS baseline_end
        ,'2023-01-01'::DATE AS data_start
)

,source_wide AS (
    SELECT
        k.date
        ,DAYOFWEEK(k.date) AS dow
        ,NVL(k.visitors, 0)::FLOAT AS visitors
        ,NVL(k.sessions, 0)::FLOAT AS sessions
        ,NVL(k.core_visitors, 0)::FLOAT AS core_visitors
        ,NVL(k.spend, 0)::FLOAT AS spend
        ,NVL(k.core_spend, 0)::FLOAT AS core_spend
        ,NVL(k.impressions, 0)::FLOAT AS impressions
        ,NVL(k.clicks, 0)::FLOAT AS clicks
        ,NVL(k.paid_search_spend, 0)::FLOAT AS paid_search_spend
        ,NVL(k.paid_search_impressions, 0)::FLOAT AS paid_search_impressions
        ,NVL(k.paid_search_clicks, 0)::FLOAT AS paid_search_clicks
        ,NVL(k.paid_social_spend, 0)::FLOAT AS paid_social_spend
        ,NVL(k.paid_social_impressions, 0)::FLOAT AS paid_social_impressions
    FROM soundstripe_prod.core.dim_daily_kpis k
        CROSS JOIN config c
    WHERE k.date >= c.data_start
)

,unpivoted AS (
    SELECT
        date
        ,dow
        ,metric_name
        ,metric_value
    FROM source_wide
    UNPIVOT (metric_value FOR metric_name IN (
        visitors
        ,sessions
        ,core_visitors
        ,spend
        ,core_spend
        ,impressions
        ,clicks
        ,paid_search_spend
        ,paid_search_impressions
        ,paid_search_clicks
        ,paid_social_spend
        ,paid_social_impressions
    ))
)

,with_moving_range AS (
    SELECT
        u.date
        ,u.dow
        ,u.metric_name
        ,u.metric_value
        ,ABS(u.metric_value - LAG(u.metric_value, 1) OVER (
            PARTITION BY u.metric_name, u.dow ORDER BY u.date
        )) AS mr
    FROM unpivoted u
)

,baseline_stats AS (
    SELECT
        w.metric_name
        ,w.dow
        ,AVG(w.metric_value) AS x_bar
        ,AVG(w.mr) AS mr_bar
    FROM with_moving_range w
        CROSS JOIN config c
    WHERE w.date BETWEEN c.baseline_start AND c.baseline_end
      AND w.mr IS NOT NULL
    GROUP BY 1, 2
)

,xmr_chart AS (
    SELECT
        w.date
        ,w.dow
        ,w.metric_name
        ,w.metric_value
        ,w.mr
        ,b.x_bar
        ,b.mr_bar
        ,b.x_bar + 2.66 * b.mr_bar AS unpl
        ,GREATEST(0, b.x_bar - 2.66 * b.mr_bar) AS lnpl
        ,3.267 * b.mr_bar AS url
        ,CASE
            WHEN w.metric_value > b.x_bar + 2.66 * b.mr_bar THEN TRUE
            WHEN w.metric_value < GREATEST(0, b.x_bar - 2.66 * b.mr_bar) THEN TRUE
            ELSE FALSE
         END AS signal_rule_1
        ,CASE WHEN w.mr > 3.267 * b.mr_bar THEN TRUE ELSE FALSE END AS mr_signal
        ,CASE
            WHEN w.metric_value > b.x_bar THEN 1
            WHEN w.metric_value < b.x_bar THEN -1
            ELSE 0
         END AS side_of_center
        ,CASE
            WHEN w.metric_value > b.x_bar + 1.77 * b.mr_bar
              OR w.metric_value < GREATEST(0, b.x_bar - 1.77 * b.mr_bar)
            THEN 1 ELSE 0
         END AS beyond_2sigma
    FROM with_moving_range w
        INNER JOIN baseline_stats b
            ON w.metric_name = b.metric_name
            AND w.dow = b.dow
)

,with_runs AS (
    SELECT
        x.*
        ,ROW_NUMBER() OVER (PARTITION BY x.metric_name, x.dow ORDER BY x.date)
         - ROW_NUMBER() OVER (PARTITION BY x.metric_name, x.dow, x.side_of_center ORDER BY x.date) AS run_group
    FROM xmr_chart x
)

,with_run_lengths AS (
    SELECT
        r.*
        ,COUNT(*) OVER (PARTITION BY r.metric_name, r.dow, r.side_of_center, r.run_group) AS run_length
    FROM with_runs r
)

SELECT
    rl.date
    ,rl.dow
    ,rl.metric_name
    ,rl.metric_value
    ,rl.mr
    ,ROUND(rl.x_bar, 2) AS x_bar
    ,ROUND(rl.mr_bar, 2) AS mr_bar
    ,ROUND(rl.unpl, 2) AS unpl
    ,ROUND(rl.lnpl, 2) AS lnpl
    ,ROUND(rl.url, 2) AS url
    ,rl.signal_rule_1
    ,CASE WHEN rl.run_length >= 8 AND rl.side_of_center != 0 THEN TRUE ELSE FALSE END AS signal_rule_2
    ,CASE
        WHEN rl.beyond_2sigma = 1
         AND SUM(rl.beyond_2sigma) OVER (
             PARTITION BY rl.metric_name, rl.dow ORDER BY rl.date
             ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
         ) >= 2
        THEN TRUE ELSE FALSE
     END AS signal_rule_3
    ,rl.mr_signal
    ,CASE
        WHEN rl.signal_rule_1
          OR (rl.run_length >= 8 AND rl.side_of_center != 0)
          OR rl.mr_signal
          OR (rl.beyond_2sigma = 1
              AND SUM(rl.beyond_2sigma) OVER (
                  PARTITION BY rl.metric_name, rl.dow ORDER BY rl.date
                  ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
              ) >= 2)
        THEN TRUE ELSE FALSE
     END AS any_signal
FROM with_run_lengths rl
ORDER BY rl.metric_name, rl.dow, rl.date
;


-- ============================================================================
-- Q4: Year-over-Year Delta XmR
-- ============================================================================
-- Removes seasonality by charting (current - LY) as the individual value.
-- Limits reflect the normal range of year-over-year change, not the raw level.
-- Requires LY_* columns to be non-NULL, so data starts ~2024-01-01.

WITH config AS (
    SELECT
        '2024-01-01'::DATE AS baseline_start
        ,'2024-12-31'::DATE AS baseline_end
        ,'2024-01-01'::DATE AS data_start
)

,source_wide AS (
    SELECT
        k.date
        ,(k.active_subscribers - k.ly_active_subscribers)::FLOAT AS delta_active_subscribers
        ,(k.mrr - k.ly_mrr)::FLOAT AS delta_mrr
        ,(k.arr - k.ly_arr)::FLOAT AS delta_arr
        ,(NVL(k.visitors, 0) - NVL(k.ly_visitors, 0))::FLOAT AS delta_visitors
        ,(NVL(k.spend, 0) - NVL(k.ly_spend, 0))::FLOAT AS delta_spend
        ,(NVL(k.core_spend, 0) - NVL(k.ly_core_spend, 0))::FLOAT AS delta_core_spend
        ,(NVL(k.core_visitors, 0) - NVL(k.ly_core_visitors, 0))::FLOAT AS delta_core_visitors
    FROM soundstripe_prod.core.dim_daily_kpis k
        CROSS JOIN config c
    WHERE k.date >= c.data_start
      AND k.ly_active_subscribers IS NOT NULL  -- only rows with valid LY data
)

,unpivoted AS (
    SELECT
        date
        ,metric_name
        ,metric_value
    FROM source_wide
    UNPIVOT (metric_value FOR metric_name IN (
        delta_active_subscribers
        ,delta_mrr
        ,delta_arr
        ,delta_visitors
        ,delta_spend
        ,delta_core_spend
        ,delta_core_visitors
    ))
)

,with_moving_range AS (
    SELECT
        u.date
        ,u.metric_name
        ,u.metric_value
        ,ABS(u.metric_value - LAG(u.metric_value, 1) OVER (
            PARTITION BY u.metric_name ORDER BY u.date
        )) AS mr
    FROM unpivoted u
)

,baseline_stats AS (
    SELECT
        w.metric_name
        ,AVG(w.metric_value) AS x_bar
        ,AVG(w.mr) AS mr_bar
    FROM with_moving_range w
        CROSS JOIN config c
    WHERE w.date BETWEEN c.baseline_start AND c.baseline_end
      AND w.mr IS NOT NULL
    GROUP BY 1
)

,xmr_chart AS (
    SELECT
        w.date
        ,w.metric_name
        ,w.metric_value
        ,w.mr
        ,b.x_bar
        ,b.mr_bar
        ,b.x_bar + 2.66 * b.mr_bar AS unpl
        ,b.x_bar - 2.66 * b.mr_bar AS lnpl  -- no floor at 0: deltas can be negative
        ,3.267 * b.mr_bar AS url
        ,CASE
            WHEN w.metric_value > b.x_bar + 2.66 * b.mr_bar THEN TRUE
            WHEN w.metric_value < b.x_bar - 2.66 * b.mr_bar THEN TRUE
            ELSE FALSE
         END AS signal_rule_1
        ,CASE WHEN w.mr > 3.267 * b.mr_bar THEN TRUE ELSE FALSE END AS mr_signal
        ,CASE
            WHEN w.metric_value > b.x_bar THEN 1
            WHEN w.metric_value < b.x_bar THEN -1
            ELSE 0
         END AS side_of_center
        ,CASE
            WHEN w.metric_value > b.x_bar + 1.77 * b.mr_bar
              OR w.metric_value < b.x_bar - 1.77 * b.mr_bar
            THEN 1 ELSE 0
         END AS beyond_2sigma
    FROM with_moving_range w
        INNER JOIN baseline_stats b
            ON w.metric_name = b.metric_name
)

,with_runs AS (
    SELECT
        x.*
        ,ROW_NUMBER() OVER (PARTITION BY x.metric_name ORDER BY x.date)
         - ROW_NUMBER() OVER (PARTITION BY x.metric_name, x.side_of_center ORDER BY x.date) AS run_group
    FROM xmr_chart x
)

,with_run_lengths AS (
    SELECT
        r.*
        ,COUNT(*) OVER (PARTITION BY r.metric_name, r.side_of_center, r.run_group) AS run_length
    FROM with_runs r
)

SELECT
    rl.date
    ,rl.metric_name
    ,rl.metric_value AS yoy_delta
    ,rl.mr
    ,ROUND(rl.x_bar, 2) AS x_bar
    ,ROUND(rl.mr_bar, 2) AS mr_bar
    ,ROUND(rl.unpl, 2) AS unpl
    ,ROUND(rl.lnpl, 2) AS lnpl
    ,ROUND(rl.url, 2) AS url
    ,rl.signal_rule_1
    ,CASE WHEN rl.run_length >= 8 AND rl.side_of_center != 0 THEN TRUE ELSE FALSE END AS signal_rule_2
    ,CASE
        WHEN rl.beyond_2sigma = 1
         AND SUM(rl.beyond_2sigma) OVER (
             PARTITION BY rl.metric_name ORDER BY rl.date
             ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
         ) >= 2
        THEN TRUE ELSE FALSE
     END AS signal_rule_3
    ,rl.mr_signal
    ,CASE
        WHEN rl.signal_rule_1
          OR (rl.run_length >= 8 AND rl.side_of_center != 0)
          OR rl.mr_signal
          OR (rl.beyond_2sigma = 1
              AND SUM(rl.beyond_2sigma) OVER (
                  PARTITION BY rl.metric_name ORDER BY rl.date
                  ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
              ) >= 2)
        THEN TRUE ELSE FALSE
     END AS any_signal
FROM with_run_lengths rl
ORDER BY rl.metric_name, rl.date
;


-- ============================================================================
-- Q5: Signal Summary Dashboard
-- ============================================================================
-- One row per metric: latest value, limit proximity, active signals.
-- Combines standard XmR (Q2) and YoY delta (Q4) results.
-- Designed as the daily check query.

WITH config AS (
    SELECT
        '2025-01-01'::DATE AS baseline_start
        ,'2025-03-31'::DATE AS baseline_end
        ,'2024-01-01'::DATE AS yoy_baseline_start
        ,'2024-12-31'::DATE AS yoy_baseline_end
        ,'2023-01-01'::DATE AS data_start
)

-- ---- Standard XmR (same logic as Q2, condensed) ----
,std_source AS (
    SELECT
        k.date
        ,k.active_subscribers::FLOAT AS active_subscribers
        ,k.active_monthly_subscribers::FLOAT AS active_monthly_subscribers
        ,k.active_yearly_subscribers::FLOAT AS active_yearly_subscribers
        ,k.new_subscribers::FLOAT AS new_subscribers
        ,ABS(k.churned_subscribers)::FLOAT AS churned_subscribers
        ,k.net_chg_active_subscribers::FLOAT AS net_chg_active_subscribers
        ,k.mrr::FLOAT AS mrr
        ,k.net_chg_mrr::FLOAT AS net_chg_mrr
        ,NVL(k.visitors, 0)::FLOAT AS visitors
        ,NVL(k.sessions, 0)::FLOAT AS sessions
        ,NVL(k.core_visitors, 0)::FLOAT AS core_visitors
        ,NVL(k.spend, 0)::FLOAT AS spend
        ,NVL(k.core_spend, 0)::FLOAT AS core_spend
        ,NVL(k.mixpanel_subscriptions, 0)::FLOAT AS mixpanel_subscriptions
        ,NVL(k.core_mixpanel_subscriptions, 0)::FLOAT AS core_mixpanel_subscriptions
        ,NVL(k.total_transactions, 0)::FLOAT AS total_transactions
    FROM soundstripe_prod.core.dim_daily_kpis k
        CROSS JOIN config c
    WHERE k.date >= c.data_start
)

,std_unpivoted AS (
    SELECT date, metric_name, metric_value
    FROM std_source
    UNPIVOT (metric_value FOR metric_name IN (
        active_subscribers, active_monthly_subscribers, active_yearly_subscribers
        ,new_subscribers, churned_subscribers, net_chg_active_subscribers
        ,mrr, net_chg_mrr
        ,visitors, sessions, core_visitors
        ,spend, core_spend
        ,mixpanel_subscriptions, core_mixpanel_subscriptions
        ,total_transactions
    ))
)

,std_mr AS (
    SELECT
        date, metric_name, metric_value
        ,ABS(metric_value - LAG(metric_value, 1) OVER (
            PARTITION BY metric_name ORDER BY date
        )) AS mr
    FROM std_unpivoted
)

,std_baseline AS (
    SELECT
        metric_name
        ,AVG(metric_value) AS x_bar
        ,AVG(mr) AS mr_bar
    FROM std_mr
        CROSS JOIN config c
    WHERE date BETWEEN c.baseline_start AND c.baseline_end
      AND mr IS NOT NULL
    GROUP BY 1
)

,std_latest AS (
    SELECT
        m.metric_name
        ,'STANDARD' AS xmr_type
        ,m.date
        ,m.metric_value AS latest_value
        ,b.x_bar
        ,b.mr_bar
        ,b.x_bar + 2.66 * b.mr_bar AS unpl
        ,GREATEST(0, b.x_bar - 2.66 * b.mr_bar) AS lnpl
        ,CASE
            WHEN m.metric_value > b.x_bar + 2.66 * b.mr_bar THEN TRUE
            WHEN m.metric_value < GREATEST(0, b.x_bar - 2.66 * b.mr_bar) THEN TRUE
            ELSE FALSE
         END AS beyond_limits
        ,CASE
            WHEN b.mr_bar = 0 THEN NULL
            ELSE ROUND(
                (m.metric_value - b.x_bar) / (2.66 * b.mr_bar) * 100
            , 1)
         END AS pct_to_limit  -- negative=below center, >100=beyond UNPL, <-100=beyond LNPL
    FROM std_mr m
        INNER JOIN std_baseline b ON m.metric_name = b.metric_name
    QUALIFY ROW_NUMBER() OVER (PARTITION BY m.metric_name ORDER BY m.date DESC) = 1
)

-- ---- YoY Delta XmR (same logic as Q4, condensed) ----
,yoy_source AS (
    SELECT
        k.date
        ,(k.active_subscribers - k.ly_active_subscribers)::FLOAT AS delta_active_subscribers
        ,(k.mrr - k.ly_mrr)::FLOAT AS delta_mrr
        ,(NVL(k.visitors, 0) - NVL(k.ly_visitors, 0))::FLOAT AS delta_visitors
        ,(NVL(k.spend, 0) - NVL(k.ly_spend, 0))::FLOAT AS delta_spend
        ,(NVL(k.core_visitors, 0) - NVL(k.ly_core_visitors, 0))::FLOAT AS delta_core_visitors
        ,(NVL(k.core_spend, 0) - NVL(k.ly_core_spend, 0))::FLOAT AS delta_core_spend
    FROM soundstripe_prod.core.dim_daily_kpis k
        CROSS JOIN config c
    WHERE k.date >= '2024-01-01'
      AND k.ly_active_subscribers IS NOT NULL
)

,yoy_unpivoted AS (
    SELECT date, metric_name, metric_value
    FROM yoy_source
    UNPIVOT (metric_value FOR metric_name IN (
        delta_active_subscribers, delta_mrr
        ,delta_visitors, delta_spend
        ,delta_core_visitors, delta_core_spend
    ))
)

,yoy_mr AS (
    SELECT
        date, metric_name, metric_value
        ,ABS(metric_value - LAG(metric_value, 1) OVER (
            PARTITION BY metric_name ORDER BY date
        )) AS mr
    FROM yoy_unpivoted
)

,yoy_baseline AS (
    SELECT
        metric_name
        ,AVG(metric_value) AS x_bar
        ,AVG(mr) AS mr_bar
    FROM yoy_mr
        CROSS JOIN config c
    WHERE date BETWEEN c.yoy_baseline_start AND c.yoy_baseline_end
      AND mr IS NOT NULL
    GROUP BY 1
)

,yoy_latest AS (
    SELECT
        m.metric_name
        ,'YOY_DELTA' AS xmr_type
        ,m.date
        ,m.metric_value AS latest_value
        ,b.x_bar
        ,b.mr_bar
        ,b.x_bar + 2.66 * b.mr_bar AS unpl
        ,b.x_bar - 2.66 * b.mr_bar AS lnpl  -- deltas can be negative
        ,CASE
            WHEN m.metric_value > b.x_bar + 2.66 * b.mr_bar THEN TRUE
            WHEN m.metric_value < b.x_bar - 2.66 * b.mr_bar THEN TRUE
            ELSE FALSE
         END AS beyond_limits
        ,CASE
            WHEN b.mr_bar = 0 THEN NULL
            ELSE ROUND(
                (m.metric_value - b.x_bar) / (2.66 * b.mr_bar) * 100
            , 1)
         END AS pct_to_limit
    FROM yoy_mr m
        INNER JOIN yoy_baseline b ON m.metric_name = b.metric_name
    QUALIFY ROW_NUMBER() OVER (PARTITION BY m.metric_name ORDER BY m.date DESC) = 1
)

-- ---- Combined summary ----
SELECT
    xmr_type
    ,metric_name
    ,date AS latest_date
    ,ROUND(latest_value, 2) AS latest_value
    ,ROUND(x_bar, 2) AS x_bar
    ,ROUND(mr_bar, 2) AS mr_bar
    ,ROUND(unpl, 2) AS unpl
    ,ROUND(lnpl, 2) AS lnpl
    ,beyond_limits
    ,pct_to_limit
FROM std_latest
UNION ALL
SELECT
    xmr_type
    ,metric_name
    ,date AS latest_date
    ,ROUND(latest_value, 2) AS latest_value
    ,ROUND(x_bar, 2) AS x_bar
    ,ROUND(mr_bar, 2) AS mr_bar
    ,ROUND(unpl, 2) AS unpl
    ,ROUND(lnpl, 2) AS lnpl
    ,beyond_limits
    ,pct_to_limit
FROM yoy_latest
ORDER BY xmr_type, metric_name
;


-- ============================================================================
-- Q6: mR Convergence Diagnostic -- Optimal Baseline Window per Metric
-- ============================================================================
-- Determines the minimum number of data points needed for m̄R to stabilize
-- per metric. Stability = cumulative m̄R changes < 5% for 5 consecutive points.
-- Output feeds Q7 (auto-phased XmR) and replaces the hard-coded baseline lengths.

WITH config AS (
    SELECT '2023-01-01'::DATE AS data_start
)

,source_wide AS (
    SELECT
        k.date
        ,k.active_subscribers::FLOAT AS active_subscribers
        ,k.active_monthly_subscribers::FLOAT AS active_monthly_subscribers
        ,k.active_yearly_subscribers::FLOAT AS active_yearly_subscribers
        ,k.new_subscribers::FLOAT AS new_subscribers
        ,ABS(k.churned_subscribers)::FLOAT AS churned_subscribers
        ,k.net_chg_active_subscribers::FLOAT AS net_chg_active_subscribers
        ,k.mrr::FLOAT AS mrr
        ,k.net_chg_mrr::FLOAT AS net_chg_mrr
        ,NVL(k.visitors, 0)::FLOAT AS visitors
        ,NVL(k.sessions, 0)::FLOAT AS sessions
        ,NVL(k.core_visitors, 0)::FLOAT AS core_visitors
        ,NVL(k.spend, 0)::FLOAT AS spend
        ,NVL(k.core_spend, 0)::FLOAT AS core_spend
        ,NVL(k.mixpanel_subscriptions, 0)::FLOAT AS mixpanel_subscriptions
        ,NVL(k.core_mixpanel_subscriptions, 0)::FLOAT AS core_mixpanel_subscriptions
        ,NVL(k.total_transactions, 0)::FLOAT AS total_transactions
    FROM soundstripe_prod.core.dim_daily_kpis k
        CROSS JOIN config c
    WHERE k.date >= c.data_start
)

,unpivoted AS (
    SELECT date, metric_name, metric_value
    FROM source_wide
    UNPIVOT (metric_value FOR metric_name IN (
        active_subscribers, active_monthly_subscribers, active_yearly_subscribers
        ,new_subscribers, churned_subscribers, net_chg_active_subscribers
        ,mrr, net_chg_mrr
        ,visitors, sessions, core_visitors
        ,spend, core_spend
        ,mixpanel_subscriptions, core_mixpanel_subscriptions
        ,total_transactions
    ))
)

,with_moving_range AS (
    SELECT
        u.date
        ,u.metric_name
        ,u.metric_value
        ,ABS(u.metric_value - LAG(u.metric_value, 1) OVER (
            PARTITION BY u.metric_name ORDER BY u.date
        )) AS mr
        ,ROW_NUMBER() OVER (PARTITION BY u.metric_name ORDER BY u.date) AS point_num
    FROM unpivoted u
)

-- Expanding-window cumulative m̄R from the start of the series
,cumulative_mr AS (
    SELECT
        w.date
        ,w.metric_name
        ,w.point_num
        ,w.mr
        ,AVG(w.mr) OVER (
            PARTITION BY w.metric_name ORDER BY w.date
            ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
        ) AS cum_mr_bar
    FROM with_moving_range w
    WHERE w.mr IS NOT NULL
)

-- Point-to-point percent change in cumulative m̄R
,mr_pct_change AS (
    SELECT
        c.*
        ,LAG(c.cum_mr_bar, 1) OVER (PARTITION BY c.metric_name ORDER BY c.date) AS prev_cum_mr_bar
        ,CASE
            WHEN LAG(c.cum_mr_bar, 1) OVER (PARTITION BY c.metric_name ORDER BY c.date) = 0 THEN NULL
            ELSE ABS(c.cum_mr_bar - LAG(c.cum_mr_bar, 1) OVER (PARTITION BY c.metric_name ORDER BY c.date))
                 / LAG(c.cum_mr_bar, 1) OVER (PARTITION BY c.metric_name ORDER BY c.date)
         END AS pct_change
    FROM cumulative_mr c
)

-- Rolling count of consecutive stable points (< 5% change)
,stability_check AS (
    SELECT
        p.*
        ,CASE WHEN p.pct_change < 0.05 THEN 1 ELSE 0 END AS is_stable
        -- Count stable points in trailing 5-point window
        ,SUM(CASE WHEN p.pct_change < 0.05 THEN 1 ELSE 0 END) OVER (
            PARTITION BY p.metric_name ORDER BY p.date
            ROWS BETWEEN 4 PRECEDING AND CURRENT ROW
        ) AS stable_in_last_5
    FROM mr_pct_change p
    WHERE p.point_num >= 10  -- minimum 10 points before checking convergence
)

-- First convergence point per metric
,first_convergence AS (
    SELECT
        s.metric_name
        ,s.point_num AS min_stable_window
        ,s.date AS convergence_date
        ,s.cum_mr_bar AS converged_mr_bar
    FROM stability_check s
    WHERE s.stable_in_last_5 = 5
    QUALIFY ROW_NUMBER() OVER (PARTITION BY s.metric_name ORDER BY s.date) = 1
)

,metric_totals AS (
    SELECT
        s.metric_name
        ,MAX(s.point_num) AS total_points
    FROM stability_check s
    GROUP BY 1
)

SELECT
    t.metric_name
    ,fc.min_stable_window
    ,fc.convergence_date
    ,ROUND(fc.converged_mr_bar, 4) AS converged_mr_bar
    ,t.total_points
FROM metric_totals t
    LEFT JOIN first_convergence fc ON t.metric_name = fc.metric_name
ORDER BY 1
;


-- ============================================================================
-- Q7: Auto-Phased XmR -- Dynamic Baseline Detection
-- ============================================================================
-- Two-pass phase detection using Wheeler's own signal rules:
--   Pass 1: Compute provisional XmR from expanding initial window, detect
--           sustained level shifts via Rule 2 (run of 8 on same side of center)
--   Pass 2: Assign phase boundaries at shift points, recompute limits per phase,
--           re-evaluate signals within each phase
--
-- This eliminates hard-coded baseline dates. Each metric finds its own stable
-- phases from the data. Phase boundaries = confirmed process changes.
--
-- For operationalization as a dbt model, the phase boundaries would be written
-- to an audit table (xmr_phase_history) so the analyst can review and confirm
-- before limits are recalculated.

WITH config AS (
    SELECT
        '2023-01-01'::DATE AS data_start
        ,90 AS provisional_window  -- points for initial limit estimation
        ,60 AS min_phase_points    -- minimum points between phase boundaries
)

,source_wide AS (
    SELECT
        k.date
        ,k.active_subscribers::FLOAT AS active_subscribers
        ,k.active_monthly_subscribers::FLOAT AS active_monthly_subscribers
        ,k.active_yearly_subscribers::FLOAT AS active_yearly_subscribers
        ,k.new_subscribers::FLOAT AS new_subscribers
        ,ABS(k.churned_subscribers)::FLOAT AS churned_subscribers
        ,k.net_chg_active_subscribers::FLOAT AS net_chg_active_subscribers
        ,k.mrr::FLOAT AS mrr
        ,k.net_chg_mrr::FLOAT AS net_chg_mrr
        ,NVL(k.visitors, 0)::FLOAT AS visitors
        ,NVL(k.sessions, 0)::FLOAT AS sessions
        ,NVL(k.core_visitors, 0)::FLOAT AS core_visitors
        ,NVL(k.spend, 0)::FLOAT AS spend
        ,NVL(k.core_spend, 0)::FLOAT AS core_spend
        ,NVL(k.mixpanel_subscriptions, 0)::FLOAT AS mixpanel_subscriptions
        ,NVL(k.core_mixpanel_subscriptions, 0)::FLOAT AS core_mixpanel_subscriptions
        ,NVL(k.total_transactions, 0)::FLOAT AS total_transactions
    FROM soundstripe_prod.core.dim_daily_kpis k
        CROSS JOIN config c
    WHERE k.date >= c.data_start
)

,unpivoted AS (
    SELECT date, metric_name, metric_value
    FROM source_wide
    UNPIVOT (metric_value FOR metric_name IN (
        active_subscribers, active_monthly_subscribers, active_yearly_subscribers
        ,new_subscribers, churned_subscribers, net_chg_active_subscribers
        ,mrr, net_chg_mrr
        ,visitors, sessions, core_visitors
        ,spend, core_spend
        ,mixpanel_subscriptions, core_mixpanel_subscriptions
        ,total_transactions
    ))
)

,with_moving_range AS (
    SELECT
        u.date
        ,u.metric_name
        ,u.metric_value
        ,ABS(u.metric_value - LAG(u.metric_value, 1) OVER (
            PARTITION BY u.metric_name ORDER BY u.date
        )) AS mr
        ,ROW_NUMBER() OVER (PARTITION BY u.metric_name ORDER BY u.date) AS point_num
    FROM unpivoted u
)

-- ---- PASS 1: Provisional limits from first N points, detect level shifts ----

,provisional_baseline AS (
    SELECT
        w.metric_name
        ,AVG(w.metric_value) AS prov_x_bar
        ,AVG(w.mr) AS prov_mr_bar
    FROM with_moving_range w
        CROSS JOIN config c
    WHERE w.point_num <= c.provisional_window
      AND w.mr IS NOT NULL
    GROUP BY 1
)

,pass1_signals AS (
    SELECT
        w.date
        ,w.metric_name
        ,w.metric_value
        ,w.mr
        ,w.point_num
        ,p.prov_x_bar
        ,p.prov_mr_bar
        ,CASE
            WHEN w.metric_value > p.prov_x_bar THEN 1
            WHEN w.metric_value < p.prov_x_bar THEN -1
            ELSE 0
         END AS side_of_center
    FROM with_moving_range w
        INNER JOIN provisional_baseline p ON w.metric_name = p.metric_name
)

,pass1_runs AS (
    SELECT
        s.*
        ,ROW_NUMBER() OVER (PARTITION BY s.metric_name ORDER BY s.date)
         - ROW_NUMBER() OVER (PARTITION BY s.metric_name, s.side_of_center ORDER BY s.date) AS run_group
    FROM pass1_signals s
)

,pass1_run_lengths AS (
    SELECT
        r.*
        ,COUNT(*) OVER (PARTITION BY r.metric_name, r.side_of_center, r.run_group) AS run_length
        -- Find the start date of each run
        ,MIN(r.date) OVER (PARTITION BY r.metric_name, r.side_of_center, r.run_group) AS run_start_date
    FROM pass1_runs r
)

-- Identify phase boundary candidates: the START of each run-of-8+
-- These represent sustained level shifts detected by provisional limits
,phase_boundaries_raw AS (
    SELECT DISTINCT
        metric_name
        ,run_start_date AS phase_start
        ,side_of_center AS shift_direction  -- 1=shifted above, -1=shifted below
    FROM pass1_run_lengths
    WHERE run_length >= 8
      AND side_of_center != 0
)

-- Enforce minimum spacing: drop boundaries too close to the prior one.
-- Uses LAG against prior candidate -- not perfectly greedy but eliminates
-- the single-point phase problem for volatile metrics.
,phase_boundaries AS (
    SELECT
        metric_name
        ,phase_start
        ,shift_direction
    FROM phase_boundaries_raw
    QUALIFY DATEDIFF('day',
        LAG(phase_start, 1, '1900-01-01'::DATE) OVER (
            PARTITION BY metric_name ORDER BY phase_start
        ),
        phase_start
    ) >= (SELECT min_phase_points FROM config)
)

-- ---- PASS 2: Assign phases, recompute limits per phase ----

-- Assign phase numbers: each boundary starts a new phase
-- Use a point-in-time approach: for each data point, find the most recent
-- phase boundary that precedes it
,phase_assignments AS (
    SELECT
        w.date
        ,w.metric_name
        ,w.metric_value
        ,w.mr
        ,w.point_num
        ,COALESCE(
            (SELECT MAX(pb.phase_start)
             FROM phase_boundaries pb
             WHERE pb.metric_name = w.metric_name
               AND pb.phase_start <= w.date)
            ,w.date  -- fallback: first date is Phase 1 start
        ) AS phase_start
    FROM with_moving_range w
)

,phase_numbered AS (
    SELECT
        pa.*
        ,DENSE_RANK() OVER (PARTITION BY pa.metric_name ORDER BY pa.phase_start) AS phase_num
        ,ROW_NUMBER() OVER (PARTITION BY pa.metric_name, pa.phase_start ORDER BY pa.date) AS point_in_phase
    FROM phase_assignments pa
)

-- Recompute limits per phase (using all points in each phase)
,phase_limits AS (
    SELECT
        pn.metric_name
        ,pn.phase_num
        ,pn.phase_start
        ,COUNT(*) AS phase_points
        ,AVG(pn.metric_value) AS x_bar
        ,AVG(pn.mr) AS mr_bar
        ,AVG(pn.metric_value) + 2.66 * AVG(pn.mr) AS unpl
        ,GREATEST(0, AVG(pn.metric_value) - 2.66 * AVG(pn.mr)) AS lnpl
        ,3.267 * AVG(pn.mr) AS url
    FROM phase_numbered pn
    WHERE pn.mr IS NOT NULL
    GROUP BY 1, 2, 3
)

-- ---- Final output: XmR chart with per-phase limits and signal detection ----

,phased_xmr AS (
    SELECT
        pn.date
        ,pn.metric_name
        ,pn.metric_value
        ,pn.mr
        ,pn.phase_num
        ,pl.phase_start
        ,pl.phase_points
        ,pn.point_in_phase
        ,pl.x_bar
        ,pl.mr_bar
        ,pl.unpl
        ,pl.lnpl
        ,pl.url
        -- Rule 1: beyond phase-specific limits
        ,CASE
            WHEN pn.metric_value > pl.unpl THEN TRUE
            WHEN pn.metric_value < pl.lnpl THEN TRUE
            ELSE FALSE
         END AS signal_rule_1
        -- mR signal
        ,CASE WHEN pn.mr > pl.url THEN TRUE ELSE FALSE END AS mr_signal
        -- Side of center (for Rule 2 within phase)
        ,CASE
            WHEN pn.metric_value > pl.x_bar THEN 1
            WHEN pn.metric_value < pl.x_bar THEN -1
            ELSE 0
         END AS side_of_center
        -- Beyond 2-sigma (for Rule 3)
        ,CASE
            WHEN pn.metric_value > pl.x_bar + 1.77 * pl.mr_bar
              OR pn.metric_value < GREATEST(0, pl.x_bar - 1.77 * pl.mr_bar)
            THEN 1 ELSE 0
         END AS beyond_2sigma
    FROM phase_numbered pn
        INNER JOIN phase_limits pl
            ON pn.metric_name = pl.metric_name
            AND pn.phase_num = pl.phase_num
)

,phase_runs AS (
    SELECT
        px.*
        ,ROW_NUMBER() OVER (PARTITION BY px.metric_name, px.phase_num ORDER BY px.date)
         - ROW_NUMBER() OVER (PARTITION BY px.metric_name, px.phase_num, px.side_of_center ORDER BY px.date) AS run_group
    FROM phased_xmr px
)

,phase_run_lengths AS (
    SELECT
        pr.*
        ,COUNT(*) OVER (PARTITION BY pr.metric_name, pr.phase_num, pr.side_of_center, pr.run_group) AS run_length
    FROM phase_runs pr
)

SELECT
    rl.date
    ,rl.metric_name
    ,rl.metric_value
    ,rl.mr
    ,rl.phase_num
    ,rl.phase_start
    ,rl.phase_points
    ,ROUND(rl.x_bar, 2) AS x_bar
    ,ROUND(rl.mr_bar, 2) AS mr_bar
    ,ROUND(rl.unpl, 2) AS unpl
    ,ROUND(rl.lnpl, 2) AS lnpl
    ,ROUND(rl.url, 2) AS url
    ,rl.signal_rule_1
    ,CASE WHEN rl.run_length >= 8 AND rl.side_of_center != 0 THEN TRUE ELSE FALSE END AS signal_rule_2
    ,CASE
        WHEN rl.beyond_2sigma = 1
         AND SUM(rl.beyond_2sigma) OVER (
             PARTITION BY rl.metric_name, rl.phase_num ORDER BY rl.date
             ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
         ) >= 2
        THEN TRUE ELSE FALSE
     END AS signal_rule_3
    ,rl.mr_signal
    ,CASE
        WHEN rl.signal_rule_1
          OR (rl.run_length >= 8 AND rl.side_of_center != 0)
          OR rl.mr_signal
          OR (rl.beyond_2sigma = 1
              AND SUM(rl.beyond_2sigma) OVER (
                  PARTITION BY rl.metric_name, rl.phase_num ORDER BY rl.date
                  ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING
              ) >= 2)
        THEN TRUE ELSE FALSE
     END AS any_signal
FROM phase_run_lengths rl
ORDER BY rl.metric_name, rl.date
;


-- ============================================================================
-- INTEGRATION BRAINSTORM
-- ============================================================================
--
-- 1. dbt Models: XmR Layer
--    a. fct_xmr_daily_kpis -- Q7 auto-phased XmR as the primary output
--       - Materialization: TABLE (full refresh -- ~30K rows, fast)
--       - Phase detection runs on every build; no manual baseline config needed
--       - Output: per-metric, per-phase limits with signal flags
--    b. xmr_phase_audit -- Phase boundaries detected by Q7
--       - Materialization: TABLE
--       - One row per phase transition: metric, phase_start, shift_direction
--       - Analyst reviews this table to confirm/reject phase boundaries
--       - Rejected boundaries get logged in a seed (xmr_phase_overrides.csv)
--    c. xmr_convergence_diagnostic -- Q6 output
--       - Materialization: TABLE
--       - Documents per-metric convergence behavior; informs min_phase_points
--    - The min_phase_points parameter (currently 30) can be replaced by
--      Q6 output: {{ ref('xmr_convergence_diagnostic') }}.min_stable_window
--
-- 2. LookML Dashboard: XmR Process Behavior Charts
--    - View: fct_xmr_daily_kpis.view.lkml wrapping the dbt model
--    - Dimensions: metric_name (filterable), date, dow, xmr_type
--    - Measures: value, mr, x_bar, unpl, lnpl (for reference line overlays)
--    - Derived dimension: in_signal (yesno) for conditional formatting
--    - Dashboard: parameter-based metric picker, X chart + mR chart as
--      separate tiles, limit lines as constant reference lines
--    - Template: follow ad_content_performance.dashboard.lookml structure
--
-- 3. Looker Alerts
--    - Scheduled Look on fct_xmr_daily_kpis filtered to:
--        any_signal = TRUE AND date = CURRENT_DATE
--    - Delivery: email to analytics team if rows > 0
--    - Frequency: daily at 9 AM after dbt run completes
--
-- 4. Snowflake Task + Slack Notification
--    - CREATE TASK xmr_daily_signal_check
--      SCHEDULE = 'USING CRON 0 14 * * * America/Chicago'  -- 9 AM CT
--      AS INSERT INTO analytics.xmr_alerts SELECT ... FROM Q5 WHERE beyond_limits
--    - Pair with a Snowflake notification integration or external function
--      to post to #data-alerts Slack channel
--    - Lower infrastructure overhead than Looker alerts; runs inside Snowflake
--
-- 5. Baseline Management (superseded by Q6/Q7 for most use cases)
--    - Q7 auto-detects phase boundaries; manual baseline management becomes
--      the exception rather than the rule
--    - Override workflow for edge cases:
--      Tier 1 (now): edit min_phase_points in Q7 config, re-run
--      Tier 2 (dbt seed): xmr_phase_overrides.csv -- force/reject specific
--          phase boundaries (metric_name, date, action: force|reject)
--      Tier 3 (UI): Streamlit app or Looker action for phase management
--    - Wheeler's guidance: only shift the baseline after a signal is confirmed
--      as a real process change, not as a reaction to noise. Q7 automates
--      detection; the analyst confirms via the phase audit table
--
-- 6. Extended Signal Detection (future)
--    - Trend detection: 6+ consecutive points steadily increasing/decreasing
--    - Mixture pattern: 8+ consecutive points alternating above/below center
--      (suggests two interleaved processes)
--    - Stratification: 15+ consecutive points within 1-sigma of center
--      (suggests the data is being mixed from multiple sources)
--    - These are Wheeler's additional rules beyond the core 3 implemented here
--
-- 7. Operational Playbook
--    - When a signal fires:
--      (a) Check xmr_phase_audit: did Q7 already detect a phase shift here?
--          If yes, the system self-corrected. Review the new phase limits.
--      (b) If the signal is within a stable phase: check if a known process
--          change explains it (deploy, tracking change, campaign launch).
--          If yes, confirm as new phase in the override seed.
--      (c) If no known change: investigate as a data quality or business anomaly.
--          Open an analysis/data-health/ task folder, follow the investigatory
--          workflow (context -> build -> iterate -> verify/interpret).
--      (d) The March 2026 direct-traffic-spike is the reference case for (c).
--    - The XmR system replaces the current ad-hoc anomaly detection approach
--      with a statistically grounded, self-calibrating process.
--
-- 8. Q6 -> Q7 Feedback Loop (dbt implementation)
--    - Q6 determines optimal min_phase_points per metric
--    - Q7 uses that value instead of a global constant
--    - In dbt: fct_xmr_daily_kpis depends on xmr_convergence_diagnostic
--    - The convergence diagnostic runs first; its output parameterizes the
--      phase detection. Metrics that stabilize fast (e.g., ACTIVE_SUBSCRIBERS
--      with low variance) get shorter initial phases. Volatile metrics
--      (e.g., ENTERPRISE_FORM_SUBMISSIONS) get longer ones.
--    - This makes the system fully self-tuning: no hard-coded window sizes,
--      no manual baseline dates, no per-metric configuration.

select *
from soundstripe_prod.core.dim_daily_kpis
