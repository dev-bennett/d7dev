-- Isolate: reproduce the exact fact table SELECT to see if it returns new reads
-- Author: d7admin
-- Date: 2026-04-02


--qa  Run the fact table query directly -- does it see the reads?
SELECT
    COUNT(*) AS total
    , SUM(CASE WHEN un.is_read THEN 1 ELSE 0 END) AS reads
FROM soundstripe_prod.staging.stg_user_notifications AS un
LEFT JOIN soundstripe_prod.marketing.dim_notification_content AS nc
    ON un.cms_entry_id = nc.cms_entry_id
WHERE nc.notification_type = 'automatedNotification'
    AND un.created_at >= '2025-11-01'
;


--qb  Is Snowflake result cache masking the change?
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

SELECT
    COUNT(*) AS total
    , SUM(CASE WHEN is_read THEN 1 ELSE 0 END) AS reads
FROM soundstripe_prod.marketing.fct_notification_deliveries
WHERE notification_type = 'automatedNotification'
    AND created_at >= '2025-11-01'
;
ALTER SESSION SET USE_CACHED_RESULT = FALSE;

--qc  Check the actual table metadata -- when were rows last written?
SELECT
    COUNT(*) AS row_count
    , MIN(created_at) AS min_created
    , MAX(created_at) AS max_created
    , SUM(CASE WHEN is_read THEN 1 ELSE 0 END) AS total_reads
FROM soundstripe_prod.marketing.fct_notification_deliveries
;

SELECT CURRENT_ROLE();
SHOW TABLES LIKE '%NOTIFICATION%' IN SCHEMA SOUNDSTRIPE_PROD.MARKETING;

USE ROLE TRANSFORMER;
SELECT CURRENT_ROLE();

SHOW TABLES LIKE '%NOTIFICATION%' IN DATABASE SOUNDSTRIPE_PROD;

CREATE TABLE SOUNDSTRIPE_PROD.MARKETING.FCT_NOTIFICATION_DELIVERIES AS
  SELECT
      un.notification_delivery_id
      , un.user_id
      , un.cms_entry_id
      , nc.notification_type
      , nc.notification_type_name
      , nc.title
      , nc.message
      , nc.url
      , nc.tag
      , un.created_at
      , un.read_at
      , un.is_read
      , DATEDIFF('hour', un.created_at, un.read_at) AS hours_to_read
  FROM SOUNDSTRIPE_PROD.STAGING.STG_USER_NOTIFICATIONS AS un
  LEFT JOIN SOUNDSTRIPE_PROD.MARKETING.DIM_NOTIFICATION_CONTENT AS nc
      ON un.cms_entry_id = nc.cms_entry_id