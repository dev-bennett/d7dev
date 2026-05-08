-- =====================================================================
-- diagnostic_queries.sql
-- Three queries to answer the foundational question:
--   1) How big is the active enterprise customer base, and how does it
--      split between Chargebee-billed and non-Chargebee?
--   2) How many HubSpot Companies does the proposed Phase A model output
--      cover, and is that consistent with (1)?
--   3) Which HubSpot custom properties are available on Company vs
--      Contact — i.e., what's the actual "missing object-specific join
--      key" Geoff referred to?
--
-- Run each query independently. Don't trust any ratio I quote —
-- compute coverage from raw counts in the output.
-- =====================================================================


-- =====================================================================
-- q01 — Enterprise customer base profile at COMPANY grain
--
-- Splits distinct HubSpot Companies in dim_enterprise_deals by:
--   - stage_category (lost / in progress / won)
--   - any_chargebee (does the company have ANY deal with a non-null
--     chargebee_customer_id, ever?)
--   - has_recurring_active (does the company have ANY deal with
--     recurring_revenue_inactive_ts IS NULL — proxy for "currently
--     billing")
-- Output is one row per (stage_category, any_chargebee,
-- has_recurring_active) cell, with distinct company count.
--
-- WHY: this is the right grain to answer "how many active enterprise
-- customers are billed via Chargebee vs not." The dim_enterprise_deals
-- row count (6,725) MIXES lost prospects, in-progress deals, and
-- renewal duplicates per customer; comparing it to subscription_periods
-- enterprise rows (1,249) is grain-mismatched arithmetic.
--
-- WHAT TO LOOK AT: the row(s) with stage_category='won' and
-- has_recurring_active=true — that's the addressable customer base.
-- The any_chargebee split inside that subset is the true split between
-- Phase A (Chargebee-bearing) and Phase B (non-Chargebee) populations.
-- =====================================================================
WITH per_company AS (
    SELECT
        companyid,
        MAX(CASE WHEN stage_category = 'won' THEN 1 ELSE 0 END) AS has_won_deal,
        MAX(CASE WHEN stage_category = 'lost' THEN 1 ELSE 0 END) AS has_lost_deal,
        MAX(CASE WHEN stage_category = 'in progress' THEN 1 ELSE 0 END) AS has_in_progress_deal,
        MAX(CASE WHEN chargebee_customer_id IS NOT NULL THEN 1 ELSE 0 END) AS any_chargebee,
        MAX(CASE WHEN recurring_revenue_inactive_ts IS NULL THEN 1 ELSE 0 END) AS has_recurring_active
    FROM soundstripe_prod.finance.dim_enterprise_deals
    WHERE companyid IS NOT NULL
    GROUP BY companyid
)
SELECT
    CASE
        WHEN has_won_deal = 1 THEN 'won'
        WHEN has_in_progress_deal = 1 THEN 'in_progress'
        WHEN has_lost_deal = 1 THEN 'lost_only'
        ELSE 'other'
    END AS top_stage_category,
    any_chargebee,
    has_recurring_active,
    COUNT(*) AS distinct_companies
FROM per_company
GROUP BY 1, 2, 3
ORDER BY 1, 2 DESC, 3 DESC;


-- =====================================================================
-- q02 — Phase A model output coverage at COMPANY grain
--
-- Runs the EXACT logic of the proposed
-- fct_enterprise_user_activity_for_scoring.sql and reports its grain +
-- coverage stats. No ratios — just counts. Compare against q01's
-- "won × any_chargebee=1 × has_recurring_active=1" cell to determine
-- the gap (if any) between eligible base and what the model produces.
--
-- WHY: tells you whether shipping Phase A (the model + Polytomic sync
-- on companyid) is worth doing for the population it actually reaches.
--
-- WHAT TO LOOK AT:
--   - distinct_companyids = N — that's the Phase A row count.
--     Compare to q01.won.any_chargebee=1.has_recurring_active=1.
--   - rows_total = same as distinct_companyids (model groups by
--     companyid). If they differ, the GROUP BY in the model is wrong.
--   - distinct_chargebee_customers ≈ distinct_companyids modulo the
--     fan-out (one customer can map to multiple companies). If it's
--     dramatically smaller, fan-out is high.
-- =====================================================================
WITH activity AS (
    SELECT
        customer_id,
        subscription_id,
        user_id,
        event,
        event_ts
    FROM soundstripe_prod.transformations.subscriber_activity
    WHERE plan_type = 'enterprise'
      AND event_ts::date BETWEEN DATEADD('days', -61, CURRENT_DATE) AND DATEADD('days', -1, CURRENT_DATE)
)
, deal_company_lookup AS (
    SELECT DISTINCT chargebee_customer_id, companyid
    FROM soundstripe_prod.finance.dim_enterprise_deals
    WHERE chargebee_customer_id IS NOT NULL AND companyid IS NOT NULL
)
, joined AS (
    SELECT d.companyid, a.customer_id, a.subscription_id, a.user_id, a.event_ts
    FROM activity a
    INNER JOIN deal_company_lookup d
        ON a.customer_id::string = d.chargebee_customer_id::string
)
, model_output AS (
    SELECT
        companyid,
        COUNT(DISTINCT user_id) AS active_users,
        COUNT(DISTINCT customer_id) AS chargebee_customers_per_company,
        COUNT(*) AS event_rows
    FROM joined
    GROUP BY companyid
)
SELECT
    COUNT(*) AS distinct_companyids,
    SUM(active_users) AS sum_active_users_naive,
    AVG(chargebee_customers_per_company)::number(10, 3) AS avg_chargebee_cust_per_company,
    MAX(chargebee_customers_per_company) AS max_chargebee_cust_per_company,
    SUM(event_rows) AS rows_total_pre_group
FROM model_output;


-- =====================================================================
-- q03 — HubSpot Companies vs Contacts: which Soundstripe-side
-- identifiers exist as columns / properties?
--
-- Confirms what's actually available as a join key on each HubSpot
-- object via dbt staging models. The "missing object-specific join key"
-- claim is: HubSpot Company has none; HubSpot Contact has
-- chargebee_customer_id and soundstripe_user_id, which is why all
-- working Polytomic syncs target Contact today.
--
-- NOTE: this lists only the staged columns, not full HubSpot custom
-- property catalog. If a property exists in HubSpot but isn't yet
-- pulled into the dbt staging model, it would not show here. If you
-- suspect a property exists, double-check Stitch raw via
-- pc_stitch_db.hubspot.companies and pc_stitch_db.hubspot.contacts
-- (the raw VARIANT 'properties' column has the full set).
--
-- WHAT TO LOOK AT: any column on hubspot_companies that holds a
-- Soundstripe-side ID (account_id, customer_id, subscription_id, etc.).
-- If none exists, Phase B will require either a new HubSpot Company
-- custom property or routing through HubSpot Contact.
-- =====================================================================
SELECT
    table_schema,
    table_name,
    column_name,
    data_type
FROM (
    SELECT 'COMPANIES' AS hs_object, table_schema, table_name, column_name, data_type
    FROM pc_stitch_db.information_schema.columns
    WHERE table_schema = 'HUBSPOT'
      AND table_name = 'COMPANIES'
      AND (column_name ILIKE '%CHARGEBEE%'
           OR column_name ILIKE '%SOUNDSTRIPE%'
           OR column_name ILIKE '%CUSTOMER%'
           OR column_name ILIKE '%SUBSCRIPTION%'
           OR column_name ILIKE '%ACCOUNT%')
    UNION ALL
    SELECT 'CONTACTS' AS hs_object, table_schema, table_name, column_name, data_type
    FROM pc_stitch_db.information_schema.columns
    WHERE table_schema = 'HUBSPOT'
      AND table_name = 'CONTACTS'
      AND (column_name ILIKE '%CHARGEBEE%'
           OR column_name ILIKE '%SOUNDSTRIPE%'
           OR column_name ILIKE '%CUSTOMER%'
           OR column_name ILIKE '%SUBSCRIPTION%'
           OR column_name ILIKE '%ACCOUNT%')
)
ORDER BY hs_object, column_name;
