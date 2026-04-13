-- XmR Process Behavior Chart -- New Subscribers (Weekly, Sliding 20-Week Baseline)
-- Purpose: Wheeler XmR with weekly aggregation and adaptive 20-week trailing baseline
-- Author: d7admin
-- Date: 2026-04-06
-- Source: soundstripe_prod.core.dim_daily_kpis
-- Methodology: Wheeler XmR with rolling baseline -- limits recalculate each week
-- Reference: 2.66 = 3/d2 (d2=1.128 for n=2); 3.267 = D4 for n=2; 1.77 = 2/d2
-- Signal rules:
--   Rule 1: Point beyond UNPL/LNPL (3σ)
--   Rule 2: Run of 8+ on same side of center line
--   Rule 3: 2 of 3 consecutive points beyond 2σ
--   Rule 4: 6+ consecutive points steadily increasing or decreasing (trend)
--   mR:     Moving range exceeds URL

WITH config AS (
    SELECT
        20 AS baseline_weeks                               -- trailing window size (weeks)
        ,'2024-01-01'::DATE AS data_start                  -- first full Monday of 2024
        ,DATEADD('week', -20, data_start) AS baseline_start -- derived: load data from here
        ,DATE_TRUNC('week', CURRENT_DATE()) AS week_cutoff  -- exclude current incomplete week
)

,daily_data AS (
    SELECT
        DATE_TRUNC('week', k.date) AS week_start
        ,k.new_subscribers AS daily_value
    FROM soundstripe_prod.core.dim_daily_kpis k
        CROSS JOIN config c
    WHERE k.date >= c.baseline_start
      AND k.date < c.week_cutoff
)

,source_data AS (
    SELECT
        d.week_start
        ,SUM(d.daily_value) AS value
    FROM daily_data d
    GROUP BY d.week_start
)

,with_moving_range AS (
    SELECT
        s.week_start
        ,s.value
        ,ABS(s.value - LAG(s.value, 1) OVER (ORDER BY s.week_start)) AS mr
    FROM source_data s
)

-- Sliding baseline: x_bar and mr_bar over the trailing 20 weeks for each row
,sliding_baseline AS (
    SELECT
        w.week_start
        ,w.value
        ,w.mr
        ,AVG(w.value) OVER (
            ORDER BY w.week_start
            ROWS BETWEEN 20 PRECEDING AND 1 PRECEDING
        ) AS x_bar
        ,AVG(w.mr) OVER (
            ORDER BY w.week_start
            ROWS BETWEEN 20 PRECEDING AND 1 PRECEDING
        ) AS mr_bar
    FROM with_moving_range w
)

,xmr_chart AS (
    SELECT
        sb.week_start
        ,sb.value
        ,sb.mr
        ,sb.x_bar
        ,sb.mr_bar
        ,sb.x_bar + 2.66 * sb.mr_bar AS unpl
        ,GREATEST(0, sb.x_bar - 2.66 * sb.mr_bar) AS lnpl
        ,3.267 * sb.mr_bar AS url
        ,sb.x_bar + 1.77 * sb.mr_bar AS two_sigma_upper
        ,GREATEST(0, sb.x_bar - 1.77 * sb.mr_bar) AS two_sigma_lower
        -- Rule 1: point beyond natural process limits
        ,CASE
            WHEN sb.value > sb.x_bar + 2.66 * sb.mr_bar THEN TRUE
            WHEN sb.value < GREATEST(0, sb.x_bar - 2.66 * sb.mr_bar) THEN TRUE
            ELSE FALSE
         END AS signal_rule_1
        -- mR signal: moving range exceeds upper range limit
        ,CASE WHEN sb.mr > 3.267 * sb.mr_bar THEN TRUE ELSE FALSE END AS mr_signal
        -- Prep for Rule 2 (run of 8)
        ,CASE
            WHEN sb.value > sb.x_bar THEN 1
            WHEN sb.value < sb.x_bar THEN -1
            ELSE 0
         END AS side_of_center
        -- Prep for Rule 3 (2 of 3 beyond 2-sigma)
        ,CASE
            WHEN sb.value > sb.x_bar + 1.77 * sb.mr_bar
              OR sb.value < GREATEST(0, sb.x_bar - 1.77 * sb.mr_bar)
            THEN 1 ELSE 0
         END AS beyond_2sigma
        -- Prep for Rule 4 (trend of 6 consecutive increases or decreases)
        ,CASE
            WHEN sb.value > LAG(sb.value, 1) OVER (ORDER BY sb.week_start) THEN 1
            WHEN sb.value < LAG(sb.value, 1) OVER (ORDER BY sb.week_start) THEN -1
            ELSE 0
         END AS direction
    FROM sliding_baseline sb
)

,with_runs AS (
    SELECT
        x.*
        ,ROW_NUMBER() OVER (ORDER BY x.week_start)
         - ROW_NUMBER() OVER (PARTITION BY x.side_of_center ORDER BY x.week_start) AS run_group
        ,ROW_NUMBER() OVER (ORDER BY x.week_start)
         - ROW_NUMBER() OVER (PARTITION BY x.direction ORDER BY x.week_start) AS trend_group
    FROM xmr_chart x
)

,with_run_lengths AS (
    SELECT
        r.*
        ,COUNT(*) OVER (PARTITION BY r.side_of_center, r.run_group) AS run_length
        ,COUNT(*) OVER (PARTITION BY r.direction, r.trend_group) AS trend_length
    FROM with_runs r
)

SELECT
    rl.week_start
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
         AND SUM(rl.beyond_2sigma) OVER (ORDER BY rl.week_start ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) >= 2
        THEN TRUE ELSE FALSE
     END AS signal_rule_3
    ,CASE WHEN rl.trend_length >= 6 AND rl.direction != 0 THEN TRUE ELSE FALSE END AS signal_rule_4
    ,rl.mr_signal
    ,CASE
        WHEN rl.signal_rule_1
          OR (rl.run_length >= 8 AND rl.side_of_center != 0)
          OR (rl.beyond_2sigma = 1
              AND SUM(rl.beyond_2sigma) OVER (ORDER BY rl.week_start ROWS BETWEEN 1 PRECEDING AND 1 FOLLOWING) >= 2)
          OR (rl.trend_length >= 6 AND rl.direction != 0)
          OR rl.mr_signal
        THEN TRUE ELSE FALSE
     END AS any_signal
FROM with_run_lengths rl
    CROSS JOIN config c
WHERE rl.week_start >= c.data_start
ORDER BY rl.week_start
;
