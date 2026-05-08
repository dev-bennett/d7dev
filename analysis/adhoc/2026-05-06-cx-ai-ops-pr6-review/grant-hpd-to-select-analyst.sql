-- Grant SELECT_ANALYST access to HUBSPOT_PLATFORM_DATA so Danielle can use it
-- as her default DB for HubSpot CX/AI-Ops research.
--
-- Run from ACCOUNTADMIN (web UI). HPD is an IMPORTED database (HubSpot Data Share —
-- the V2_LIVE/V2_DAILY/PUBLIC layout plus the DATA_SHARE_STATUS table is the tell).
-- For shared databases, per-object GRANTs are rejected by Snowflake:
--   "Granting individual privileges on imported database is not allowed.
--    Use 'GRANT IMPORTED PRIVILEGES' instead."
-- IMPORTED PRIVILEGES is all-or-nothing — SELECT_ANALYST will see the entire share
-- (V2_DAILY + V2_LIVE + PUBLIC). The rules doc still steers her to V2_DAILY only.
--
-- Date: 2026-05-06
-- Why: SoundstripeEngineering/cx-ai-ops#6 — SNOWFLAKE_RULES.md will route HPD as
-- the default for HubSpot event-grain analysis. SELECT_ANALYST currently has
-- zero visibility (verified via snowflake.account_usage.grants_to_roles).

USE ROLE ACCOUNTADMIN;

GRANT IMPORTED PRIVILEGES ON DATABASE HUBSPOT_PLATFORM_DATA TO ROLE SELECT_ANALYST;

-- Verification — should return 784 tables in V2_DAILY
SELECT COUNT(*) AS table_count
FROM HUBSPOT_PLATFORM_DATA.INFORMATION_SCHEMA.TABLES
WHERE table_schema = 'V2_DAILY';
