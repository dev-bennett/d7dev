-- ============================================================================
-- q14 — Enterprise sub roster, May 2024 - Apr 2026 analysis window
-- ============================================================================
-- Author: Devon Bennett
-- Date:   2026-04-30
--
-- Purpose
--   List every Enterprise subscription in the 24-month product-KPIs analysis
--   window with identifying details, contract amounts, lifecycle status, and
--   realized cash revenue to-date. Used to validate the $6,000 Enterprise
--   1-yr LTV anchor against actual booked contracts before publishing the
--   +18% rev/session / -6% net revenue claims to stakeholders.
--
-- Plan classifier (mirrors console.sql q03 / followups/M6/queries.sql m6_q02)
--   Enterprise =  plan_type ILIKE 'enterprise%'
--              OR plan_type IN (
--                   'pro-microsoft_production_studios','pro-portlandjesuit',
--                   'pro-renderstudios','pro-shakr','pro-south-dakota-university',
--                   'pro-volkswagon','pro-waymark'
--                 )
--   plan_type sourced from chargebee_subscription_changes within 30d of start,
--   falling back to first invoice's plan_array (matches M6's logic exactly).
--   sp.plan_type is also exposed as a transparency column.
--
-- Schema verified via information_schema 2026-04-30:
--   subscription_periods columns confirmed; current_contract_state DOES NOT
--   exist (calibration artifact narrative was wrong on this column).
--   Active vs cancelled is derived from cancelled_at IS NOT NULL.
--
-- Expected row count
--   ~549 (216 Y1 + 333 Y2 per M6_yoy_decomposition.csv).
-- ============================================================================

WITH plan_classified AS (
    SELECT
          sp.subscription_id
        , sp.soundstripe_subscription_id
        , sp.soundstripe_user_id
        , sp.soundstripe_account_id
        , sp.customer_id
        , sp.start_date
        , sp.end_date
        , sp.cancelled_at
        , sp.current_term_start
        , sp.current_term_end
        , sp.billing_period_unit
        , sp.plan_type                                             AS sp_plan_type
        , sp.amount                                                AS contract_amount
        , sp.monthly_revenue                                       AS monthly_revenue
        , sp.monthly_amount                                        AS monthly_amount
        , sp.sticker_price
        , sp.converting_session_id
        , sp.last_channel_non_direct
        , COALESCE(csc.new_plan_type, csi.plan_array)              AS plan_raw
        , csc.new_plan_amount                                      AS change_event_plan_amount
        , CASE
              WHEN COALESCE(csc.new_plan_type, csi.plan_array) ILIKE 'enterprise%'
                  THEN 'plan_type ILIKE enterprise%'
              WHEN COALESCE(csc.new_plan_type, csi.plan_array) IN (
                      'pro-microsoft_production_studios'
                    , 'pro-portlandjesuit'
                    , 'pro-renderstudios'
                    , 'pro-shakr'
                    , 'pro-south-dakota-university'
                    , 'pro-volkswagon'
                    , 'pro-waymark'
                  )
                  THEN 'named_account_list'
          END                                                      AS enterprise_classifier_source
        , ROW_NUMBER() OVER (
              PARTITION BY sp.subscription_id
              ORDER BY     csc.occurred_at DESC NULLS LAST
          )                                                        AS rn
    FROM        soundstripe_prod.core.subscription_periods                       AS sp
    LEFT JOIN   soundstripe_prod.transformations.chargebee_subscription_changes  AS csc
             ON sp.subscription_id  = csc.chargebee_subscription_id
            AND DATEDIFF('day', sp.start_date::DATE, csc.occurred_at::DATE) <= 30
    LEFT JOIN   soundstripe_prod.transformations.chargebee_subscription_invoices AS csi
             ON sp.subscription_id              = csi.subscription_id
            AND csi.subscription_invoice_number = 1
    WHERE sp.start_date >= '2024-05-01'
      AND sp.start_date <  '2026-05-01'
)

, enterprise_subs AS (
    SELECT
          subscription_id
        , soundstripe_subscription_id
        , soundstripe_user_id
        , soundstripe_account_id
        , customer_id
        , start_date
        , end_date
        , cancelled_at
        , current_term_start
        , current_term_end
        , billing_period_unit
        , sp_plan_type
        , contract_amount
        , monthly_revenue
        , monthly_amount
        , sticker_price
        , plan_raw
        , change_event_plan_amount
        , enterprise_classifier_source
        , last_channel_non_direct
        , converting_session_id
        , CASE WHEN cancelled_at IS NOT NULL THEN 'cancelled' ELSE 'active' END AS state_derived
        , CASE
              WHEN start_date >= '2024-05-01' AND start_date < '2025-05-01' THEN 'Y1'
              WHEN start_date >= '2025-05-01' AND start_date < '2026-05-01' THEN 'Y2'
          END                                                      AS year_bucket
    FROM plan_classified
    WHERE rn = 1
      AND enterprise_classifier_source IS NOT NULL
)

, realized_revenue AS (
    -- Direct from chargebee_subscription_invoices: actuals per subscription.
    -- transaction_amount_paid = real cash collected (after credits/discounts/tax).
    -- amount                 = pre-credits gross.
    SELECT
          subscription_id
        , SUM(transaction_amount_paid)                             AS total_paid_to_date
        , SUM(amount)                                              AS total_invoiced_to_date
        , COUNT(DISTINCT invoice_id)                               AS invoice_count
        , COUNT(DISTINCT CASE WHEN invoice_status = 'paid'    THEN invoice_id END) AS invoices_paid
        , COUNT(DISTINCT CASE WHEN invoice_status = 'pending' THEN invoice_id END) AS invoices_pending
        , MIN(paid_at)                                             AS first_paid_at
        , MAX(paid_at)                                             AS most_recent_paid_at
    FROM soundstripe_prod.transformations.chargebee_subscription_invoices
    GROUP BY subscription_id
)

SELECT
      es.year_bucket
    , es.subscription_id
    , es.soundstripe_subscription_id
    , es.soundstripe_user_id
    , es.soundstripe_account_id
    , es.customer_id
    , es.plan_raw
    , es.sp_plan_type
    , es.enterprise_classifier_source
    , es.billing_period_unit
    , es.contract_amount
    , es.monthly_revenue
    , es.monthly_amount
    , es.sticker_price
    , es.change_event_plan_amount
    , es.start_date
    , es.end_date
    , es.cancelled_at
    , es.current_term_start
    , es.current_term_end
    , es.state_derived
    , es.last_channel_non_direct
    , es.converting_session_id
    , rr.total_paid_to_date
    , rr.total_invoiced_to_date
    , rr.invoice_count
    , rr.invoices_paid
    , rr.invoices_pending
    , rr.first_paid_at
    , rr.most_recent_paid_at
    , DATEDIFF(
          'day'
        , es.start_date::DATE
        , COALESCE(es.cancelled_at::DATE, es.end_date::DATE, CURRENT_DATE())
      )                                                            AS days_active
    , CASE
          WHEN rr.total_paid_to_date IS NULL THEN 'no_invoices_yet'
          WHEN rr.total_paid_to_date <  1000 THEN '0_to_1k'
          WHEN rr.total_paid_to_date <  3000 THEN '1k_to_3k'
          WHEN rr.total_paid_to_date <  6000 THEN '3k_to_6k'
          WHEN rr.total_paid_to_date < 12000 THEN '6k_to_12k'
          WHEN rr.total_paid_to_date < 25000 THEN '12k_to_25k'
          ELSE '25k_plus'
      END                                                          AS realized_revenue_bucket
FROM        enterprise_subs                                        AS es
LEFT JOIN   realized_revenue                                       AS rr
         ON es.subscription_id = rr.subscription_id
ORDER BY    es.year_bucket
        ,   es.start_date
        ,   es.subscription_id
;

-- ============================================================================
-- POST-EXECUTION CHECKS
-- ============================================================================
--   1. Row count = 216 Y1 + 333 Y2 = 549? If not, classifier drifted vs M6.
--
--   2. Median total_paid_to_date for Y1 cohort (start_date 13-24mo ago,
--      sufficient time for 1-yr revenue to materialize) — compare to $6,000.
--
--   3. Distribution of realized_revenue_bucket by year_bucket — what fraction
--      of Y1 Enterprise subs cleared $6k? what fraction stayed below $1k?
--
--   4. billing_period_unit distribution. Yearly should dominate Enterprise;
--      monthly Enterprise contracts at typical $200-400/mo never reach $6k 1-yr.
--
--   5. Compare contract_amount, monthly_revenue, change_event_plan_amount —
--      these are the contract sticker amounts. Their distribution gives the
--      cleanest empirical anchor for what an Enterprise "1-yr value" should be.
--
--   6. state_derived counts (active vs cancelled) by year_bucket — high cancel
--      rate in Y1 cohort undercuts the 1-yr LTV anchor for that cohort.
-- ============================================================================
