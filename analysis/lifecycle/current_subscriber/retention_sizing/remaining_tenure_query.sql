-- =============================================================================
-- REMAINING TENURE — Conditional Expected Remaining Months
-- Snowflake dialect | soundstripe_prod.core schema
--
-- Approach: For subscribers who cancelled, compute how many additional months
-- they survived beyond each tenure milestone. Then weight by the current
-- active subscriber tenure distribution to get a plan-level estimate.
--
-- Export as rt1.csv, rt2.csv
-- =============================================================================


-- ---------------------------------------------------------------------------
-- QUERY RT1: Conditional remaining tenure from historical cancellations
--
-- For each plan_type and tenure_bucket, among subscribers who cancelled
-- AND had at least reached that tenure bucket, how many additional months
-- did they survive beyond the bucket threshold?
--
-- This is the empirical conditional survival function.
-- Uses cancellations from the last 3 years for sample size.
-- ---------------------------------------------------------------------------
WITH cancelled_subs AS (
    SELECT
        sp.soundstripe_subscription_id AS subscription_id,
        sp.plan_type,
        sp.billing_period_unit,
        sp.start_date,
        sp.cancelled_at,
        DATEDIFF('month', sp.start_date, sp.cancelled_at) AS total_tenure_months
    FROM soundstripe_prod.core.subscription_periods sp
    WHERE sp.cancelled_at IS NOT NULL
      AND sp.cancelled_at >= DATEADD('year', -3, CURRENT_DATE())
      AND sp.start_date IS NOT NULL
      AND DATEDIFF('month', sp.start_date, sp.cancelled_at) >= 0
),

tenure_buckets AS (
    SELECT 0 AS bucket_start, 3 AS bucket_end, '0-3 mo' AS bucket_label UNION ALL
    SELECT 3, 6, '3-6 mo' UNION ALL
    SELECT 6, 12, '6-12 mo' UNION ALL
    SELECT 12, 24, '12-24 mo' UNION ALL
    SELECT 24, 36, '24-36 mo' UNION ALL
    SELECT 36, 48, '36-48 mo' UNION ALL
    SELECT 48, 999, '48+ mo'
)

SELECT
    cs.plan_type,
    tb.bucket_label AS tenure_bucket,
    tb.bucket_start,
    -- How many cancelled subs reached at least this tenure?
    COUNT(*) AS subs_who_reached_bucket,
    -- Of those, how many additional months did they survive beyond bucket_start?
    ROUND(AVG(cs.total_tenure_months - tb.bucket_start), 1) AS avg_additional_months,
    ROUND(MEDIAN(cs.total_tenure_months - tb.bucket_start), 1) AS median_additional_months,
    ROUND(PERCENTILE_CONT(0.25) WITHIN GROUP (ORDER BY cs.total_tenure_months - tb.bucket_start), 1) AS p25_additional_months,
    ROUND(PERCENTILE_CONT(0.75) WITHIN GROUP (ORDER BY cs.total_tenure_months - tb.bucket_start), 1) AS p75_additional_months
FROM cancelled_subs cs
CROSS JOIN tenure_buckets tb
WHERE cs.total_tenure_months >= tb.bucket_start
GROUP BY cs.plan_type, tb.bucket_label, tb.bucket_start
HAVING COUNT(*) >= 20  -- minimum sample size
ORDER BY cs.plan_type, tb.bucket_start;


-- ---------------------------------------------------------------------------
-- QUERY RT2: Current active subscriber tenure distribution
--
-- For each plan_type, how many active subscribers are in each tenure bucket?
-- Combined with RT1, this produces a weighted average remaining tenure.
-- ---------------------------------------------------------------------------
WITH active_subs AS (
    SELECT
        sp.soundstripe_subscription_id AS subscription_id,
        sp.plan_type,
        sp.start_date,
        DATEDIFF('month', sp.start_date, CURRENT_DATE()) AS current_tenure_months
    FROM soundstripe_prod.core.subscription_periods sp
    WHERE sp.start_date <= CURRENT_DATE()
      AND (sp.cancelled_at IS NULL OR sp.cancelled_at >= DATE_TRUNC('month', CURRENT_DATE()))
),

tenure_buckets AS (
    SELECT 0 AS bucket_start, 3 AS bucket_end, '0-3 mo' AS bucket_label UNION ALL
    SELECT 3, 6, '3-6 mo' UNION ALL
    SELECT 6, 12, '6-12 mo' UNION ALL
    SELECT 12, 24, '12-24 mo' UNION ALL
    SELECT 24, 36, '24-36 mo' UNION ALL
    SELECT 36, 48, '36-48 mo' UNION ALL
    SELECT 48, 999, '48+ mo'
)

SELECT
    a.plan_type,
    tb.bucket_label AS tenure_bucket,
    tb.bucket_start,
    COUNT(DISTINCT a.subscription_id) AS active_subs_in_bucket,
    ROUND(100.0 * COUNT(DISTINCT a.subscription_id)
        / SUM(COUNT(DISTINCT a.subscription_id)) OVER (PARTITION BY a.plan_type), 1) AS pct_of_plan
FROM active_subs a
INNER JOIN tenure_buckets tb
    ON a.current_tenure_months >= tb.bucket_start
   AND a.current_tenure_months < tb.bucket_end
GROUP BY a.plan_type, tb.bucket_label, tb.bucket_start
ORDER BY a.plan_type, tb.bucket_start;
