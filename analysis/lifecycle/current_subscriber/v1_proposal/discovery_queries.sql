-- =============================================================================
-- LIFECYCLE EMAIL FLOW — STEP 0: DATA DISCOVERY QUERIES
-- Snowflake dialect | soundstripe_prod.core schema
-- Purpose: Understand behavioral distributions to inform lifecycle segment definitions
-- =============================================================================
--
-- DEFINITIONS (consistent with subscriber engagement analysis):
--   "Active subscriber" = subscription period overlaps the calendar month
--   "Visitor" = active subscriber with at least one session that month
--   "Session rate" = visitors / active subscribers
--   "Download rate" = downloaders / visitors
--   "Search rate"   = searchers / visitors
--
-- Run each query separately in Snowflake and export results as CSV.
-- =============================================================================


-- ---------------------------------------------------------------------------
-- QUERY A1: Session recency distribution (point-in-time snapshot)
-- For every active subscriber as of the most recent complete month,
-- how many days since their last session?
-- Bucketed to find natural breakpoints for lapsing/lapsed thresholds.
-- ---------------------------------------------------------------------------
WITH current_active_subs AS (
    SELECT
        sp.soundstripe_subscription_id AS subscription_id,
        sp.start_date,
        sp.plan_type,
        sp.billing_period_unit
    FROM soundstripe_prod.core.subscription_periods sp
    WHERE sp.start_date <= LAST_DAY(DATE_TRUNC('month', DATEADD('month', -1, CURRENT_DATE())))
      AND (sp.cancelled_at IS NULL
           OR sp.cancelled_at >= DATE_TRUNC('month', DATEADD('month', -1, CURRENT_DATE())))
),

last_session AS (
    SELECT
        s.current_subscription_id AS subscription_id,
        MAX(s.session_started_at) AS last_session_date
    FROM soundstripe_prod.core.fct_sessions s
    WHERE s.current_subscription_id IS NOT NULL
    GROUP BY 1
)

SELECT
    CASE
        WHEN ls.last_session_date IS NULL THEN 'never'
        WHEN DATEDIFF('day', ls.last_session_date, CURRENT_DATE()) <= 7   THEN '0-7d'
        WHEN DATEDIFF('day', ls.last_session_date, CURRENT_DATE()) <= 14  THEN '8-14d'
        WHEN DATEDIFF('day', ls.last_session_date, CURRENT_DATE()) <= 30  THEN '15-30d'
        WHEN DATEDIFF('day', ls.last_session_date, CURRENT_DATE()) <= 60  THEN '31-60d'
        WHEN DATEDIFF('day', ls.last_session_date, CURRENT_DATE()) <= 90  THEN '61-90d'
        WHEN DATEDIFF('day', ls.last_session_date, CURRENT_DATE()) <= 180 THEN '91-180d'
        ELSE '180d+'
    END AS recency_bucket,
    COUNT(DISTINCT cas.subscription_id) AS subscriber_count,
    ROUND(100.0 * COUNT(DISTINCT cas.subscription_id)
        / SUM(COUNT(DISTINCT cas.subscription_id)) OVER (), 1) AS pct_of_total
FROM current_active_subs cas
LEFT JOIN last_session ls
    ON cas.subscription_id = ls.subscription_id
GROUP BY 1
ORDER BY
    CASE recency_bucket
        WHEN 'never'   THEN 0
        WHEN '0-7d'    THEN 1
        WHEN '8-14d'   THEN 2
        WHEN '15-30d'  THEN 3
        WHEN '31-60d'  THEN 4
        WHEN '61-90d'  THEN 5
        WHEN '91-180d' THEN 6
        WHEN '180d+'   THEN 7
    END;


-- ---------------------------------------------------------------------------
-- QUERY A2: Session frequency distribution (trailing 30 days)
-- Among subscribers with at least one session in the last 30 days,
-- how many sessions did they have? Bucketed.
-- ---------------------------------------------------------------------------
WITH current_active_subs AS (
    SELECT
        sp.soundstripe_subscription_id AS subscription_id
    FROM soundstripe_prod.core.subscription_periods sp
    WHERE sp.start_date <= CURRENT_DATE()
      AND (sp.cancelled_at IS NULL OR sp.cancelled_at >= DATEADD('day', -30, CURRENT_DATE()))
),

trailing_sessions AS (
    SELECT
        s.current_subscription_id AS subscription_id,
        COUNT(DISTINCT s.session_id) AS session_count
    FROM soundstripe_prod.core.fct_sessions s
    WHERE s.session_started_at >= DATEADD('day', -30, CURRENT_DATE())
      AND s.current_subscription_id IS NOT NULL
    GROUP BY 1
)

SELECT
    CASE
        WHEN ts.session_count = 1      THEN '1 session'
        WHEN ts.session_count = 2      THEN '2 sessions'
        WHEN ts.session_count BETWEEN 3 AND 5   THEN '3-5 sessions'
        WHEN ts.session_count BETWEEN 6 AND 10  THEN '6-10 sessions'
        WHEN ts.session_count BETWEEN 11 AND 20 THEN '11-20 sessions'
        ELSE '21+ sessions'
    END AS frequency_bucket,
    COUNT(DISTINCT ts.subscription_id) AS subscriber_count,
    ROUND(100.0 * COUNT(DISTINCT ts.subscription_id)
        / SUM(COUNT(DISTINCT ts.subscription_id)) OVER (), 1) AS pct_of_visitors
FROM current_active_subs cas
INNER JOIN trailing_sessions ts
    ON cas.subscription_id = ts.subscription_id
GROUP BY 1
ORDER BY
    CASE frequency_bucket
        WHEN '1 session'     THEN 1
        WHEN '2 sessions'    THEN 2
        WHEN '3-5 sessions'  THEN 3
        WHEN '6-10 sessions' THEN 4
        WHEN '11-20 sessions' THEN 5
        WHEN '21+ sessions'  THEN 6
    END;


-- ---------------------------------------------------------------------------
-- QUERY A3: Behavioral segmentation among visitors (trailing 30 days)
-- Among subscribers who logged in during the last 30 days:
--   - What % downloaded at least 1 song?
--   - What % searched but did NOT download?
--   - What % browsed only (no search, no download)?
-- ---------------------------------------------------------------------------
WITH current_active_subs AS (
    SELECT
        sp.soundstripe_subscription_id AS subscription_id
    FROM soundstripe_prod.core.subscription_periods sp
    WHERE sp.start_date <= CURRENT_DATE()
      AND (sp.cancelled_at IS NULL OR sp.cancelled_at >= DATEADD('day', -30, CURRENT_DATE()))
),

visitor_activity AS (
    SELECT
        s.current_subscription_id AS subscription_id,
        SUM(COALESCE(s.downloaded_songs_count, 0))   AS total_downloads,
        SUM(COALESCE(s.searched_songs_count, 0))      AS total_searches,
        SUM(COALESCE(s.downloaded_sound_effects_count, 0)) AS total_sfx_downloads,
        SUM(COALESCE(s.searched_sound_effects_count, 0))   AS total_sfx_searches
    FROM soundstripe_prod.core.fct_sessions s
    WHERE s.session_started_at >= DATEADD('day', -30, CURRENT_DATE())
      AND s.current_subscription_id IS NOT NULL
    GROUP BY 1
)

SELECT
    CASE
        WHEN va.total_downloads > 0 OR va.total_sfx_downloads > 0
            THEN 'downloader'
        WHEN va.total_searches > 0 OR va.total_sfx_searches > 0
            THEN 'searcher_no_download'
        ELSE 'browse_only'
    END AS visitor_behavior,
    COUNT(DISTINCT va.subscription_id) AS subscriber_count,
    ROUND(100.0 * COUNT(DISTINCT va.subscription_id)
        / SUM(COUNT(DISTINCT va.subscription_id)) OVER (), 1) AS pct_of_visitors
FROM current_active_subs cas
INNER JOIN visitor_activity va
    ON cas.subscription_id = va.subscription_id
GROUP BY 1
ORDER BY subscriber_count DESC;


-- ---------------------------------------------------------------------------
-- QUERY B4: Activity rates by subscriber age bucket
-- Session rate and download rate by months since subscription start.
-- Uses the most recent 6 complete months to get stable averages.
-- ---------------------------------------------------------------------------
WITH recent_months AS (
    SELECT DISTINCT DATE_TRUNC('month', session_started_at) AS month_start
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at >= DATEADD('month', -7, DATE_TRUNC('month', CURRENT_DATE()))
      AND session_started_at < DATE_TRUNC('month', CURRENT_DATE())
),

active_subs AS (
    SELECT
        m.month_start,
        sp.soundstripe_subscription_id AS subscription_id,
        sp.start_date,
        DATEDIFF('month', sp.start_date, m.month_start) AS months_since_start,
        CASE
            WHEN DATEDIFF('month', sp.start_date, m.month_start) = 0  THEN '0 (signup month)'
            WHEN DATEDIFF('month', sp.start_date, m.month_start) = 1  THEN '1'
            WHEN DATEDIFF('month', sp.start_date, m.month_start) BETWEEN 2 AND 3 THEN '2-3'
            WHEN DATEDIFF('month', sp.start_date, m.month_start) BETWEEN 4 AND 6 THEN '4-6'
            WHEN DATEDIFF('month', sp.start_date, m.month_start) BETWEEN 7 AND 12 THEN '7-12'
            WHEN DATEDIFF('month', sp.start_date, m.month_start) BETWEEN 13 AND 24 THEN '13-24'
            ELSE '25+'
        END AS tenure_bucket
    FROM recent_months m
    INNER JOIN soundstripe_prod.core.subscription_periods sp
        ON sp.start_date <= LAST_DAY(m.month_start)
       AND (sp.cancelled_at IS NULL OR sp.cancelled_at >= m.month_start)
),

sub_monthly_activity AS (
    SELECT
        DATE_TRUNC('month', s.session_started_at)      AS month_start,
        s.current_subscription_id                       AS subscription_id,
        COUNT(DISTINCT s.session_id)                    AS sessions,
        SUM(COALESCE(s.downloaded_songs_count, 0))      AS song_downloads,
        SUM(COALESCE(s.searched_songs_count, 0))        AS song_searches
    FROM soundstripe_prod.core.fct_sessions s
    WHERE s.session_started_at >= DATEADD('month', -7, DATE_TRUNC('month', CURRENT_DATE()))
      AND s.session_started_at < DATE_TRUNC('month', CURRENT_DATE())
      AND s.current_subscription_id IS NOT NULL
    GROUP BY 1, 2
)

SELECT
    a.tenure_bucket,

    -- Counts (averaged across the 6 months)
    ROUND(COUNT(DISTINCT a.subscription_id) / 6.0, 0)              AS avg_monthly_active_subs,
    ROUND(COUNT(DISTINCT sma.subscription_id) / 6.0, 0)            AS avg_monthly_visitors,

    -- Session rate
    ROUND(100.0 *
        COUNT(DISTINCT sma.subscription_id)
        / NULLIF(COUNT(DISTINCT a.subscription_id), 0)
    , 1)                                                            AS pct_session_rate,

    -- Download rate (visitor denom)
    ROUND(100.0 *
        COUNT(DISTINCT CASE WHEN sma.song_downloads >= 1 THEN sma.subscription_id END)
        / NULLIF(COUNT(DISTINCT sma.subscription_id), 0)
    , 1)                                                            AS pct_visitors_downloading,

    -- Search rate (visitor denom)
    ROUND(100.0 *
        COUNT(DISTINCT CASE WHEN sma.song_searches >= 1 THEN sma.subscription_id END)
        / NULLIF(COUNT(DISTINCT sma.subscription_id), 0)
    , 1)                                                            AS pct_visitors_searching

FROM active_subs a
LEFT JOIN sub_monthly_activity sma
    ON a.subscription_id = sma.subscription_id
   AND a.month_start     = sma.month_start
GROUP BY a.tenure_bucket
ORDER BY
    CASE tenure_bucket
        WHEN '0 (signup month)' THEN 0
        WHEN '1'     THEN 1
        WHEN '2-3'   THEN 2
        WHEN '4-6'   THEN 3
        WHEN '7-12'  THEN 4
        WHEN '13-24' THEN 5
        WHEN '25+'   THEN 6
    END;


-- ---------------------------------------------------------------------------
-- QUERY B5: First-action timing
-- For subscribers who started in the last 12 months and eventually had a
-- session/download, how many days from subscription start to:
--   a) first session
--   b) first download
-- Distribution in day buckets.
-- ---------------------------------------------------------------------------
WITH recent_subs AS (
    SELECT
        sp.soundstripe_subscription_id AS subscription_id,
        sp.start_date
    FROM soundstripe_prod.core.subscription_periods sp
    WHERE sp.start_date >= DATEADD('month', -12, DATE_TRUNC('month', CURRENT_DATE()))
),

first_actions AS (
    SELECT
        s.current_subscription_id AS subscription_id,
        MIN(s.session_started_at) AS first_session_date,
        MIN(CASE WHEN s.downloaded_songs_count > 0 THEN s.session_started_at END) AS first_download_date
    FROM soundstripe_prod.core.fct_sessions s
    WHERE s.current_subscription_id IS NOT NULL
    GROUP BY 1
)

SELECT
    'first_session' AS action_type,
    CASE
        WHEN DATEDIFF('day', rs.start_date, fa.first_session_date) = 0 THEN 'day 0'
        WHEN DATEDIFF('day', rs.start_date, fa.first_session_date) = 1 THEN 'day 1'
        WHEN DATEDIFF('day', rs.start_date, fa.first_session_date) BETWEEN 2 AND 3 THEN 'day 2-3'
        WHEN DATEDIFF('day', rs.start_date, fa.first_session_date) BETWEEN 4 AND 7 THEN 'day 4-7'
        WHEN DATEDIFF('day', rs.start_date, fa.first_session_date) BETWEEN 8 AND 14 THEN 'day 8-14'
        WHEN DATEDIFF('day', rs.start_date, fa.first_session_date) BETWEEN 15 AND 30 THEN 'day 15-30'
        WHEN DATEDIFF('day', rs.start_date, fa.first_session_date) BETWEEN 31 AND 60 THEN 'day 31-60'
        ELSE 'day 61+'
    END AS timing_bucket,
    COUNT(*) AS subscriber_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_group
FROM recent_subs rs
INNER JOIN first_actions fa
    ON rs.subscription_id = fa.subscription_id
WHERE fa.first_session_date IS NOT NULL
  AND fa.first_session_date >= rs.start_date
GROUP BY 1, 2

UNION ALL

SELECT
    'first_download' AS action_type,
    CASE
        WHEN DATEDIFF('day', rs.start_date, fa.first_download_date) = 0 THEN 'day 0'
        WHEN DATEDIFF('day', rs.start_date, fa.first_download_date) = 1 THEN 'day 1'
        WHEN DATEDIFF('day', rs.start_date, fa.first_download_date) BETWEEN 2 AND 3 THEN 'day 2-3'
        WHEN DATEDIFF('day', rs.start_date, fa.first_download_date) BETWEEN 4 AND 7 THEN 'day 4-7'
        WHEN DATEDIFF('day', rs.start_date, fa.first_download_date) BETWEEN 8 AND 14 THEN 'day 8-14'
        WHEN DATEDIFF('day', rs.start_date, fa.first_download_date) BETWEEN 15 AND 30 THEN 'day 15-30'
        WHEN DATEDIFF('day', rs.start_date, fa.first_download_date) BETWEEN 31 AND 60 THEN 'day 31-60'
        ELSE 'day 61+'
    END AS timing_bucket,
    COUNT(*) AS subscriber_count,
    ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1) AS pct_of_group
FROM recent_subs rs
INNER JOIN first_actions fa
    ON rs.subscription_id = fa.subscription_id
WHERE fa.first_download_date IS NOT NULL
  AND fa.first_download_date >= rs.start_date
GROUP BY 1, 2

ORDER BY action_type,
    CASE timing_bucket
        WHEN 'day 0'    THEN 0
        WHEN 'day 1'    THEN 1
        WHEN 'day 2-3'  THEN 2
        WHEN 'day 4-7'  THEN 3
        WHEN 'day 8-14' THEN 4
        WHEN 'day 15-30' THEN 5
        WHEN 'day 31-60' THEN 6
        WHEN 'day 61+'  THEN 7
    END;


-- ---------------------------------------------------------------------------
-- QUERY B6: Lapse-and-return patterns
-- Among subscribers who had a 30+ day gap between sessions:
--   - What % returned (had another session after the gap)?
--   - What was the median gap length for returners vs. non-returners?
-- Scoped to gaps that started in the last 12 months (so there's time to observe return).
-- ---------------------------------------------------------------------------
WITH sub_sessions AS (
    SELECT
        s.current_subscription_id AS subscription_id,
        s.session_started_at,
        LAG(s.session_started_at) OVER (
            PARTITION BY s.current_subscription_id
            ORDER BY s.session_started_at
        ) AS prev_session_date
    FROM soundstripe_prod.core.fct_sessions s
    WHERE s.current_subscription_id IS NOT NULL
      AND s.session_started_at >= '2024-01-01'
),

gaps AS (
    SELECT
        subscription_id,
        prev_session_date AS gap_start,
        session_started_at AS gap_end,
        DATEDIFF('day', prev_session_date, session_started_at) AS gap_days
    FROM sub_sessions
    WHERE prev_session_date IS NOT NULL
      AND DATEDIFF('day', prev_session_date, session_started_at) >= 30
),

-- For each subscription, find the FIRST 30+ day gap
first_gap AS (
    SELECT
        subscription_id,
        gap_start,
        gap_end,
        gap_days,
        ROW_NUMBER() OVER (PARTITION BY subscription_id ORDER BY gap_start) AS rn
    FROM gaps
    WHERE gap_start >= '2025-01-01'
      AND gap_start <= DATEADD('month', -2, CURRENT_DATE())  -- at least 2 months to observe return
)

SELECT
    CASE
        WHEN fg.gap_days BETWEEN 30 AND 60   THEN '30-60d gap'
        WHEN fg.gap_days BETWEEN 61 AND 90   THEN '61-90d gap'
        WHEN fg.gap_days BETWEEN 91 AND 180  THEN '91-180d gap'
        ELSE '180d+ gap'
    END AS gap_bucket,
    COUNT(DISTINCT fg.subscription_id) AS subscribers_with_gap,
    -- "Returned" means there was a session after the gap ended
    COUNT(DISTINCT fg.subscription_id) AS returned_count,  -- all rows in first_gap ARE returns (the gap_end IS the return session)
    ROUND(MEDIAN(fg.gap_days), 0) AS median_gap_days,
    ROUND(AVG(fg.gap_days), 0) AS avg_gap_days
FROM first_gap fg
WHERE fg.rn = 1
GROUP BY 1
ORDER BY
    CASE gap_bucket
        WHEN '30-60d gap'  THEN 1
        WHEN '61-90d gap'  THEN 2
        WHEN '91-180d gap' THEN 3
        WHEN '180d+ gap'   THEN 4
    END;


-- ---------------------------------------------------------------------------
-- QUERY B6b: Non-returners — subscribers whose last session was 30+ days ago
-- and who are STILL active (haven't cancelled).
-- Complements B6 by sizing the "currently lapsed but still paying" population.
-- ---------------------------------------------------------------------------
WITH current_active_subs AS (
    SELECT
        sp.soundstripe_subscription_id AS subscription_id,
        sp.start_date
    FROM soundstripe_prod.core.subscription_periods sp
    WHERE sp.start_date <= CURRENT_DATE()
      AND (sp.cancelled_at IS NULL OR sp.cancelled_at >= CURRENT_DATE())
),

last_session AS (
    SELECT
        s.current_subscription_id AS subscription_id,
        MAX(s.session_started_at) AS last_session_date
    FROM soundstripe_prod.core.fct_sessions s
    WHERE s.current_subscription_id IS NOT NULL
    GROUP BY 1
)

SELECT
    CASE
        WHEN ls.last_session_date IS NULL THEN 'never_visited'
        WHEN DATEDIFF('day', ls.last_session_date, CURRENT_DATE()) BETWEEN 30 AND 60 THEN '30-60d lapsed'
        WHEN DATEDIFF('day', ls.last_session_date, CURRENT_DATE()) BETWEEN 61 AND 90 THEN '61-90d lapsed'
        WHEN DATEDIFF('day', ls.last_session_date, CURRENT_DATE()) BETWEEN 91 AND 180 THEN '91-180d lapsed'
        WHEN DATEDIFF('day', ls.last_session_date, CURRENT_DATE()) > 180 THEN '180d+ lapsed'
        ELSE 'active_last_30d'
    END AS lapse_status,
    COUNT(DISTINCT cas.subscription_id) AS subscriber_count,
    ROUND(100.0 * COUNT(DISTINCT cas.subscription_id)
        / SUM(COUNT(DISTINCT cas.subscription_id)) OVER (), 1) AS pct_of_active_subs
FROM current_active_subs cas
LEFT JOIN last_session ls
    ON cas.subscription_id = ls.subscription_id
GROUP BY 1
ORDER BY
    CASE lapse_status
        WHEN 'active_last_30d' THEN 0
        WHEN '30-60d lapsed'   THEN 1
        WHEN '61-90d lapsed'   THEN 2
        WHEN '91-180d lapsed'  THEN 3
        WHEN '180d+ lapsed'    THEN 4
        WHEN 'never_visited'   THEN 5
    END;


-- ---------------------------------------------------------------------------
-- QUERY C7: Monthly funnel metrics — trailing 12 months
-- Replicates engagement analysis Q5 but scoped to recent period.
-- ---------------------------------------------------------------------------
WITH recent_months AS (
    SELECT DISTINCT DATE_TRUNC('month', session_started_at) AS month_start
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at >= DATEADD('month', -12, DATE_TRUNC('month', CURRENT_DATE()))
      AND session_started_at < DATE_TRUNC('month', CURRENT_DATE())
),

active_subs AS (
    SELECT
        m.month_start,
        sp.soundstripe_subscription_id AS subscription_id
    FROM recent_months m
    INNER JOIN soundstripe_prod.core.subscription_periods sp
        ON sp.start_date <= LAST_DAY(m.month_start)
       AND (sp.cancelled_at IS NULL OR sp.cancelled_at >= m.month_start)
),

sub_monthly_activity AS (
    SELECT
        DATE_TRUNC('month', s.session_started_at)      AS month_start,
        s.current_subscription_id                       AS subscription_id,
        COUNT(DISTINCT s.session_id)                    AS sessions,
        SUM(COALESCE(s.downloaded_songs_count, 0))      AS song_downloads,
        SUM(COALESCE(s.searched_songs_count, 0))        AS song_searches
    FROM soundstripe_prod.core.fct_sessions s
    WHERE s.session_started_at >= DATEADD('month', -12, DATE_TRUNC('month', CURRENT_DATE()))
      AND s.session_started_at < DATE_TRUNC('month', CURRENT_DATE())
      AND s.current_subscription_id IS NOT NULL
    GROUP BY 1, 2
)

SELECT
    a.month_start,
    COUNT(DISTINCT a.subscription_id)                                        AS total_active_subs,
    COUNT(DISTINCT sma.subscription_id)                                      AS visitors,
    ROUND(100.0 * COUNT(DISTINCT sma.subscription_id)
        / NULLIF(COUNT(DISTINCT a.subscription_id), 0), 1)                   AS pct_session_rate,
    COUNT(DISTINCT CASE WHEN sma.song_downloads >= 1 THEN sma.subscription_id END) AS downloaders,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN sma.song_downloads >= 1 THEN sma.subscription_id END)
        / NULLIF(COUNT(DISTINCT sma.subscription_id), 0), 1)                AS pct_visitors_downloading,
    COUNT(DISTINCT CASE WHEN sma.song_searches >= 1 THEN sma.subscription_id END) AS searchers,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN sma.song_searches >= 1 THEN sma.subscription_id END)
        / NULLIF(COUNT(DISTINCT sma.subscription_id), 0), 1)                AS pct_visitors_searching
FROM active_subs a
LEFT JOIN sub_monthly_activity sma
    ON a.subscription_id = sma.subscription_id
   AND a.month_start     = sma.month_start
GROUP BY a.month_start
ORDER BY a.month_start;


-- ---------------------------------------------------------------------------
-- QUERY C8: Cohort-level funnel compression — trailing 12 months by signup year
-- Same as C7 but broken by tenure cohort.
-- ---------------------------------------------------------------------------
WITH recent_months AS (
    SELECT DISTINCT DATE_TRUNC('month', session_started_at) AS month_start
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at >= DATEADD('month', -12, DATE_TRUNC('month', CURRENT_DATE()))
      AND session_started_at < DATE_TRUNC('month', CURRENT_DATE())
),

active_subs AS (
    SELECT
        m.month_start,
        sp.soundstripe_subscription_id AS subscription_id,
        CASE
            WHEN sp.start_date < '2022-01-01' THEN 'Pre-2022'
            WHEN sp.start_date < '2023-01-01' THEN '2022'
            WHEN sp.start_date < '2024-01-01' THEN '2023'
            WHEN sp.start_date < '2025-01-01' THEN '2024'
            ELSE '2025+'
        END AS tenure_cohort
    FROM recent_months m
    INNER JOIN soundstripe_prod.core.subscription_periods sp
        ON sp.start_date <= LAST_DAY(m.month_start)
       AND (sp.cancelled_at IS NULL OR sp.cancelled_at >= m.month_start)
),

sub_monthly_activity AS (
    SELECT
        DATE_TRUNC('month', s.session_started_at)      AS month_start,
        s.current_subscription_id                       AS subscription_id,
        COUNT(DISTINCT s.session_id)                    AS sessions,
        SUM(COALESCE(s.downloaded_songs_count, 0))      AS song_downloads,
        SUM(COALESCE(s.searched_songs_count, 0))        AS song_searches
    FROM soundstripe_prod.core.fct_sessions s
    WHERE s.session_started_at >= DATEADD('month', -12, DATE_TRUNC('month', CURRENT_DATE()))
      AND s.session_started_at < DATE_TRUNC('month', CURRENT_DATE())
      AND s.current_subscription_id IS NOT NULL
    GROUP BY 1, 2
)

SELECT
    a.month_start,
    a.tenure_cohort,
    COUNT(DISTINCT a.subscription_id)                                        AS total_active_subs,
    COUNT(DISTINCT sma.subscription_id)                                      AS visitors,
    ROUND(100.0 * COUNT(DISTINCT sma.subscription_id)
        / NULLIF(COUNT(DISTINCT a.subscription_id), 0), 1)                   AS pct_session_rate,
    COUNT(DISTINCT CASE WHEN sma.song_downloads >= 1 THEN sma.subscription_id END) AS downloaders,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN sma.song_downloads >= 1 THEN sma.subscription_id END)
        / NULLIF(COUNT(DISTINCT sma.subscription_id), 0), 1)                AS pct_visitors_downloading,
    COUNT(DISTINCT CASE WHEN sma.song_searches >= 1 THEN sma.subscription_id END) AS searchers,
    ROUND(100.0 * COUNT(DISTINCT CASE WHEN sma.song_searches >= 1 THEN sma.subscription_id END)
        / NULLIF(COUNT(DISTINCT sma.subscription_id), 0), 1)                AS pct_visitors_searching
FROM active_subs a
LEFT JOIN sub_monthly_activity sma
    ON a.subscription_id = sma.subscription_id
   AND a.month_start     = sma.month_start
GROUP BY a.month_start, a.tenure_cohort
ORDER BY a.month_start, a.tenure_cohort;
