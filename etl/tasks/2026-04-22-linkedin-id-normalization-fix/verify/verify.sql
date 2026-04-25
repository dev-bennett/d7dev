-- verify.sql
-- Purpose: confirm the LinkedIn creative_id normalization fix landed correctly in prod.
--          Run AFTER the dbt PR merges and the next prod build completes.
--          Each labeled query is a single SELECT producing one exportable result.
--          Export as vN.csv next to this file.
-- Author: devon.bennett
-- Date: 2026-04-22
-- Dependencies:
--   soundstripe_prod.marketing.fct_ad_performance
--   soundstripe_prod.marketing.dim_ad_content
--   pc_stitch_db.linkedin_ads.creatives


----------------------------------------------------------------------
-- V1: 2026 LinkedIn spend by month in fct_ad_performance.
--     Expected: non-zero spend for every month 2026-01 through the current month.
--     Pre-fix baseline (for reference): 2026-04 = 1 row / ~0 USD. Post-fix target: ~5,037 USD.
----------------------------------------------------------------------
SELECT
    DATE_TRUNC('MONTH', date) AS month
    , COUNT(*) AS row_count
    , COUNT(DISTINCT ad_id) AS distinct_creatives
    , SUM(spend) AS total_spend_usd
    , SUM(impressions) AS total_impressions
    , SUM(clicks) AS total_clicks
FROM soundstripe_prod.marketing.fct_ad_performance
WHERE platform = 'linkedin'
    AND marketing_test_ind = 0
    AND date >= '2025-01-01'
GROUP BY 1
ORDER BY 1 DESC
;


----------------------------------------------------------------------
-- V2: Creative-name coverage on LinkedIn 2026 active rows via the
--     fct_ad_performance -> dim_ad_content LEFT JOIN.
--     Expected: pct_named ≥ 90% on rows dated 2026-01-01 onward.
----------------------------------------------------------------------
WITH linked AS (
    SELECT
        DATE_TRUNC('MONTH', f.date) AS month
        , f.ad_id
        , f.spend
        , d.creative_name
    FROM soundstripe_prod.marketing.fct_ad_performance f
    LEFT JOIN soundstripe_prod.marketing.dim_ad_content d
        ON f.ad_id = d.ad_id
        AND f.platform = d.platform
    WHERE f.platform = 'linkedin'
        AND f.marketing_test_ind = 0
        AND f.date >= '2026-01-01'
)
SELECT
    month
    , COUNT(*) AS row_count
    , SUM(CASE WHEN creative_name IS NOT NULL THEN 1 ELSE 0 END) AS rows_named
    , SUM(CASE WHEN creative_name IS NULL THEN 1 ELSE 0 END) AS rows_unnamed
    , ROUND(100.0 * SUM(CASE WHEN creative_name IS NOT NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 1) AS pct_named
    , SUM(spend) AS total_spend_usd
    , SUM(CASE WHEN creative_name IS NOT NULL THEN spend ELSE 0 END) AS spend_with_name
FROM linked
GROUP BY 1
ORDER BY 1 DESC
;


----------------------------------------------------------------------
-- V3: Facebook regression check — spend and name coverage should be
--     unchanged vs pre-fix. If any month's coverage drops materially,
--     the fix broke something upstream of fct_ad_performance.
----------------------------------------------------------------------
WITH linked AS (
    SELECT
        DATE_TRUNC('MONTH', f.date) AS month
        , f.ad_id
        , f.spend
        , d.creative_name
    FROM soundstripe_prod.marketing.fct_ad_performance f
    LEFT JOIN soundstripe_prod.marketing.dim_ad_content d
        ON f.ad_id = d.ad_id
        AND f.platform = d.platform
    WHERE f.platform = 'facebook'
        AND f.marketing_test_ind = 0
        AND f.date >= '2025-10-01'
)
SELECT
    month
    , COUNT(*) AS row_count
    , SUM(CASE WHEN creative_name IS NOT NULL THEN 1 ELSE 0 END) AS rows_named
    , ROUND(100.0 * SUM(CASE WHEN creative_name IS NOT NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*), 0), 1) AS pct_named
    , SUM(spend) AS total_spend_usd
FROM linked
GROUP BY 1
ORDER BY 1 DESC
;


----------------------------------------------------------------------
-- V4: dim_ad_content primary-key integrity. Both schema tests already
--     enforce unique+not_null at build time, but verify in prod at read time.
--     Expected: zero rows returned.
----------------------------------------------------------------------
SELECT
    platform
    , ad_id
    , COUNT(*) AS row_count
FROM soundstripe_prod.marketing.dim_ad_content
GROUP BY 1, 2
HAVING COUNT(*) > 1
ORDER BY row_count DESC
;


----------------------------------------------------------------------
-- V5: Spot-check named 2026 LinkedIn creatives from Taylor's ticket.
--     Expected: every named creative with activity since 2026-01-01
--     appears with non-null creative_name via the join.
----------------------------------------------------------------------
SELECT
    d.creative_name
    , f.ad_id
    , MIN(f.date) AS first_active_date
    , MAX(f.date) AS last_active_date
    , COUNT(*) AS perf_rows
    , SUM(f.spend) AS total_spend_usd
    , SUM(f.impressions) AS total_impressions
    , SUM(f.clicks) AS total_clicks
FROM soundstripe_prod.marketing.fct_ad_performance f
LEFT JOIN soundstripe_prod.marketing.dim_ad_content d
    ON f.ad_id = d.ad_id
    AND f.platform = d.platform
WHERE f.platform = 'linkedin'
    AND f.marketing_test_ind = 0
    AND f.date >= '2026-01-01'
    AND d.creative_name IS NOT NULL
GROUP BY 1, 2
ORDER BY total_spend_usd DESC NULLS LAST
LIMIT 50
;

select date_trunc(month, event_ts::date) as month,
       count(*) as instances
from soundstripe_prod.core.fct_events
where lower(event) = 'clicked element'
  and lower(context) = 'onboarding'
  and date_trunc(month,event_ts::date) > '2025-06-01'
group by 1
order by 1