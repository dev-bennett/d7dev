WITH subscription_periods AS (select
        *
        ,first_value(start_date) over(partition by soundstripe_user_id order by start_date asc)::date as first_sub_date
      from soundstripe_prod.core.subscription_periods
  )
SELECT
    (TO_CHAR(TO_DATE(date_trunc('week', fct_sessions.session_started_at) ), 'YYYY-MM-DD')) AS "fct_sessions.dynamic_session_started",
    div0(( ((COALESCE(CAST( ( SUM(DISTINCT (CAST(FLOOR(COALESCE(fct_sessions."MARKET_PURCHASE_AMOUNT" ,0)*(1000000*1.0)) AS DECIMAL(38,0))) + (TO_NUMBER(MD5(fct_sessions.session_id ), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') % 1.0e27)::NUMERIC(38, 0) ) - SUM(DISTINCT (TO_NUMBER(MD5(fct_sessions.session_id ), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') % 1.0e27)::NUMERIC(38, 0)) )  AS DOUBLE PRECISION) / CAST((1000000*1.0) AS DOUBLE PRECISION), 0)) + (COALESCE(CAST( ( SUM(DISTINCT (CAST(FLOOR(COALESCE(fct_sessions."SFX_PURCHASE_AMOUNT" ,0)*(1000000*1.0)) AS DECIMAL(38,0))) + (TO_NUMBER(MD5(fct_sessions.session_id ), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') % 1.0e27)::NUMERIC(38, 0) ) - SUM(DISTINCT (TO_NUMBER(MD5(fct_sessions.session_id ), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') % 1.0e27)::NUMERIC(38, 0)) )  AS DOUBLE PRECISION) / CAST((1000000*1.0) AS DOUBLE PRECISION), 0)) + (COALESCE(CAST( ( SUM(DISTINCT (CAST(FLOOR(COALESCE(fct_sessions."SINGLE_SONG_PURCHASE_AMOUNT" ,0)*(1000000*1.0)) AS DECIMAL(38,0))) + (TO_NUMBER(MD5(fct_sessions.session_id ), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') % 1.0e27)::NUMERIC(38, 0) ) - SUM(DISTINCT (TO_NUMBER(MD5(fct_sessions.session_id ), 'XXXXXXXXXXXXXXXXXXXXXXXXXXXXXXXX') % 1.0e27)::NUMERIC(38, 0)) )  AS DOUBLE PRECISION) / CAST((1000000*1.0) AS DOUBLE PRECISION), 0))) + (COALESCE(SUM((subscription_ltv_assumptions."LTV_1_YR_GM") ), 0)) + (((count(distinct case when fct_sessions."ENTERPRISE_FORM_SUBMISSIONS" > 0 then fct_sessions.distinct_id end)) + (count(distinct case when fct_sessions."ENTERPRISE_LANDING_FORM_SUBMISSIONS" > 0 then fct_sessions.distinct_id end)) + (count(distinct case when fct_sessions."ENTERPRISE_SCHEDULE_DEMO" > 0 then fct_sessions.distinct_id end)))  * .05 * 6000) ), ( COUNT(DISTINCT fct_sessions.session_id ) ))  AS "fct_sessions.total_revenue_per_session"
FROM soundstripe_prod."CORE".FCT_SESSIONS  AS fct_sessions
LEFT JOIN subscription_periods ON (fct_sessions."CURRENT_SUBSCRIPTION_ID") = (subscription_periods."SOUNDSTRIPE_SUBSCRIPTION_ID")
LEFT JOIN soundstripe_prod."FINANCE"."SUBSCRIPTION_LTV_ASSUMPTIONS"  AS subscription_ltv_assumptions ON subscription_periods.plan_type = translate((subscription_ltv_assumptions."PLAN"), ' ', '-')
       and (fct_sessions."CREATED_SUBSCRIPTION") > 0
       and (subscription_periods."BILLING_PERIOD_UNIT") = (subscription_ltv_assumptions."BILLING_INTERVAL")
WHERE ((( fct_sessions.session_started_at  ) >= ((DATEADD('month', -11, DATE_TRUNC('month', CURRENT_DATE())))) AND ( fct_sessions.session_started_at  ) < ((DATEADD('month', 12, DATEADD('month', -11, DATE_TRUNC('month', CURRENT_DATE()))))))) AND (case when fct_sessions.has_app_view > 0 then true else false end ) AND (case when fct_sessions."SESSION_DURATION_SECONDS" > 44
              or nvl(fct_sessions.single_song_purchase_count,0) > 0
              or nvl(fct_sessions.sfx_purchase_count, 0) > 0
              or nvl(fct_sessions.market_purchase_count, 0) > 0
              or nvl(fct_sessions.created_subscription, 0) > 0
              or nvl(fct_sessions.SIGNED_UP, 0) > 0
              or nvl(fct_sessions.ENTERPRISE_FORM_SUBMISSIONS, 0) > 0
              or nvl(fct_sessions.ENTERPRISE_LANDING_FORM_SUBMISSIONS, 0) > 0
              or nvl(fct_sessions.ENTERPRISE_SCHEDULE_DEMO, 0) > 0
              then true else false end )
GROUP BY
    (TO_DATE(date_trunc('week', fct_sessions.session_started_at) ))
ORDER BY
    1
FETCH NEXT 500 ROWS ONLY
;

-- =============================================================================
-- INVESTIGATION: weeks of 2026-03-23 and 2026-03-30 returned total_revenue_per_session = 0;
-- week of 2026-04-06 returned 1.17 (below ~1.3-1.6 baseline). Decompose the numerator
-- to isolate which component(s) collapsed, and audit the subscription LTV join + the
-- has_app_view filter as leading suspects.
-- Author: d7dev investigation, 2026-04-13
-- Dependencies: soundstripe_prod.core.fct_sessions, core.subscription_periods,
--               finance.subscription_ltv_assumptions
-- =============================================================================


-- -----------------------------------------------------------------------------
-- Query 2 -- Weekly numerator decomposition (no LTV join yet)
-- Purpose: break the Looker rate into its additive components for the last 16
-- weeks so we can see which term(s) went to zero in 03-23 / 03-30 / 04-06.
-- Filter mirrors the original: has_app_view > 0 AND engaged-session OR clause.
-- No rates computed here -- raw sums only; divide downstream if needed.
-- -----------------------------------------------------------------------------
SELECT
    TO_DATE(DATE_TRUNC('week', fs.session_started_at))                                   AS week_start
    , COUNT(DISTINCT fs.session_id)                                                       AS engaged_sessions
    , COUNT(DISTINCT fs.distinct_id)                                                      AS engaged_distinct_ids
    , SUM(COALESCE(fs.market_purchase_amount, 0))                                         AS sum_market_rev
    , SUM(COALESCE(fs.sfx_purchase_amount, 0))                                            AS sum_sfx_rev
    , SUM(COALESCE(fs.single_song_purchase_amount, 0))                                    AS sum_single_song_rev
    , COUNT(DISTINCT CASE WHEN fs.market_purchase_count > 0 THEN fs.session_id END)       AS sessions_with_market_purchase
    , COUNT(DISTINCT CASE WHEN fs.sfx_purchase_count > 0 THEN fs.session_id END)          AS sessions_with_sfx_purchase
    , COUNT(DISTINCT CASE WHEN fs.single_song_purchase_count > 0 THEN fs.session_id END)  AS sessions_with_single_song_purchase
    , SUM(fs.created_subscription)                                                        AS sum_created_subscription
    , COUNT(DISTINCT CASE WHEN fs.created_subscription > 0 THEN fs.session_id END)        AS sessions_with_created_subscription
    , COUNT(DISTINCT CASE WHEN fs.enterprise_form_submissions > 0 THEN fs.distinct_id END)         AS ent_form_submitters
    , COUNT(DISTINCT CASE WHEN fs.enterprise_landing_form_submissions > 0 THEN fs.distinct_id END) AS ent_landing_submitters
    , COUNT(DISTINCT CASE WHEN fs.enterprise_schedule_demo > 0 THEN fs.distinct_id END)            AS ent_demo_submitters
FROM soundstripe_prod.core.fct_sessions AS fs
WHERE fs.session_started_at >= DATEADD('week', -16, DATE_TRUNC('week', CURRENT_DATE()))
  AND fs.session_started_at <  DATE_TRUNC('week', CURRENT_DATE())
  AND fs.has_app_view > 0
  AND (
         fs.session_duration_seconds > 44
      OR NVL(fs.single_song_purchase_count, 0) > 0
      OR NVL(fs.sfx_purchase_count, 0) > 0
      OR NVL(fs.market_purchase_count, 0) > 0
      OR NVL(fs.created_subscription, 0) > 0
      OR NVL(fs.signed_up, 0) > 0
      OR NVL(fs.enterprise_form_submissions, 0) > 0
      OR NVL(fs.enterprise_landing_form_submissions, 0) > 0
      OR NVL(fs.enterprise_schedule_demo, 0) > 0
  )
GROUP BY 1
ORDER BY 1
;


-- -----------------------------------------------------------------------------
-- Query 3 -- Has-app-view filter audit (leading hypothesis)
-- Purpose: check whether monetized sessions are still being tagged with
-- has_app_view > 0. If the domain consolidation (www/app -> soundstripe.com via
-- Fastly, launched March 2026) broke app-view classification, monetized sessions
-- would fall out of the numerator while duration-only engaged sessions remain.
-- Counts monetized sessions by week, split on has_app_view, has_www_view, and
-- neither. Also surfaces landing_page_host distribution for monetized sessions.
-- -----------------------------------------------------------------------------
SELECT
    TO_DATE(DATE_TRUNC('week', fs.session_started_at))                                           AS week_start
    , fs.landing_page_host
    , COUNT(DISTINCT fs.session_id)                                                               AS monetized_sessions
    , COUNT(DISTINCT CASE WHEN fs.has_app_view > 0 THEN fs.session_id END)                        AS with_has_app_view
    , COUNT(DISTINCT CASE WHEN fs.has_www_view > 0 THEN fs.session_id END)                        AS with_has_www_view
    , COUNT(DISTINCT CASE WHEN NVL(fs.has_app_view,0) = 0 AND NVL(fs.has_www_view,0) = 0
                          THEN fs.session_id END)                                                  AS with_neither_view_flag
    , SUM(COALESCE(fs.market_purchase_amount, 0)
        + COALESCE(fs.sfx_purchase_amount, 0)
        + COALESCE(fs.single_song_purchase_amount, 0))                                            AS sum_purchase_rev
FROM soundstripe_prod.core.fct_sessions AS fs
WHERE fs.session_started_at >= DATEADD('week', -16, DATE_TRUNC('week', CURRENT_DATE()))
  AND fs.session_started_at <  DATE_TRUNC('week', CURRENT_DATE())
  AND (
         NVL(fs.market_purchase_count, 0) > 0
      OR NVL(fs.sfx_purchase_count, 0) > 0
      OR NVL(fs.single_song_purchase_count, 0) > 0
      OR NVL(fs.created_subscription, 0) > 0
      OR NVL(fs.enterprise_form_submissions, 0) > 0
      OR NVL(fs.enterprise_landing_form_submissions, 0) > 0
      OR NVL(fs.enterprise_schedule_demo, 0) > 0
  )
GROUP BY 1, 2
ORDER BY 1, monetized_sessions DESC
;


-- -----------------------------------------------------------------------------
-- Query 4 -- Subscription LTV join audit by week
-- Purpose: for sessions with created_subscription > 0, audit the join chain
-- fct_sessions -> subscription_periods -> subscription_ltv_assumptions. Counts
-- sessions that match each join step and sums the resulting LTV. Helps rule in
-- or out the LTV join as a cause for the zero weeks.
-- -----------------------------------------------------------------------------
WITH subscription_periods AS (
    SELECT
        sp.*
        , FIRST_VALUE(sp.start_date) OVER (PARTITION BY sp.soundstripe_user_id ORDER BY sp.start_date ASC)::DATE AS first_sub_date
    FROM soundstripe_prod.core.subscription_periods AS sp
)
SELECT
    TO_DATE(DATE_TRUNC('week', fs.session_started_at))                                      AS week_start
    , COUNT(DISTINCT fs.session_id)                                                          AS sessions_with_new_sub
    , COUNT(DISTINCT CASE WHEN sp.soundstripe_subscription_id IS NOT NULL
                          THEN fs.session_id END)                                             AS matched_to_sub_period
    , COUNT(DISTINCT CASE WHEN la.plan IS NOT NULL
                          THEN fs.session_id END)                                             AS matched_to_ltv_assumption
    , SUM(COALESCE(la.ltv_1_yr_gm, 0))                                                       AS sum_ltv_1_yr_gm
    , COUNT(DISTINCT sp.plan_type)                                                           AS distinct_plan_types_observed
    , LISTAGG(DISTINCT sp.plan_type, ', ') WITHIN GROUP (ORDER BY sp.plan_type)              AS plan_types_observed
FROM soundstripe_prod.core.fct_sessions AS fs
LEFT JOIN subscription_periods AS sp
       ON fs.current_subscription_id = sp.soundstripe_subscription_id
LEFT JOIN soundstripe_prod.finance.subscription_ltv_assumptions AS la
       ON sp.plan_type = TRANSLATE(la.plan, ' ', '-')
      AND fs.created_subscription > 0
      AND sp.billing_period_unit = la.billing_interval
WHERE fs.session_started_at >= DATEADD('week', -16, DATE_TRUNC('week', CURRENT_DATE()))
  AND fs.session_started_at <  DATE_TRUNC('week', CURRENT_DATE())
  AND fs.created_subscription > 0
GROUP BY 1
ORDER BY 1
;

select *
from MANUAL_UPLOADS.public.cue_sheets
order by upload_date desc;

SELECT
    (TO_CHAR(TO_DATE(date_trunc('week', fct_sessions.session_started_at) ), 'YYYY-MM-DD')) AS "fct_sessions.dynamic_session_started",
    div0(( (count(distinct case when fct_sessions."ENTERPRISE_FORM_SUBMISSIONS" > 0 then fct_sessions.distinct_id end)) + (count(distinct case when fct_sessions."ENTERPRISE_LANDING_FORM_SUBMISSIONS" > 0 then fct_sessions.distinct_id end)) + (count(distinct case when fct_sessions."ENTERPRISE_SCHEDULE_DEMO" > 0 then fct_sessions.distinct_id end))  ), ( COUNT(DISTINCT fct_sessions.session_id ) ))  AS "fct_sessions.mqls_per_session",
    ( (count(distinct case when fct_sessions."ENTERPRISE_FORM_SUBMISSIONS" > 0 then fct_sessions.distinct_id end)) + (count(distinct case when fct_sessions."ENTERPRISE_LANDING_FORM_SUBMISSIONS" > 0 then fct_sessions.distinct_id end)) + (count(distinct case when fct_sessions."ENTERPRISE_SCHEDULE_DEMO" > 0 then fct_sessions.distinct_id end))  ) as mqls,
    ( COUNT(DISTINCT fct_sessions.session_id ) ) as sessions
FROM soundstripe_prod."CORE".FCT_SESSIONS  AS fct_sessions
WHERE ((( fct_sessions.session_started_at  ) >= ((DATEADD('month', -11, DATE_TRUNC('month', CURRENT_DATE())))) AND ( fct_sessions.session_started_at  ) < ((DATEADD('month', 12, DATEADD('month', -11, DATE_TRUNC('month', CURRENT_DATE())))))))
GROUP BY
    (TO_DATE(date_trunc('week', fct_sessions.session_started_at) ))
ORDER BY
    1