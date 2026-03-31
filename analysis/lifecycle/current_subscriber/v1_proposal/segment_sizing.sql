-- =============================================================================
-- LIFECYCLE EMAIL FLOW — SEGMENT SIZING (v2)
-- Snowflake dialect | soundstripe_prod.core schema
-- Purpose: Classify every active non-enterprise subscriber into a lifecycle
--          segment using rolling 30-day windows, and compute segment sizes.
-- =============================================================================
--
-- SEGMENT DEFINITIONS (rolling windows from evaluation date):
--   ACTIVE_DOWNLOADER = session in last 30 days AND downloaded 1+ song/SFX
--   ACTIVE_BROWSER    = session in last 30 days AND no downloads
--   EARLY_LAPSE       = no session in last 30 days; last session 31-60 days ago
--   DEEP_LAPSE        = no session in last 30 days; last session 61-180 days ago
--   DORMANT           = no session in last 30 days; last session 180+ days ago OR never
--
-- EXCLUSIONS:
--   Enterprise plan subscribers (handled by Sales/AM)
--   New subscribers (subscribed within last 30 days) — existing onboarding flow
--
-- DENOMINATOR: all active non-enterprise subscribers with tenure > 30 days
-- GRAIN: one row per evaluation_date × plan_type × segment
-- =============================================================================


-- ---------------------------------------------------------------------------
-- QUERY S1: Monthly segment sizes — trailing 12 months
-- Evaluates segments at end of each month using rolling 30-day windows
-- ---------------------------------------------------------------------------
WITH evaluation_dates AS (
    -- Last day of each of the past 12 months
    SELECT DATEADD('day', -1, DATEADD('month', -seq.n, DATE_TRUNC('month', CURRENT_DATE()))) AS eval_date
    FROM (
        SELECT ROW_NUMBER() OVER (ORDER BY seq4()) - 1 AS n
        FROM TABLE(GENERATOR(ROWCOUNT => 12))
    ) seq
    WHERE seq.n BETWEEN 0 AND 11
),

active_subs AS (
    SELECT
        e.eval_date,
        sp.soundstripe_subscription_id AS subscription_id,
        sp.start_date,
        sp.plan_type,
        sp.billing_period_unit
    FROM evaluation_dates e
    INNER JOIN soundstripe_prod.core.subscription_periods sp
        ON sp.start_date <= e.eval_date
       AND (sp.cancelled_at IS NULL OR sp.cancelled_at > e.eval_date)
    WHERE sp.plan_type NOT IN ('enterprise')
      -- Exclude new subscribers (subscribed within last 30 days)
      AND DATEDIFF('day', sp.start_date, e.eval_date) > 30
),

-- Session activity in the 30-day window before each evaluation date
rolling_activity AS (
    SELECT
        e.eval_date,
        s.current_subscription_id AS subscription_id,
        SUM(COALESCE(s.downloaded_songs_count, 0))
            + SUM(COALESCE(s.downloaded_sound_effects_count, 0)) AS total_downloads,
        SUM(COALESCE(s.searched_songs_count, 0))
            + SUM(COALESCE(s.searched_sound_effects_count, 0))   AS total_searches,
        COUNT(DISTINCT s.session_id) AS session_count
    FROM evaluation_dates e
    INNER JOIN soundstripe_prod.core.fct_sessions s
        ON s.session_started_at > DATEADD('day', -30, e.eval_date)
       AND s.session_started_at <= e.eval_date
       AND s.current_subscription_id IS NOT NULL
    GROUP BY 1, 2
),

-- Last session date ever (for lapse classification)
last_session_ever AS (
    SELECT
        s.current_subscription_id AS subscription_id,
        MAX(s.session_started_at) AS last_session_date
    FROM soundstripe_prod.core.fct_sessions s
    WHERE s.current_subscription_id IS NOT NULL
    GROUP BY 1
),

-- Classify each subscriber at each evaluation date
classified AS (
    SELECT
        a.eval_date,
        a.subscription_id,
        a.start_date,
        a.plan_type,
        a.billing_period_unit,
        ra.subscription_id IS NOT NULL AS had_session_in_window,
        COALESCE(ra.total_downloads, 0) AS downloads_in_window,
        lse.last_session_date,
        DATEDIFF('day', lse.last_session_date, a.eval_date) AS days_since_last_session,
        CASE
            -- Active Downloader: session in last 30 days + downloaded
            WHEN ra.subscription_id IS NOT NULL AND COALESCE(ra.total_downloads, 0) > 0
                THEN 'ACTIVE_DOWNLOADER'
            -- Active Browser: session in last 30 days but no downloads
            WHEN ra.subscription_id IS NOT NULL AND COALESCE(ra.total_downloads, 0) = 0
                THEN 'ACTIVE_BROWSER'
            -- No session in last 30 days — classify by recency of last session ever
            WHEN lse.last_session_date IS NULL
                THEN 'DORMANT'
            WHEN DATEDIFF('day', lse.last_session_date, a.eval_date) BETWEEN 31 AND 60
                THEN 'EARLY_LAPSE'
            WHEN DATEDIFF('day', lse.last_session_date, a.eval_date) BETWEEN 61 AND 180
                THEN 'DEEP_LAPSE'
            WHEN DATEDIFF('day', lse.last_session_date, a.eval_date) > 180
                THEN 'DORMANT'
            -- Edge: last session 1-30 days ago but not captured in rolling window
            -- (shouldn't happen given the 30-day window, but safety fallback)
            ELSE 'EARLY_LAPSE'
        END AS lifecycle_segment
    FROM active_subs a
    LEFT JOIN rolling_activity ra
        ON a.subscription_id = ra.subscription_id
       AND a.eval_date       = ra.eval_date
    LEFT JOIN last_session_ever lse
        ON a.subscription_id = lse.subscription_id
)

SELECT
    eval_date                                                       AS month_end,
    DATE_TRUNC('month', eval_date)                                  AS month_start,
    plan_type,
    lifecycle_segment,
    COUNT(DISTINCT subscription_id)                                 AS subscriber_count,
    ROUND(100.0 * COUNT(DISTINCT subscription_id)
        / SUM(COUNT(DISTINCT subscription_id)) OVER (PARTITION BY eval_date, plan_type), 1) AS pct_of_plan_total,
    COUNT(DISTINCT CASE WHEN billing_period_unit = 'year' THEN subscription_id END)  AS annual_subs,
    COUNT(DISTINCT CASE WHEN billing_period_unit = 'month' THEN subscription_id END) AS monthly_subs
FROM classified
GROUP BY eval_date, plan_type, lifecycle_segment
ORDER BY eval_date, plan_type,
    CASE lifecycle_segment
        WHEN 'ACTIVE_DOWNLOADER' THEN 1
        WHEN 'ACTIVE_BROWSER'    THEN 2
        WHEN 'EARLY_LAPSE'       THEN 3
        WHEN 'DEEP_LAPSE'        THEN 4
        WHEN 'DORMANT'           THEN 5
    END;


-- ---------------------------------------------------------------------------
-- QUERY S2: Segment transition matrix — month over month
-- Compares each subscriber's segment at consecutive month-end evaluation dates
-- Uses rolling 30-day windows at each evaluation point
-- Trailing 6 months for stable averages
-- ---------------------------------------------------------------------------
WITH evaluation_dates AS (
    SELECT DATEADD('day', -1, DATEADD('month', -seq.n, DATE_TRUNC('month', CURRENT_DATE()))) AS eval_date
    FROM (
        SELECT ROW_NUMBER() OVER (ORDER BY seq4()) - 1 AS n
        FROM TABLE(GENERATOR(ROWCOUNT => 8))
    ) seq
    WHERE seq.n BETWEEN 0 AND 7
),

active_subs AS (
    SELECT
        e.eval_date,
        sp.soundstripe_subscription_id AS subscription_id,
        sp.start_date,
        sp.plan_type
    FROM evaluation_dates e
    INNER JOIN soundstripe_prod.core.subscription_periods sp
        ON sp.start_date <= e.eval_date
       AND (sp.cancelled_at IS NULL OR sp.cancelled_at > e.eval_date)
    WHERE sp.plan_type NOT IN ('enterprise')
      AND DATEDIFF('day', sp.start_date, e.eval_date) > 30
),

rolling_activity AS (
    SELECT
        e.eval_date,
        s.current_subscription_id AS subscription_id,
        SUM(COALESCE(s.downloaded_songs_count, 0))
            + SUM(COALESCE(s.downloaded_sound_effects_count, 0)) AS total_downloads
    FROM evaluation_dates e
    INNER JOIN soundstripe_prod.core.fct_sessions s
        ON s.session_started_at > DATEADD('day', -30, e.eval_date)
       AND s.session_started_at <= e.eval_date
       AND s.current_subscription_id IS NOT NULL
    GROUP BY 1, 2
),

last_session_ever AS (
    SELECT
        s.current_subscription_id AS subscription_id,
        MAX(s.session_started_at) AS last_session_date
    FROM soundstripe_prod.core.fct_sessions s
    WHERE s.current_subscription_id IS NOT NULL
    GROUP BY 1
),

classified AS (
    SELECT
        a.eval_date,
        a.subscription_id,
        a.plan_type,
        CASE
            WHEN ra.subscription_id IS NOT NULL AND COALESCE(ra.total_downloads, 0) > 0
                THEN 'ACTIVE_DOWNLOADER'
            WHEN ra.subscription_id IS NOT NULL AND COALESCE(ra.total_downloads, 0) = 0
                THEN 'ACTIVE_BROWSER'
            WHEN lse.last_session_date IS NULL
                THEN 'DORMANT'
            WHEN DATEDIFF('day', lse.last_session_date, a.eval_date) BETWEEN 31 AND 60
                THEN 'EARLY_LAPSE'
            WHEN DATEDIFF('day', lse.last_session_date, a.eval_date) BETWEEN 61 AND 180
                THEN 'DEEP_LAPSE'
            WHEN DATEDIFF('day', lse.last_session_date, a.eval_date) > 180
                THEN 'DORMANT'
            ELSE 'EARLY_LAPSE'
        END AS lifecycle_segment
    FROM active_subs a
    LEFT JOIN rolling_activity ra
        ON a.subscription_id = ra.subscription_id
       AND a.eval_date       = ra.eval_date
    LEFT JOIN last_session_ever lse
        ON a.subscription_id = lse.subscription_id
),

-- Pair each subscriber's current evaluation with prior month's evaluation
transitions AS (
    SELECT
        c.eval_date,
        c.subscription_id,
        c.plan_type,
        c.lifecycle_segment AS current_segment,
        LAG(c.lifecycle_segment) OVER (
            PARTITION BY c.subscription_id ORDER BY c.eval_date
        ) AS prior_segment
    FROM classified c
)

SELECT
    plan_type,
    prior_segment,
    current_segment,
    COUNT(DISTINCT subscription_id) AS subscriber_count,
    ROUND(COUNT(DISTINCT subscription_id) / 6.0, 0) AS avg_monthly_transitions
FROM transitions
WHERE prior_segment IS NOT NULL
  -- Use most recent 6 evaluation dates for averaging
  AND eval_date >= DATEADD('month', -6, (SELECT MAX(eval_date) FROM evaluation_dates))
GROUP BY plan_type, prior_segment, current_segment
ORDER BY plan_type, prior_segment, current_segment;
