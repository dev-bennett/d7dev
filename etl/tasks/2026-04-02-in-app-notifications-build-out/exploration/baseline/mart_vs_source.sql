-- Diagnostic: compare mart vs raw source read counts
-- Purpose: Identify why dbt full-refresh isn't reflecting source backfill
-- Author: d7admin
-- Date: 2026-04-02


--qa  Mart vs source for Nov 2025+ automated
SELECT
    'mart' AS data_source
    , COUNT(*) AS total
    , SUM(CASE WHEN is_read THEN 1 ELSE 0 END) AS reads
FROM soundstripe_prod.marketing.fct_notification_deliveries
WHERE notification_type = 'automatedNotification'
    AND created_at >= '2025-11-01'

UNION ALL

SELECT
    'raw_source' AS data_source
    , COUNT(*) AS total
    , SUM(CASE WHEN un.read_at IS NOT NULL THEN 1 ELSE 0 END) AS reads
FROM pc_stitch_db.soundstripe.user_notifications AS un
INNER JOIN pc_stitch_db.soundstripe.cms_entries AS ce
    ON un.cms_entry_id = ce.id
INNER JOIN pc_stitch_db.soundstripe.cms_content_types AS ct
    ON ce.content_type_id = ct.id
WHERE ct.identifier = 'automatedNotification'
    AND un.created_at >= '2025-11-01'
;


--qb  Check what schema/table the staging view actually resolves to
SELECT *
FROM soundstripe_prod.staging.stg_user_notifications
WHERE created_at >= '2025-11-01'
    AND is_read = TRUE
LIMIT 10
;


--qc  Check the dbt target schema -- is fct_notification_deliveries where we think it is?
SELECT
    table_catalog
    , table_schema
    , table_name
    , table_type
    , last_altered
FROM soundstripe_prod.information_schema.tables
WHERE table_name ILIKE '%notification%'
ORDER BY table_schema, table_name
;
