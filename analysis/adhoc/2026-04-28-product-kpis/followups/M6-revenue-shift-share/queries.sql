-- M6 — Revenue/session shift-share decomposition
-- Author: Devon  Date: 2026-04-28

------------------------------------------------------------------------
-- m6_q01 — subscription_ltv_assumptions snapshot (small dim, single-row-peek confirms current)
------------------------------------------------------------------------
SELECT plan, billing_interval, ltv_1_yr_gm
FROM soundstripe_prod.finance.subscription_ltv_assumptions
ORDER BY plan, billing_interval;

------------------------------------------------------------------------
-- m6_q02 — new-subscription plan_tier × billing_interval × month, 24m
------------------------------------------------------------------------
WITH sub_changes AS (
    SELECT
        a.start_date,
        a.subscription_id,
        COALESCE(b.new_plan_type, c.plan_array) AS new_plan_raw,
        CASE WHEN COALESCE(b.new_plan_type, c.plan_array) ILIKE 'business%' THEN 'business'
             WHEN COALESCE(b.new_plan_type, c.plan_array) ILIKE 'creator%'  THEN 'personal'
             WHEN COALESCE(b.new_plan_type, c.plan_array) ILIKE 'enterprise%'
               OR COALESCE(b.new_plan_type, c.plan_array) IN (
                  'pro-microsoft_production_studios','pro-portlandjesuit','pro-renderstudios',
                  'pro-shakr','pro-south-dakota-university','pro-volkswagon','pro-waymark') THEN 'enterprise'
             WHEN COALESCE(b.new_plan_type, c.plan_array) ILIKE ANY('pro-plus%','video%') THEN 'pro-plus'
             WHEN COALESCE(b.new_plan_type, c.plan_array) ILIKE ANY('music%','pro%','sfx%','standard%','premium%') THEN 'pro'
             WHEN COALESCE(b.new_plan_type, c.plan_array) ILIKE 'twitch-pro%' THEN 'twitch-pro'
             ELSE 'other' END AS plan_tier,
        a.billing_period_unit AS billing_interval,
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
       plan_tier, billing_interval,
       COUNT(DISTINCT subscription_id) AS subs
FROM sub_changes WHERE rn = 1
GROUP BY 1, 2, 3 ORDER BY 1, 2, 3;

-- TYPE AUDIT — m6_q02:
--   Declared denominator: subscription_periods (one row per subscription_id, gated by rn=1).
--   JOIN chain: LEFT JOIN preserves all subscription_periods rows; missing chargebee fall through with
--               COALESCE to invoice plan_array. Classification taxonomy mirrors q03 in console.sql exactly.
--   RESULT: PASS. Note: the 'pro' bucket is broad (matches music%, pro%, sfx%, standard%, premium%);
--   its share inflation 2024→2026 may partly reflect classifier coverage of legacy plan names.
