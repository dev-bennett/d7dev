-- diagnose.sql
-- Purpose: confirm root cause of LinkedIn fct_ad_performance / dim_ad_content join failure.
--          Each labeled query (Q1..Q6) is a single SELECT producing one exportable result.
--          Export results as qN.csv in this directory.
-- Author: devon.bennett
-- Date: 2026-04-22
-- Dependencies:
--   pc_stitch_db.linkedin_ads.ad_analytics_by_creative
--   pc_stitch_db.linkedin_ads.creatives
--   pc_stitch_db.linkedin_ads.campaigns


----------------------------------------------------------------------
-- Q1: Stitch freshness — is the LinkedIn source still receiving data?
--     Expected: max_date within the last 3 days for ad_analytics_by_creative
----------------------------------------------------------------------
SELECT
    'ad_analytics_by_creative' AS table_name
    , MAX(start_at::DATE) AS max_date
    , MIN(start_at::DATE) AS min_date
    , COUNT(*) AS row_count
    , COUNT(DISTINCT creative_id) AS distinct_keys
FROM pc_stitch_db.linkedin_ads.ad_analytics_by_creative

UNION ALL

SELECT
    'creatives'
    , MAX(last_modified_at::DATE)
    , MIN(created_at::DATE)
    , COUNT(*)
    , COUNT(DISTINCT id)
FROM pc_stitch_db.linkedin_ads.creatives

UNION ALL

SELECT
    'campaigns'
    , MAX(created_time::DATE)
    , MIN(created_time::DATE)
    , COUNT(*)
    , COUNT(DISTINCT id)
FROM pc_stitch_db.linkedin_ads.campaigns
ORDER BY table_name
;


----------------------------------------------------------------------
-- Q2: ID format samples — 20 most recent distinct IDs from each side of
--     the join, with all three candidate normalizations computed side-by-side.
--     "side" column separates the two populations.
----------------------------------------------------------------------
WITH analytics_sample AS (
    SELECT
        'analytics.creative_id' AS side
        , creative_id::VARCHAR AS raw_id
        , LENGTH(creative_id::VARCHAR) AS id_length
        , RIGHT(creative_id::VARCHAR, 9) AS key_right9
        , SPLIT_PART(creative_id::VARCHAR, ':', -1) AS key_split_colon
        , REGEXP_SUBSTR(creative_id::VARCHAR, '[0-9]+$') AS key_regex_numeric
        , MAX(start_at::DATE) AS latest_date_seen
    FROM pc_stitch_db.linkedin_ads.ad_analytics_by_creative
    WHERE start_at::DATE >= DATEADD(MONTH, -6, CURRENT_DATE)
    GROUP BY 1, 2, 3, 4, 5, 6
    QUALIFY ROW_NUMBER() OVER (ORDER BY MAX(start_at::DATE) DESC) <= 20
)
, creatives_sample AS (
    SELECT
        'creatives.id' AS side
        , id::VARCHAR AS raw_id
        , LENGTH(id::VARCHAR) AS id_length
        , RIGHT(id::VARCHAR, 9) AS key_right9
        , SPLIT_PART(id::VARCHAR, ':', -1) AS key_split_colon
        , REGEXP_SUBSTR(id::VARCHAR, '[0-9]+$') AS key_regex_numeric
        , last_modified_at::DATE AS latest_date_seen
    FROM pc_stitch_db.linkedin_ads.creatives
    QUALIFY ROW_NUMBER() OVER (ORDER BY last_modified_at DESC) <= 20
)
SELECT * FROM analytics_sample
UNION ALL
SELECT * FROM creatives_sample
ORDER BY side, latest_date_seen DESC
;


----------------------------------------------------------------------
-- Q3: Length distribution — how many distinct IDs of each length live
--     in each source table. Expect a rollover point where analytics
--     lengths diverge from creatives lengths.
----------------------------------------------------------------------
SELECT
    'analytics' AS source_table
    , LENGTH(creative_id::VARCHAR) AS id_length
    , COUNT(DISTINCT creative_id) AS distinct_ids
FROM pc_stitch_db.linkedin_ads.ad_analytics_by_creative
GROUP BY 1, 2

UNION ALL

SELECT
    'creatives'
    , LENGTH(id::VARCHAR)
    , COUNT(DISTINCT id)
FROM pc_stitch_db.linkedin_ads.creatives
GROUP BY 1, 2
ORDER BY source_table, id_length
;


----------------------------------------------------------------------
-- Q4: Current join coverage by month — how many analytics rows (and
--     how much spend) survive the existing right(id, 9) INNER JOIN.
--     Expect a step-change where 2026 rows drop out.
----------------------------------------------------------------------
WITH analytics AS (
    SELECT
        start_at::DATE AS date
        , creative_id::VARCHAR AS analytics_creative_id
        , cost_in_usd
        , impressions
    FROM pc_stitch_db.linkedin_ads.ad_analytics_by_creative
)
, creatives_right9 AS (
    SELECT DISTINCT RIGHT(id::VARCHAR, 9) AS k
    FROM pc_stitch_db.linkedin_ads.creatives
)
, tagged AS (
    SELECT
        a.date
        , a.cost_in_usd
        , a.impressions
        , CASE WHEN r9.k IS NOT NULL THEN 1 ELSE 0 END AS joined_right9
    FROM analytics a
    LEFT JOIN creatives_right9 r9 ON a.analytics_creative_id = r9.k
)
SELECT
    DATE_TRUNC('MONTH', date) AS month
    , COUNT(*) AS analytics_rows
    , SUM(cost_in_usd) AS total_spend_usd
    , SUM(impressions) AS total_impressions
    , SUM(joined_right9) AS rows_joined
    , COUNT(*) - SUM(joined_right9) AS rows_unjoined
    , SUM(CASE WHEN joined_right9 = 0 THEN cost_in_usd ELSE 0 END) AS unjoined_spend_usd
    , ROUND(100.0 * SUM(joined_right9) / NULLIF(COUNT(*), 0), 1) AS pct_joined
FROM tagged
GROUP BY 1
ORDER BY 1 DESC
;


----------------------------------------------------------------------
-- Q5: Proposed key coverage by month — for each candidate normalization
--     on creatives.id, how many analytics rows (and spend) join. Compare
--     right_9 (current) vs split_colon vs regex_numeric.
--     Expectation: split_colon / regex_numeric recover 2026 rows.
----------------------------------------------------------------------
WITH analytics AS (
    SELECT
        start_at::DATE AS date
        , creative_id::VARCHAR AS analytics_creative_id
        , cost_in_usd
    FROM pc_stitch_db.linkedin_ads.ad_analytics_by_creative
)
, keys_right9 AS (
    SELECT DISTINCT RIGHT(id::VARCHAR, 9) AS k
    FROM pc_stitch_db.linkedin_ads.creatives
)
, keys_split AS (
    SELECT DISTINCT SPLIT_PART(id::VARCHAR, ':', -1) AS k
    FROM pc_stitch_db.linkedin_ads.creatives
)
, keys_regex AS (
    SELECT DISTINCT REGEXP_SUBSTR(id::VARCHAR, '[0-9]+$') AS k
    FROM pc_stitch_db.linkedin_ads.creatives
)
, tagged AS (
    SELECT
        a.date
        , a.cost_in_usd
        , CASE WHEN r9.k IS NOT NULL THEN 1 ELSE 0 END AS matched_right9
        , CASE WHEN sp.k IS NOT NULL THEN 1 ELSE 0 END AS matched_split
        , CASE WHEN rx.k IS NOT NULL THEN 1 ELSE 0 END AS matched_regex
    FROM analytics a
    LEFT JOIN keys_right9 r9 ON a.analytics_creative_id = r9.k
    LEFT JOIN keys_split sp ON a.analytics_creative_id = sp.k
    LEFT JOIN keys_regex rx ON a.analytics_creative_id = rx.k
)
SELECT
    DATE_TRUNC('MONTH', date) AS month
    , COUNT(*) AS analytics_rows
    , SUM(cost_in_usd) AS total_spend_usd
    , SUM(matched_right9) AS matched_right9
    , SUM(matched_split) AS matched_split
    , SUM(matched_regex) AS matched_regex
    , ROUND(100.0 * SUM(matched_right9) / NULLIF(COUNT(*), 0), 1) AS pct_right9
    , ROUND(100.0 * SUM(matched_split) / NULLIF(COUNT(*), 0), 1) AS pct_split
    , ROUND(100.0 * SUM(matched_regex) / NULLIF(COUNT(*), 0), 1) AS pct_regex
FROM tagged
GROUP BY 1
ORDER BY 1 DESC
;


----------------------------------------------------------------------
-- Q6: Key-scheme safety summary — for each candidate normalization on
--     creatives.id, does it (a) emit NULLs, (b) collapse distinct
--     creatives into the same key (collisions)?
--     Null or colliding keys = unsafe primary key.
----------------------------------------------------------------------
WITH per_id AS (
    SELECT
        id::VARCHAR AS raw_id
        , RIGHT(id::VARCHAR, 9) AS k_right9
        , SPLIT_PART(id::VARCHAR, ':', -1) AS k_split
        , REGEXP_SUBSTR(id::VARCHAR, '[0-9]+$') AS k_regex
    FROM pc_stitch_db.linkedin_ads.creatives
)
, unpivoted AS (
    SELECT 'right_9' AS key_scheme, k_right9 AS k, raw_id FROM per_id
    UNION ALL
    SELECT 'split_colon', k_split, raw_id FROM per_id
    UNION ALL
    SELECT 'regex_numeric', k_regex, raw_id FROM per_id
)
, per_key AS (
    SELECT
        key_scheme
        , k
        , COUNT(DISTINCT raw_id) AS distinct_raw_ids
    FROM unpivoted
    GROUP BY 1, 2
)
SELECT
    key_scheme
    , COUNT(*) AS total_keys
    , SUM(CASE WHEN k IS NULL OR k = '' THEN 1 ELSE 0 END) AS null_or_empty_keys
    , SUM(CASE WHEN distinct_raw_ids > 1 THEN 1 ELSE 0 END) AS colliding_keys
    , SUM(CASE WHEN distinct_raw_ids > 1 THEN distinct_raw_ids ELSE 0 END) AS ambiguous_raw_ids
    , MAX(distinct_raw_ids) AS worst_collision_size
FROM per_key
GROUP BY 1
ORDER BY 1
;

-- 2026 LinkedIn spend should now be present in dev
SELECT DATE_TRUNC('MONTH', date) AS month
     , COUNT(*) AS row_count
     , SUM(spend) AS total_spend_usd
FROM soundstripe_dev.marketing.fct_ad_performance
WHERE platform = 'linkedin'
  AND marketing_test_ind = 0
  AND date >= '2026-01-01'
GROUP BY 1
ORDER BY 1 DESC;

-- LinkedIn creative_name join coverage in dev
SELECT DATE_TRUNC('MONTH', f.date) AS month
     , COUNT(*) AS row_count
     , ROUND(100.0 * SUM(CASE WHEN d.creative_name IS NOT NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 1) AS pct_named
FROM soundstripe_dev.marketing.fct_ad_performance f
LEFT JOIN soundstripe_dev.marketing.dim_ad_content d
    ON f.ad_id = d.ad_id AND f.platform = d.platform
WHERE f.platform = 'linkedin'
  AND f.marketing_test_ind = 0
  AND f.date >= '2026-01-01'
GROUP BY 1
ORDER BY 1 DESC;