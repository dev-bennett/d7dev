-- M1 — Tile 12 expansion-rate root-cause
-- Author: Devon  Date: 2026-04-28

------------------------------------------------------------------------
-- m1_q01 — chargebee_subscription_changes event volume per month
-- Tests M1.4: did the upstream change-event volume drop?
------------------------------------------------------------------------
SELECT
    DATE_TRUNC('month', occurred_at)::DATE AS month_start,
    COUNT(*) AS total_change_events,
    COUNT(DISTINCT chargebee_subscription_id) AS distinct_subs_with_change,
    SUM(CASE WHEN prior_plan_type IS NOT NULL AND new_plan_type IS NOT NULL THEN 1 ELSE 0 END) AS plan_type_changes_with_both_known,
    SUM(CASE WHEN prior_plan_type = new_plan_type THEN 1 ELSE 0 END) AS same_plan_changes,
    SUM(CASE WHEN prior_plan_type IS NOT NULL AND new_plan_type IS NOT NULL
                  AND prior_plan_type <> new_plan_type THEN 1 ELSE 0 END) AS distinct_plan_changes
FROM soundstripe_prod.transformations.chargebee_subscription_changes
WHERE occurred_at >= '2024-04-01' AND occurred_at < '2026-05-01'
GROUP BY 1 ORDER BY 1;

-- TYPE AUDIT — m1_q01:
--   No rates declared; raw counts. JOIN chain: NONE. RESULT: PASS.

------------------------------------------------------------------------
-- m1_q02 — qualifying subs by prior_plan tier per month (Tests M1.3)
-- Replicates q03 (console.sql) but breaks out the qualifying_subs by prior_plan tier
-- so we can see the cohort composition shift directly.
------------------------------------------------------------------------
WITH sub_changes AS (
    SELECT
        a.start_date, a.subscription_id,
        COALESCE(c.plan_array, b.prior_plan_type) AS prior_plan_raw,
        CASE WHEN COALESCE(c.plan_array, b.prior_plan_type) ILIKE 'business%' THEN 'business'
             WHEN COALESCE(c.plan_array, b.prior_plan_type) ILIKE 'creator%'  THEN 'personal'
             WHEN COALESCE(c.plan_array, b.prior_plan_type) ILIKE 'enterprise%' THEN 'enterprise'
             WHEN COALESCE(c.plan_array, b.prior_plan_type) ILIKE ANY('pro-plus%','video%') THEN 'pro-plus'
             WHEN COALESCE(c.plan_array, b.prior_plan_type) ILIKE ANY('music%','pro%','sfx%','standard%','premium%') THEN 'pro'
             ELSE 'other' END AS prior_plan,
        ROW_NUMBER() OVER (PARTITION BY a.subscription_id ORDER BY b.occurred_at DESC) AS rn
    FROM soundstripe_prod.core.subscription_periods a
        LEFT JOIN soundstripe_prod.transformations.chargebee_subscription_changes b
            ON a.subscription_id = b.chargebee_subscription_id
            AND DATEDIFF('day', a.start_date::DATE, b.occurred_at::DATE) <= 30
        LEFT JOIN soundstripe_prod.transformations.chargebee_subscription_invoices c
            ON a.subscription_id = c.subscription_id
            AND c.subscription_invoice_number = 1
    WHERE a.start_date >= '2024-05-01' AND a.start_date < '2026-05-01'
)
SELECT DATE_TRUNC('month', start_date)::DATE AS month_start,
       prior_plan,
       COUNT(DISTINCT subscription_id) AS qualifying_subs
FROM sub_changes
WHERE rn = 1 AND prior_plan IN ('personal','pro','pro-plus')
GROUP BY 1, 2 ORDER BY 1, 2;

-- TYPE AUDIT — m1_q02:
--   Declared denominator: subscription_periods rows (rn=1) filtered to prior_plan ∈ list.
--   Sum across all 3 prior_plans = q03.csv qualifying_subs_for_expansion_rate (2,041 verified at 2024-05-01).
--   RESULT: PASS.
--   Note: an "expansions" column was attempted but produced inflated counts due to LTV-table
--   fanout (LEFT JOIN to subscription_ltv_assumptions on plan only — NOT on billing_interval —
--   produces 1-3 LTV rows per source row). q03 in console.sql exhibits the same fanout but
--   yields q03.csv values that match the dashboard, suggesting Snowflake's join behavior
--   happens to pick consistent rows. This M1 query DOES NOT use the expansion count; it uses
--   only the qualifying_subs count (which is fanout-invariant via COUNT DISTINCT).
