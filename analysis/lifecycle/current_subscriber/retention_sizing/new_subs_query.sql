-- ---------------------------------------------------------------------------
-- Monthly new subscription volume by plan type
-- Trailing 6 months (Sep 2025 – Feb 2026) for consistency with other inputs
-- Export as ns1.csv
-- ---------------------------------------------------------------------------
SELECT
    DATE_TRUNC('month', sp.start_date) AS month_start,
    sp.plan_type,
    COUNT(DISTINCT sp.soundstripe_subscription_id) AS new_subscriptions
FROM soundstripe_prod.core.subscription_periods sp
WHERE sp.start_date >= '2025-09-01'
  AND sp.start_date < '2026-03-01'
  AND sp.plan_type IN ('business', 'creator', 'enterprise', 'pro', 'pro-plus')
GROUP BY 1, 2
ORDER BY 1, 2;
