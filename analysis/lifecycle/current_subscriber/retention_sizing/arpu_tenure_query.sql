-- =============================================================================
-- RETENTION SIZING — ARPU & TENURE QUERIES
-- Snowflake dialect | soundstripe_prod.core schema
-- Run both queries, export as r1.csv, r2.csv
-- =============================================================================


-- ---------------------------------------------------------------------------
-- QUERY R1: ARPU by plan type
-- Currently active subscribers, grouped by plan_type only (not billing period).
-- The MONTHLY_REVENUE column is already normalized to monthly.
-- ---------------------------------------------------------------------------
SELECT
    sp.plan_type,
    COUNT(DISTINCT sp.soundstripe_subscription_id) AS active_subs,
    ROUND(AVG(sp.monthly_revenue), 2) AS avg_monthly_revenue,
    ROUND(MEDIAN(sp.monthly_revenue), 2) AS median_monthly_revenue,
    ROUND(SUM(sp.monthly_revenue), 2) AS total_monthly_revenue,
    -- Billing mix for context
    COUNT(DISTINCT CASE WHEN sp.billing_period_unit = 'year' THEN sp.soundstripe_subscription_id END) AS annual_subs,
    COUNT(DISTINCT CASE WHEN sp.billing_period_unit = 'month' THEN sp.soundstripe_subscription_id END) AS monthly_subs,
    COUNT(DISTINCT CASE WHEN sp.billing_period_unit = 'quarter' THEN sp.soundstripe_subscription_id END) AS quarterly_subs
FROM soundstripe_prod.core.subscription_periods sp
WHERE sp.start_date <= CURRENT_DATE()
  AND (sp.cancelled_at IS NULL OR sp.cancelled_at >= DATE_TRUNC('month', CURRENT_DATE()))
GROUP BY sp.plan_type
ORDER BY sp.plan_type;


-- ---------------------------------------------------------------------------
-- QUERY R2: Tenure and trailing 6-month average churn rate by plan type
-- Uses 6 months (Sep 2025–Feb 2026) for stability instead of a single month.
-- Churn rate = cancellations in month / active subscribers at start of month.
-- ---------------------------------------------------------------------------
WITH months AS (
    SELECT '2025-09-01'::DATE AS month_start UNION ALL
    SELECT '2025-10-01'::DATE UNION ALL
    SELECT '2025-11-01'::DATE UNION ALL
    SELECT '2025-12-01'::DATE UNION ALL
    SELECT '2026-01-01'::DATE UNION ALL
    SELECT '2026-02-01'::DATE
),

monthly_counts AS (
    SELECT
        m.month_start,
        sp.plan_type,
        COUNT(DISTINCT sp.soundstripe_subscription_id) AS active_at_start,
        COUNT(DISTINCT CASE
            WHEN sp.cancelled_at >= m.month_start
             AND sp.cancelled_at < DATEADD('month', 1, m.month_start)
            THEN sp.soundstripe_subscription_id
        END) AS cancelled_in_month
    FROM months m
    INNER JOIN soundstripe_prod.core.subscription_periods sp
        ON sp.start_date <= LAST_DAY(m.month_start)
       AND (sp.cancelled_at IS NULL OR sp.cancelled_at >= m.month_start)
    GROUP BY m.month_start, sp.plan_type
),

-- Current tenure for active subscribers
tenure AS (
    SELECT
        sp.plan_type,
        ROUND(AVG(DATEDIFF('month', sp.start_date, CURRENT_DATE())), 1) AS avg_tenure_months,
        ROUND(MEDIAN(DATEDIFF('month', sp.start_date, CURRENT_DATE())), 1) AS median_tenure_months
    FROM soundstripe_prod.core.subscription_periods sp
    WHERE sp.start_date <= CURRENT_DATE()
      AND (sp.cancelled_at IS NULL OR sp.cancelled_at >= DATE_TRUNC('month', CURRENT_DATE()))
    GROUP BY sp.plan_type
)

SELECT
    mc.plan_type,
    -- 6-month average churn rate
    ROUND(AVG(100.0 * mc.cancelled_in_month / NULLIF(mc.active_at_start, 0)), 2) AS avg_monthly_churn_rate_pct,
    -- Also show the range for context
    ROUND(MIN(100.0 * mc.cancelled_in_month / NULLIF(mc.active_at_start, 0)), 2) AS min_monthly_churn_pct,
    ROUND(MAX(100.0 * mc.cancelled_in_month / NULLIF(mc.active_at_start, 0)), 2) AS max_monthly_churn_pct,
    -- Tenure
    t.avg_tenure_months,
    t.median_tenure_months,
    -- Implied average remaining tenure (1/churn_rate in months, capped at 60)
    ROUND(LEAST(60, 1.0 / NULLIF(AVG(mc.cancelled_in_month / NULLIF(mc.active_at_start, 0)), 0)), 1) AS implied_remaining_months
FROM monthly_counts mc
LEFT JOIN tenure t ON mc.plan_type = t.plan_type
GROUP BY mc.plan_type, t.avg_tenure_months, t.median_tenure_months
ORDER BY mc.plan_type;
