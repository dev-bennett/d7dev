-- Verify SQL — Product KPIs LTV by Cohort
-- Author: Devon Bennett
-- Date: 2026-04-25
-- Purpose: Sanity-check the new fct_ltv_subscription_projections LookML view
--   before promoting to the Looker repo. Three labeled queries.
--
-- Pre-step: /calibrate finance.fct_ltv_subscription_projections
--   (first-touch rule per .claude/rules/snowflake-mcp.md)
--
-- Dependencies:
--   - soundstripe_prod.finance.fct_ltv_subscription_projections (source)
--   - soundstripe_prod.core.fct_kpis_self_service (reconciliation reference)


-- ============================================================================
-- q1: Cohort row counts
-- ----------------------------------------------------------------------------
-- Goal: confirm every plan_type × billing_period_unit cell has subscriptions.
-- Pass: every expected combo present (business/creator/pro/pro-plus × month/quarter/year,
--   plus twitch-pro × month/year). Flags any empty cells or unexpected enum values.
-- ============================================================================

SELECT
      plan_type
    , billing_period_unit
    , COUNT(DISTINCT subscription_id)                               AS subscription_count
    , COUNT(*)                                                      AS row_count
    , MIN(sub_start_date)                                           AS earliest_sub_start
    , MAX(sub_start_date)                                           AS latest_sub_start
FROM soundstripe_prod.finance.fct_ltv_subscription_projections
GROUP BY 1, 2
ORDER BY subscription_count DESC
;


-- ============================================================================
-- q2: Per-cohort 1-yr LTV sanity check vs subscription_ltv_assumptions
-- ----------------------------------------------------------------------------
-- Goal: confirm the new measure's per-cohort `ltv_1_yr_per_subscription`
--   is in the expected order of magnitude.
--
-- Pass criterion: Annual cohorts should land at ratio ~1.0-1.6 vs ltv_1_yr_gm
--   (gross revenue > gross margin). Monthly/quarterly cohorts may land BELOW
--   1.0 vs ltv_1_yr_gm because the assumptions table uses a forward-looking
--   expected-value methodology (with modeled retention curves) while this
--   measure is realized revenue (subs that churn within 12 months stop
--   accruing both invoice and projection rows). Different methodologies.
--
-- Investigate if: any cohort returns NULL/0 LTV; or annual cohort ratio < 1.0;
--   or any cohort > 3x the GM value; or business cohort yields a per-sub LTV
--   wildly out of family with the others. q1 already verifies cell coverage.
--
-- Earlier draft attempted reconciliation vs fct_kpis_self_service.ltv_1_yr.
-- That table is event-month-grain (LTV tabulated by reporting month) while
-- the new measure is cohort-start-month-grain — the two are not directly
-- comparable. Removed.
--
-- Scope: mature cohorts only — sub_start_date 13-24 months ago. Within this
--   window, all 12 first-year months are actual invoice rows (not projections).
-- ============================================================================

WITH window_bounds AS (
    SELECT
          DATEADD('month', -24, CURRENT_DATE)                       AS cohort_start_lower
        , DATEADD('month', -13, CURRENT_DATE)                       AS cohort_start_upper
)

, per_cohort AS (
    SELECT
          p.plan_type
        , p.billing_period_unit
        , COUNT(DISTINCT p.subscription_id)                         AS subscription_count
        , SUM(p.total_amount_paid)                                  AS ltv_1_yr_total
        , SUM(p.total_amount_paid)
            / NULLIF(COUNT(DISTINCT p.subscription_id), 0)          AS ltv_1_yr_per_subscription
    FROM soundstripe_prod.finance.fct_ltv_subscription_projections p
        CROSS JOIN window_bounds w
    WHERE p.plan_type IN ('business', 'creator', 'pro', 'pro-plus')
      AND p.months_into_subscription <= 12
      AND p.sub_start_date >= w.cohort_start_lower
      AND p.sub_start_date <  w.cohort_start_upper
    GROUP BY 1, 2
)

SELECT
      c.plan_type
    , c.billing_period_unit
    , c.subscription_count
    , c.ltv_1_yr_total
    , c.ltv_1_yr_per_subscription
    , a.ltv_1_yr_gm                                                 AS reference_ltv_1_yr_gm
    , (c.ltv_1_yr_per_subscription / NULLIF(a.ltv_1_yr_gm, 0))      AS gross_to_gm_ratio
FROM per_cohort c
    LEFT JOIN soundstripe_prod.finance.subscription_ltv_assumptions a
        ON a.plan = c.plan_type
       AND a.billing_interval = c.billing_period_unit
ORDER BY c.subscription_count DESC
;


-- ============================================================================
-- q3: sub_start_date bounds + value_type distribution
-- ----------------------------------------------------------------------------
-- Goal: confirm the time series is bounded sensibly; no future dates, no NULLs;
--   and confirm the actual-vs-projected mix per cohort age.
-- Pass: MIN(sub_start_date) is a sensible historical date, MAX is recent (not
--   in the future). Projection rows concentrated in cohorts <12 months old.
-- ============================================================================

SELECT
      value_type
    , COUNT(*)                                                      AS row_count
    , COUNT(DISTINCT subscription_id)                               AS subscription_count
    , MIN(sub_start_date)                                           AS earliest_sub_start
    , MAX(sub_start_date)                                           AS latest_sub_start
    , SUM(CASE WHEN months_into_subscription <= 12 THEN 1 ELSE 0 END) AS rows_within_first_12_months
    , SUM(CASE WHEN months_into_subscription > 12 THEN 1 ELSE 0 END)  AS rows_beyond_first_12_months
FROM soundstripe_prod.finance.fct_ltv_subscription_projections
GROUP BY 1
ORDER BY 1
;
