-- Verification: confirm Stitch re-replication captured read_at updates
-- Author: d7admin
-- Date: 2026-04-02
-- Run against raw source to validate before triggering dbt rebuild


--qa  Monthly read rate from source (Nov 2025+ should now show 5-15% for automated/targeted)
SELECT
    DATE_TRUNC('month', un.created_at)::DATE AS delivery_month
    , ct.identifier AS notification_type
    , COUNT(*) AS total_deliveries
    , SUM(CASE WHEN un.read_at IS NOT NULL THEN 1 ELSE 0 END) AS has_read_at
    , ROUND(100.0 * SUM(CASE WHEN un.read_at IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS read_rate_pct
FROM pc_stitch_db.soundstripe.user_notifications AS un
INNER JOIN pc_stitch_db.soundstripe.cms_entries AS ce
    ON un.cms_entry_id = ce.id
INNER JOIN pc_stitch_db.soundstripe.cms_content_types AS ct
    ON ce.content_type_id = ct.id
WHERE ct.identifier IN ('automatedNotification', 'targetedNotification')
    AND un.created_at >= '2025-09-01'
GROUP BY 1, 2
ORDER BY 1, 2
;


--qb  Before vs after comparison (same query as original diagnostic qb)
SELECT
    CASE
        WHEN un.created_at < '2025-11-01' THEN 'pre-Nov 2025'
        ELSE 'Nov 2025+'
    END AS period
    , ct.identifier AS notification_type
    , COUNT(*) AS total_deliveries
    , SUM(CASE WHEN un.read_at IS NOT NULL THEN 1 ELSE 0 END) AS has_read_at
    , ROUND(100.0 * SUM(CASE WHEN un.read_at IS NOT NULL THEN 1 ELSE 0 END) / COUNT(*), 2) AS pct_with_read_at
FROM pc_stitch_db.soundstripe.user_notifications AS un
INNER JOIN pc_stitch_db.soundstripe.cms_entries AS ce
    ON un.cms_entry_id = ce.id
INNER JOIN pc_stitch_db.soundstripe.cms_content_types AS ct
    ON ce.content_type_id = ct.id
WHERE ct.identifier IN ('automatedNotification', 'targetedNotification')
GROUP BY 1, 2
ORDER BY 1, 2
;
