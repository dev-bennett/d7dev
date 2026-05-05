-- =====================================================================
-- q01: Original Looker tile SQL (verbatim, as pasted)
-- Source: Looker — fct_kpis_enterprise.closed_won_arr, last 12 months
-- =====================================================================
SELECT
    (TO_CHAR(TO_DATE(fct_kpis_enterprise."EVENT_MONTH" ), 'YYYY-MM-DD')) AS "fct_kpis_enterprise.event_month",
    COALESCE(SUM(fct_kpis_enterprise.won_deal_amount ), 0) AS "fct_kpis_enterprise.closed_won_arr",
    COALESCE(SUM(dim_monthly_forecast."FORECAST_ENTERPRISE_BOOKINGS" ), 0) AS "dim_monthly_forecast.forecast_enterprise_bookings"
FROM "CORE"."FCT_KPIS_ENTERPRISE"  AS fct_kpis_enterprise
LEFT JOIN "FINANCE"."DIM_MONTHLY_FORECAST"  AS dim_monthly_forecast ON (TO_CHAR(TO_DATE(dim_monthly_forecast."EVENT_MONTH" ), 'YYYY-MM-DD')) = (TO_CHAR(TO_DATE(fct_kpis_enterprise."EVENT_MONTH" ), 'YYYY-MM-DD'))
      and (dim_monthly_forecast."FORECAST_NAME") = '2026 Budget'
WHERE ((( fct_kpis_enterprise."EVENT_MONTH"  ) >= ((DATEADD('month', -11, DATE_TRUNC('month', CURRENT_DATE())))) AND ( fct_kpis_enterprise."EVENT_MONTH"  ) < ((DATEADD('month', 12, DATEADD('month', -11, DATE_TRUNC('month', CURRENT_DATE())))))))
GROUP BY
    (TO_DATE(fct_kpis_enterprise."EVENT_MONTH" ))
ORDER BY
    1
;


-- =====================================================================
-- q02: Direct SUM(won_deal_amount) for April 2026 — sanity check on q01
-- Confirms the April row in q01 matches the underlying mart directly.
-- =====================================================================
SELECT
    event_month
    , won_deal_amount
FROM soundstripe_prod.core.fct_kpis_enterprise
WHERE event_month = '2026-04-01'
;


-- =====================================================================
-- q03: Deal-level pull, April 2026 close dates, ALL filters relaxed
-- Source: finance.dim_enterprise_deals (calibrated 2026-05-04, 6,706 rows)
-- Purpose: classify each tracker row by which model filter excludes it
--          (pipeline_name / deal_grouping / stage_category) or whether
--          it's a value mismatch / not-found.
-- No date predicate cap risk: April 2026 close-date population is small
-- and bounded by closedate range; expected ~30-50 rows.
-- =====================================================================
SELECT
    dealid
    , dealname
    , companyid
    , amount
    , closedate
    , pipeline_name
    , deal_grouping
    , stage_category
    , stage_name
    , CASE
        WHEN pipeline_name IN ('Enterprise Pipeline', 'Renewal Pipeline')
            AND deal_grouping ILIKE '%new deal'
            AND stage_category = 'won'
        THEN TRUE ELSE FALSE
      END AS in_won_deal_amount
FROM soundstripe_prod.finance.dim_enterprise_deals
WHERE closedate >= '2026-04-01'
  AND closedate < '2026-05-01'
ORDER BY closedate, dealname
;