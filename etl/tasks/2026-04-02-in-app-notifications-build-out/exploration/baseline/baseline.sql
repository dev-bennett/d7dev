-- Baseline: post-backfill notification performance from reporting layer
-- Source: fct_notification_deliveries, dim_notification_content
-- Purpose: Establish corrected KPIs/benchmarks for LookML dashboard validation
-- Author: d7admin
-- Date: 2026-04-02


--qa  Data shape & time range
SELECT
    COUNT(*) AS total_deliveries
    , COUNT(DISTINCT user_id) AS distinct_users
    , COUNT(DISTINCT cms_entry_id) AS distinct_notifications
    , MIN(created_at)::DATE AS earliest_delivery
    , MAX(created_at)::DATE AS latest_delivery
    , DATEDIFF('day', MIN(created_at), MAX(created_at)) AS date_range_days
FROM soundstripe_prod.marketing.fct_notification_deliveries
;


--qb  Deliveries by notification type
SELECT
    COALESCE(notification_type, '(unmatched)') AS notification_type
    , COALESCE(notification_type_name, '(unmatched)') AS notification_type_name
    , COUNT(*) AS delivery_count
    , ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM soundstripe_prod.marketing.fct_notification_deliveries
GROUP BY 1, 2
ORDER BY delivery_count DESC
;


--qc  Read rates by notification type
SELECT
    COALESCE(notification_type, '(unmatched)') AS notification_type
    , COUNT(*) AS total_deliveries
    , SUM(CASE WHEN is_read THEN 1 ELSE 0 END) AS read_count
    , SUM(CASE WHEN NOT is_read THEN 1 ELSE 0 END) AS unread_count
    , ROUND(100.0 * SUM(CASE WHEN is_read THEN 1 ELSE 0 END) / COUNT(*), 2) AS read_rate_pct
FROM soundstripe_prod.marketing.fct_notification_deliveries
GROUP BY 1
ORDER BY total_deliveries DESC
;


--qd  Time-to-read distribution
SELECT
    CASE
        WHEN hours_to_read IS NULL THEN 'unread'
        WHEN hours_to_read < 1 THEN '< 1 hour'
        WHEN hours_to_read < 6 THEN '1-6 hours'
        WHEN hours_to_read < 24 THEN '6-24 hours'
        WHEN hours_to_read < 72 THEN '1-3 days'
        WHEN hours_to_read < 168 THEN '3-7 days'
        ELSE '7+ days'
    END AS time_to_read_bucket
    , COUNT(*) AS delivery_count
    , ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 2) AS pct_of_total
FROM soundstripe_prod.marketing.fct_notification_deliveries
GROUP BY 1
ORDER BY
    CASE time_to_read_bucket
        WHEN 'unread' THEN 0
        WHEN '< 1 hour' THEN 1
        WHEN '1-6 hours' THEN 2
        WHEN '6-24 hours' THEN 3
        WHEN '1-3 days' THEN 4
        WHEN '3-7 days' THEN 5
        WHEN '7+ days' THEN 6
    END
;


--qe  Delivery volume over time (monthly by type)
SELECT
    DATE_TRUNC('month', created_at)::DATE AS delivery_month
    , COALESCE(notification_type, '(unmatched)') AS notification_type
    , COUNT(*) AS delivery_count
FROM soundstripe_prod.marketing.fct_notification_deliveries
GROUP BY 1, 2
ORDER BY 1, 2
;


--qf  Read rate over time (monthly by type)
SELECT
    DATE_TRUNC('month', created_at)::DATE AS delivery_month
    , COALESCE(notification_type, '(unmatched)') AS notification_type
    , COUNT(*) AS total_deliveries
    , SUM(CASE WHEN is_read THEN 1 ELSE 0 END) AS read_count
    , ROUND(100.0 * SUM(CASE WHEN is_read THEN 1 ELSE 0 END) / COUNT(*), 2) AS read_rate_pct
FROM soundstripe_prod.marketing.fct_notification_deliveries
GROUP BY 1, 2
ORDER BY 1, 2
;


--qg  Top 20 notifications by volume with read rate
SELECT
    f.cms_entry_id
    , f.notification_type
    , f.title
    , f.tag
    , COUNT(*) AS delivery_count
    , SUM(CASE WHEN f.is_read THEN 1 ELSE 0 END) AS read_count
    , ROUND(100.0 * SUM(CASE WHEN f.is_read THEN 1 ELSE 0 END) / COUNT(*), 2) AS read_rate_pct
    , ROUND(AVG(CASE WHEN f.is_read THEN f.hours_to_read END), 1) AS avg_hours_to_read
FROM soundstripe_prod.marketing.fct_notification_deliveries AS f
WHERE f.notification_type IS NOT NULL
GROUP BY 1, 2, 3, 4
ORDER BY delivery_count DESC
LIMIT 20
;


--qh  Tag distribution with read rates
SELECT
    COALESCE(tag, '(no tag)') AS tag
    , notification_type
    , COUNT(*) AS delivery_count
    , SUM(CASE WHEN is_read THEN 1 ELSE 0 END) AS read_count
    , ROUND(100.0 * SUM(CASE WHEN is_read THEN 1 ELSE 0 END) / COUNT(*), 2) AS read_rate_pct
FROM soundstripe_prod.marketing.fct_notification_deliveries
WHERE notification_type IS NOT NULL
GROUP BY 1, 2
ORDER BY delivery_count DESC
;


--qi  User distribution (notifications per user histogram)
SELECT
    CASE
        WHEN notification_count = 1 THEN '1'
        WHEN notification_count BETWEEN 2 AND 5 THEN '2-5'
        WHEN notification_count BETWEEN 6 AND 10 THEN '6-10'
        WHEN notification_count BETWEEN 11 AND 25 THEN '11-25'
        WHEN notification_count BETWEEN 26 AND 50 THEN '26-50'
        ELSE '50+'
    END AS notifications_per_user_bucket
    , COUNT(*) AS user_count
    , SUM(notification_count) AS total_deliveries_in_bucket
FROM (
    SELECT
        user_id
        , COUNT(*) AS notification_count
    FROM soundstripe_prod.marketing.fct_notification_deliveries
    GROUP BY 1
)
GROUP BY 1
ORDER BY
    CASE notifications_per_user_bucket
        WHEN '1' THEN 1
        WHEN '2-5' THEN 2
        WHEN '6-10' THEN 3
        WHEN '11-25' THEN 4
        WHEN '26-50' THEN 5
        WHEN '50+' THEN 6
    END
;


--qj  Content dimension summary
SELECT
    notification_type
    , COUNT(*) AS total_entries
    , SUM(CASE WHEN published THEN 1 ELSE 0 END) AS published_entries
    , SUM(CASE WHEN has_url THEN 1 ELSE 0 END) AS entries_with_url
    , COUNT(DISTINCT tag) AS distinct_tags
FROM soundstripe_prod.marketing.dim_notification_content
GROUP BY 1
ORDER BY total_entries DESC
;
