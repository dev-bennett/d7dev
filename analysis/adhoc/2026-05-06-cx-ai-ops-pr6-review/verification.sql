-- Verification queries for grant-hpd-to-select-analyst.sql
-- Run after the GRANT script lands. Two perspectives:
--   q01 — from EMBEDDED_ANALYST (Devon's MCP role): confirm grants exist in account_usage
--   q02 — from SELECT_ANALYST (Danielle's session): confirm she can actually query HPD

-- q01: confirm grants landed in snowflake.account_usage.grants_to_roles
-- (replication lag on this view can be up to 2 hours; if empty immediately after
-- the grant, trust the live SHOW GRANTS instead — see q01b)
SELECT privilege, granted_on, name, granted_by
FROM snowflake.account_usage.grants_to_roles
WHERE grantee_name = 'SELECT_ANALYST'
  AND deleted_on IS NULL
  AND (
       (granted_on = 'DATABASE' AND name = 'HUBSPOT_PLATFORM_DATA')
    OR (granted_on = 'SCHEMA'   AND name = 'HUBSPOT_PLATFORM_DATA.V2_DAILY')
    OR (granted_on IN ('TABLE','VIEW') AND name LIKE 'HUBSPOT_PLATFORM_DATA.V2_DAILY.%')
  )
ORDER BY granted_on, name;

-- q01b: live grant check — no replication lag. Run from any role with USAGE on HPD.
SHOW GRANTS TO ROLE SELECT_ANALYST;

-- q02 (Danielle runs from her session as SELECT_ANALYST):
-- expect ~191 rows in OWNERS, no permission error.
SELECT COUNT(*) AS owners_visible_to_select_analyst
FROM HUBSPOT_PLATFORM_DATA.V2_DAILY.OWNERS;

-- q02b (Danielle): confirm she can see all 784 V2_DAILY tables
SELECT COUNT(*) AS table_count_visible_to_select_analyst
FROM HUBSPOT_PLATFORM_DATA.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'V2_DAILY';
