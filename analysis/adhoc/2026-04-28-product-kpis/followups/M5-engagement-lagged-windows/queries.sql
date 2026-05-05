-- M5 — Engagement metrics on lagged-cohort basis (right-censoring removed)
-- Author: Devon  Date: 2026-04-28

------------------------------------------------------------------------
-- m5_q01 — engagement components per cohort, restricted to cohorts with
-- sub_start_month + 60 days <= today (2026-04-29)
------------------------------------------------------------------------
WITH activity AS (
    SELECT
        DATE_TRUNC('month', start_date)::DATE AS sub_start_month,
        soundstripe_subscription_id,
        session_id,
        start_date,
        end_date,
        session_started_at,
        downloaded_songs,
        DATEDIFF('day', start_date, session_started_at::DATE) AS days_into_sub,
        DATEDIFF('day', start_date, end_date) AS sub_lifetime_days
    FROM soundstripe_prod.core.fct_subscriber_activity_mixpanel
    WHERE start_date >= '2024-05-01'
      AND start_date <  '2026-03-01'
),
subscriber_level AS (
    SELECT
        sub_start_month, soundstripe_subscription_id,
        MAX(sub_lifetime_days) AS sub_lifetime_days,
        MAX(CASE WHEN days_into_sub <  7 AND NVL(downloaded_songs,0) > 0 THEN 1 ELSE 0 END) AS dl_in_first_7d_flag,
        SUM(CASE WHEN days_into_sub < 30 AND NVL(downloaded_songs,0) > 0 THEN downloaded_songs ELSE 0 END) AS songs_dl_first_30d,
        MAX(CASE WHEN days_into_sub BETWEEN 30 AND 59 THEN 1 ELSE 0 END) AS engaged_30_60d_flag,
        COUNT(DISTINCT CASE WHEN days_into_sub BETWEEN 30 AND 59 THEN session_id END) AS sessions_30_60d
    FROM activity GROUP BY 1, 2
)
SELECT
    sub_start_month,
    CASE WHEN DATEADD('day', 60, sub_start_month) <= CURRENT_DATE THEN 1 ELSE 0 END AS cohort_fully_observable_at_60d,
    COUNT(DISTINCT soundstripe_subscription_id) AS subs_in_cohort,
    COUNT(DISTINCT CASE WHEN sub_lifetime_days >= 60 THEN soundstripe_subscription_id END) AS subs_60_plus,
    COUNT(DISTINCT CASE WHEN dl_in_first_7d_flag = 1 THEN soundstripe_subscription_id END) AS subs_dl_first_7d,
    SUM(songs_dl_first_30d) AS songs_dl_first_30d_total,
    COUNT(DISTINCT CASE WHEN engaged_30_60d_flag = 1 AND sub_lifetime_days >= 60 THEN soundstripe_subscription_id END) AS engaged_subs_30_60_qualifying,
    SUM(CASE WHEN engaged_30_60d_flag = 1 THEN sessions_30_60d END) AS sessions_in_30_60_window_engaged,
    COUNT(DISTINCT CASE WHEN engaged_30_60d_flag = 1 THEN soundstripe_subscription_id END) AS engaged_subs_30_60_total
FROM subscriber_level
GROUP BY 1, 2 ORDER BY 1;

-- TYPE AUDIT — m5_q01:
--   Declared denominator (tiles 7, 8): subs_in_cohort
--   Declared denominator (tile 9): subs_60_plus (only subs that lasted ≥60 days)
--   Declared denominator (tile 10): engaged_subs_30_60_total (only engaged subs in that window)
--   JOIN chain: NONE — single-table aggregation, subscriber-level rollup CTE.
--   Right-censoring filter: WHERE start_date < '2026-03-01' caps cohort_start; the CASE on
--   DATEADD(60d, ...) ≤ CURRENT_DATE confirms all included cohorts are fully observable for
--   the 30-60d window (the longest cohort window of the four tiles). At analysis date 2026-04-29,
--   the latest fully-observable cohort is 2026-02 (Feb 28 + 60 = Apr 29 = today).
--   RESULT: PASS.
