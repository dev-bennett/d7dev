-- =====================================================================
-- verify/sanity_checks.sql
-- Run AFTER the modified fct_enterprise_user_activity_for_scoring lands
-- in soundstripe_dev (dev build) or soundstripe_prod (post-merge).
-- Pre-merge baseline (run 2026-05-05 against the proposed CTE logic):
--   distinct companyids:     483
--   total event rows:        371,595
--   distinct chargebee customers: 489
--   distinct users:          1,076
-- =====================================================================

-- =====================================================================
-- v01: row count + grain integrity
-- Confirms one row per companyid (sync requires unique upsert key).
-- =====================================================================
SELECT
    COUNT(*) AS rows_total
  , COUNT(DISTINCT companyid) AS distinct_companyids
  , COUNT(*) - COUNT(DISTINCT companyid) AS dup_companyid_rows
  , COUNT_IF(companyid IS NULL) AS null_companyid_rows
FROM {{database}}.{{schema}}.fct_enterprise_user_activity_for_scoring;
-- Expect: rows_total = distinct_companyids; dup_companyid_rows = 0; null_companyid_rows = 0.

-- =====================================================================
-- v02: relationships test (companyid → dim_enterprise_deals)
-- Every output row's companyid should match a deal.
-- =====================================================================
SELECT
    COUNT(*) AS unmatched_rows
FROM {{database}}.{{schema}}.fct_enterprise_user_activity_for_scoring f
LEFT JOIN {{database}}.finance.dim_enterprise_deals d
    ON f.companyid = d.companyid
WHERE d.companyid IS NULL;
-- Expect: 0.

-- =====================================================================
-- v03: fan-out audit — multiple chargebee customers per company?
-- chargebee_customer_count > 1 means engagement counters aggregate across
-- multiple Chargebee customers on the same HubSpot company. Investigate
-- before activating sync if any company shows > 2.
-- =====================================================================
SELECT
    chargebee_customer_count
  , COUNT(*) AS company_count
FROM {{database}}.{{schema}}.fct_enterprise_user_activity_for_scoring
GROUP BY chargebee_customer_count
ORDER BY chargebee_customer_count;
-- Expect: most rows at chargebee_customer_count = 1; a few at 2+. The
-- broadcast-to-all-companies fan-out (max 17 from pre-merge audit) is the
-- inverse — same Chargebee customer mapped to many companies — and is
-- baked in via the deal_company_lookup deliberately.

-- =====================================================================
-- v04: coverage vs eligible enterprise customers
-- Sanity: how many Chargebee enterprise customers are in subscription_periods,
-- vs how many landed in the model? Gap = enterprise customers with no
-- activity in days 1-61 OR no matching deal in dim_enterprise_deals.
-- =====================================================================
WITH eligible AS (
    SELECT COUNT(DISTINCT customer_id) AS n_eligible
    FROM {{database}}.core.subscription_periods
    WHERE plan_type = 'enterprise'
)
, in_model AS (
    SELECT SUM(chargebee_customer_count) AS n_in_model_with_dup,
           COUNT(*) AS n_companies
    FROM {{database}}.{{schema}}.fct_enterprise_user_activity_for_scoring
)
SELECT
    e.n_eligible
  , m.n_companies
  , m.n_in_model_with_dup
  , (m.n_in_model_with_dup * 100.0 / NULLIF(e.n_eligible, 0))::number(10, 1) AS coverage_pct_approx
FROM eligible e CROSS JOIN in_model m;

-- =====================================================================
-- v05: output schema check (all expected Polytomic-mapped columns present)
-- =====================================================================
SELECT column_name, data_type
FROM {{database}}.information_schema.columns
WHERE table_schema = UPPER('{{schema}}')
  AND table_name = 'FCT_ENTERPRISE_USER_ACTIVITY_FOR_SCORING'
ORDER BY ordinal_position;
-- Expect (in order):
--   companyid (NUMBER), active_users, chargebee_customer_count,
--   chargebee_subscription_count, sessions_prior_30, song_downloads_prior_30,
--   projects_created_prior_30, sessions_last_30, song_downloads_last_30,
--   projects_created_last_30
