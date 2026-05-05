-- Product KPIs 24-Month Trend Review — console.sql
-- Author: Devon Bennett (analyst)
-- Date: 2026-04-28
-- Stakeholder: Meredith Knott (Product)
--
-- Window: 2024-05-01 through 2026-05-01 (24 months, monthly grain)
-- Source dashboard: Looker Dashboard 19 — Product KPIs
-- LookML export: ./product_kpis.lkml
--
-- Tile measure SQL traced from:
--   context/lookml/views/Mixpanel/fct_sessions.view.lkml
--   context/lookml/views/Mixpanel/fct_subscriber_activity_mixpanel.view.lkml
--   context/lookml/views/_Custom_Views/subscription_changes_retention.view.lkml
--
-- Calibration prerequisites (verify before MCP execution):
--   core.fct_sessions — current (2026-04-24-r2)
--   core.dim_daily_kpis — current (2026-04-24)
--   core.fct_sessions_attribution — current
--   core.fct_subscriber_activity_mixpanel — NEEDS CALIBRATION (fact-grain naming, first-touch rule applies)
--   transformations.chargebee_subscription_changes — NEEDS CALIBRATION (raw transformation, first-touch)
--   finance.subscription_ltv_assumptions — small dim, soft-warn at most
--
-- §13 query efficiency: q01-q03 are consolidated by source explore. Each query produces one row
-- per (month, tile_id) so the three-query result set covers all 14 tiles in one round-trip per source.
-- Per `feedback_one_sql_file_per_query_set`: one file, labeled q## blocks, UNION-friendly schema.

------------------------------------------------------------------------
-- q01 — fct_sessions tiles (1, 3, 4, 5, 6, 11, 14) — 24m monthly series
------------------------------------------------------------------------
-- Tiles covered:
--   #1  total_revenue_per_session (Revenue / Session, all sessions)
--   #3  total_revenue_per_session_engaged (Revenue / Engaged Session)
--   #4  overall_conversion_rate (Purchase CVR per Session)
--   #5  sign_ups_per_session (visitor numerator / session denominator — grain mismatch)
--   #6  mqls_per_session (3-component visitor numerator / session denominator)
--   #11 visitor_sign_up_cvr filtered to engaged_session_ind = 'Yes'
--   #14 placeholder (duplicate of #1)
--
-- §1 RATE blocks for each: see contract-and-rates.md
--
-- Approach: produce one row per (month) with all numerators and denominators side-by-side,
-- then derive rates downstream. This lets a single query feed multiple tile rates.
-- Grain mismatch is preserved (visitor numerators kept distinct from session denominators).
--
-- Limitations:
--   - total_revenue (tiles 1, 3, 14) requires the modeled subscription_ltv_assumptions join.
--     This query computes the components (license_revenue, subscribes, mqls) so the rate can
--     be reconstructed downstream once the LTV assumption is applied. The exact tile value
--     requires multiplying subscribes by the per-plan LTV-1yr and adding mql_value (mqls × 0.05 × 6000).

WITH session_base AS (
    SELECT
        DATE_TRUNC('month', session_started_at)::DATE                             AS month_start,
        session_id,
        distinct_id,
        engaged_session_ind                                                       AS is_engaged_yesno_dim,  -- LookML dim, not column; recompute below
        -- Recompute engaged_session_ind from columns (mirrors LookML):
        CASE WHEN session_duration_seconds > 44
              OR NVL(single_song_purchase_count, 0) > 0
              OR NVL(sfx_purchase_count, 0) > 0
              OR NVL(market_purchase_count, 0) > 0
              OR NVL(created_subscription, 0) > 0
              OR NVL(signed_up, 0) > 0
              OR NVL(enterprise_form_submissions, 0) > 0
              OR NVL(enterprise_landing_form_submissions, 0) > 0
              OR NVL(enterprise_schedule_demo, 0) > 0
             THEN 1 ELSE 0 END                                                    AS is_engaged_session,
        CASE WHEN created_subscription > 0 THEN 1 ELSE 0 END                      AS is_subscribing_session,
        CASE WHEN NVL(single_song_purchase_count, 0) > 0
              OR NVL(sfx_purchase_count, 0) > 0
              OR NVL(market_purchase_count, 0) > 0 THEN 1 ELSE 0 END              AS is_license_session,
        signed_up                                                                 AS signed_up_count,
        enterprise_form_submissions,
        enterprise_landing_form_submissions,
        enterprise_schedule_demo,
        single_song_purchase_amount,
        sfx_purchase_amount,
        market_purchase_amount,
        last_channel_non_direct,
        landing_page_host,
        country
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at >= '2024-05-01'
      AND session_started_at <  '2026-05-01'
)
SELECT
    month_start,
    -- Denominators
    COUNT(DISTINCT session_id)                                                    AS sessions_total,
    COUNT(DISTINCT CASE WHEN is_engaged_session = 1 THEN session_id END)          AS sessions_engaged,
    COUNT(DISTINCT distinct_id)                                                   AS visitors_total,
    COUNT(DISTINCT CASE WHEN is_engaged_session = 1 THEN distinct_id END)         AS visitors_engaged,

    -- Tile #4 numerator components
    COUNT(DISTINCT CASE WHEN is_subscribing_session = 1 THEN session_id END)      AS subscribing_sessions,
    COUNT(DISTINCT CASE WHEN is_license_session     = 1 THEN session_id END)      AS license_sessions,
    -- overall_conversion_rate = (subscribing_sessions + license_sessions) / sessions_total

    -- Tile #5 numerator (visitor-grain)
    COUNT(DISTINCT CASE WHEN signed_up_count > 0 THEN distinct_id END)            AS visitors_signed_up,
    -- sign_ups_per_session = visitors_signed_up / sessions_total

    -- Tile #6 numerator components (3-component visitor sum, replicating LookML quirk)
    COUNT(DISTINCT CASE WHEN enterprise_form_submissions         > 0 THEN distinct_id END) AS visitors_mql_pricing,
    COUNT(DISTINCT CASE WHEN enterprise_landing_form_submissions > 0 THEN distinct_id END) AS visitors_mql_enterprise,
    COUNT(DISTINCT CASE WHEN enterprise_schedule_demo            > 0 THEN distinct_id END) AS visitors_mql_demo,
    (COUNT(DISTINCT CASE WHEN enterprise_form_submissions         > 0 THEN distinct_id END)
   + COUNT(DISTINCT CASE WHEN enterprise_landing_form_submissions > 0 THEN distinct_id END)
   + COUNT(DISTINCT CASE WHEN enterprise_schedule_demo            > 0 THEN distinct_id END))   AS mqls_total_3component,
    -- mqls_per_session = mqls_total_3component / sessions_total

    -- Tile #11 numerator (engaged-session filtered, visitor-grain)
    COUNT(DISTINCT CASE WHEN is_engaged_session = 1 AND signed_up_count > 0 THEN distinct_id END)
                                                                                  AS engaged_visitors_signed_up,
    -- visitor_sign_up_cvr (engaged) = engaged_visitors_signed_up / engaged_unique_non_registered_visitors
    -- (the strict denominator requires a users join we elide here; visitors_engaged is a close proxy)

    -- Tile #1, #3, #14 numerator components: realized license revenue + subscribing-session count
    -- (modeled total_revenue requires subscription_ltv_assumptions join — see q04 if needed)
    SUM(NVL(single_song_purchase_amount, 0)
      + NVL(sfx_purchase_amount, 0)
      + NVL(market_purchase_amount, 0))                                           AS license_revenue,
    SUM(CASE WHEN is_engaged_session = 1
             THEN NVL(single_song_purchase_amount, 0)
                + NVL(sfx_purchase_amount, 0)
                + NVL(market_purchase_amount, 0) END)                             AS license_revenue_engaged,

    -- Channel/host context for §5 algebraic identity decomposition (used in BUILD-C)
    COUNT(DISTINCT CASE WHEN last_channel_non_direct = 'Direct' THEN session_id END)         AS sessions_direct,
    COUNT(DISTINCT CASE WHEN last_channel_non_direct = 'Organic Search' THEN session_id END) AS sessions_organic,
    COUNT(DISTINCT CASE WHEN last_channel_non_direct = 'Paid Search'    THEN session_id END) AS sessions_paid_search,
    COUNT(DISTINCT CASE WHEN last_channel_non_direct = 'Paid Social'    THEN session_id END) AS sessions_paid_social,
    COUNT(DISTINCT CASE WHEN last_channel_non_direct = 'Referral'       THEN session_id END) AS sessions_referral,
    COUNT(DISTINCT CASE WHEN last_channel_non_direct = 'Email'          THEN session_id END) AS sessions_email,
    COUNT(DISTINCT CASE WHEN last_channel_non_direct NOT IN
        ('Direct','Organic Search','Paid Search','Paid Social','Referral','Email') THEN session_id END) AS sessions_other_channel
FROM session_base
GROUP BY month_start
ORDER BY month_start;

-- TYPE AUDIT — q01:
--   Declared denominators (per RATE block):
--     #1 total_revenue_per_session: sessions_total (all sessions, no filter)
--     #3 engaged variant:           sessions_engaged (engaged_session_ind = 'Yes', has_app_view ALL)
--     #4 overall_conversion_rate:   sessions_total
--     #5 sign_ups_per_session:      sessions_total
--     #6 mqls_per_session:          sessions_total
--     #11 visitor_sign_up_cvr:      engaged unique_non_registered_visitors (proxied here as visitors_engaged)
--   JOIN chain: NONE — single-table aggregation over fct_sessions
--   Column used as denominator: COUNT(DISTINCT session_id) for tiles 1/3/4/5/6, COUNT(DISTINCT distinct_id) (engaged-filtered) for tile 11
--   Does the absence of JOINs preserve the declared denominators? YES — single-table aggregation, no fan-out risk
--   RESULT: PASS (single-table query; no JOIN-implied denominator divergence possible)
--
--   Caveats:
--     (a) Tile 11 strict denominator uses unique_non_registered_visitors which requires fct_sessions ⨝ dim_users on user_id.
--         This query proxies with visitors_engaged. The proxy includes already-registered users in the denominator,
--         which inflates the denominator and depresses the rate vs. the strict measure. Stakeholder benchmark cross-check
--         (Stage 4) will quantify the proxy bias at a known clean month.
--     (b) Tiles 1/3/14 require the modeled subscription_ltv_assumptions join. q04 below pulls that table.
--         Trend shape is captured by the COMPONENTS in q01; the exact tile value requires the LTV model.

------------------------------------------------------------------------
-- q02 — fct_subscriber_activity_mixpanel tiles (7, 8, 9, 10) — 24m monthly series
------------------------------------------------------------------------
-- Tiles covered:
--   #7  song_downloading_subscriber_rate_param @ days_since_sub = 7
--   #8  songs_downloaded_by_subscriber_param  @ days_since_sub = 30 (note: denominator is ALL subscribers, not downloading subscribers — see RATE block)
--   #9  engaged_subscriber_rate_30_to_60      = engaged_subs_30_60 / subs_60_plus
--   #10 sessions_per_engaged_subscriber_30_60 = sessions / engaged_subs_30_60 (filtered to is_sub_30_to_60)
--
-- Grain: subscriber × session row per fct_subscriber_activity_mixpanel.
-- The dashboard groups on dynamic_sub_start_date (subscription start month, not session month).
--
-- §1 RATE blocks: see contract-and-rates.md tiles 7, 8, 9, 10.

WITH activity AS (
    SELECT
        DATE_TRUNC('month', start_date)::DATE                                     AS sub_start_month,
        soundstripe_subscription_id,
        session_id,
        start_date,
        end_date,
        session_started_at,
        downloaded_songs,
        DATEDIFF('day', start_date, session_started_at::DATE)                     AS days_into_sub,
        DATEDIFF('day', start_date, end_date)                                     AS sub_lifetime_days
    FROM soundstripe_prod.core.fct_subscriber_activity_mixpanel
    WHERE start_date >= '2024-05-01'
      AND start_date <  '2026-05-01'
),
subscriber_level AS (
    SELECT
        sub_start_month,
        soundstripe_subscription_id,
        MAX(sub_lifetime_days)                                                    AS sub_lifetime_days,
        SUM(CASE WHEN days_into_sub <  7 AND NVL(downloaded_songs,0) > 0
                 THEN downloaded_songs ELSE 0 END)                                AS songs_dl_first_7d,
        MAX(CASE WHEN days_into_sub <  7 AND NVL(downloaded_songs,0) > 0
                 THEN 1 ELSE 0 END)                                               AS dl_in_first_7d_flag,
        SUM(CASE WHEN days_into_sub < 30 AND NVL(downloaded_songs,0) > 0
                 THEN downloaded_songs ELSE 0 END)                                AS songs_dl_first_30d,
        MAX(CASE WHEN days_into_sub < 30 AND NVL(downloaded_songs,0) > 0
                 THEN 1 ELSE 0 END)                                               AS dl_in_first_30d_flag,
        SUM(CASE WHEN days_into_sub BETWEEN 30 AND 59
                 THEN downloaded_songs ELSE 0 END)                                AS songs_dl_30_60d,
        MAX(CASE WHEN days_into_sub BETWEEN 30 AND 59
                 THEN 1 ELSE 0 END)                                               AS engaged_30_60d_flag,
        COUNT(DISTINCT CASE WHEN days_into_sub BETWEEN 30 AND 59
                            THEN session_id END)                                  AS sessions_30_60d
    FROM activity
    GROUP BY sub_start_month, soundstripe_subscription_id
)
SELECT
    sub_start_month                                                               AS month_start,

    -- Denominator candidates
    COUNT(DISTINCT soundstripe_subscription_id)                                   AS subscribers_in_cohort,
    COUNT(DISTINCT CASE WHEN sub_lifetime_days >= 60
                        THEN soundstripe_subscription_id END)                     AS subs_60_plus,
    -- Tile 7 numerator
    COUNT(DISTINCT CASE WHEN dl_in_first_7d_flag  = 1
                        THEN soundstripe_subscription_id END)                     AS subs_dl_first_7d,
    -- Tile 7 rate = subs_dl_first_7d / subscribers_in_cohort

    -- Tile 8 numerator components
    SUM(songs_dl_first_30d)                                                       AS songs_dl_first_30d_total,
    -- Tile 8 ratio = songs_dl_first_30d_total / subscribers_in_cohort
    -- (note: tile title says "per Downloading Subscriber" but measure denominator is `subscribers` not `songs_downloading_subscribers`)

    -- Tile 9 numerator (engaged 30-60d subs that lasted 60+)
    COUNT(DISTINCT CASE WHEN engaged_30_60d_flag = 1
                          AND sub_lifetime_days >= 60
                        THEN soundstripe_subscription_id END)                     AS engaged_subs_30_60_qualifying,
    -- Tile 9 rate = engaged_subs_30_60_qualifying / subs_60_plus

    -- Tile 10 numerator/denominator (sessions in 30-60d window, per engaged 30-60 sub)
    SUM(CASE WHEN engaged_30_60d_flag = 1 THEN sessions_30_60d END)               AS sessions_in_30_60_window_engaged,
    COUNT(DISTINCT CASE WHEN engaged_30_60d_flag = 1
                        THEN soundstripe_subscription_id END)                     AS engaged_subs_30_60_total
    -- Tile 10 ratio = sessions_in_30_60_window_engaged / engaged_subs_30_60_total

FROM subscriber_level
GROUP BY sub_start_month
ORDER BY sub_start_month;

-- TYPE AUDIT — q02:
--   Declared denominators (per RATE block):
--     #7  subscribers_in_cohort (all subscribers in cohort month)
--     #8  subscribers_in_cohort (the LookML measure says `subscribers`; the tile title misleads with "per Downloading Subscriber")
--     #9  subs_60_plus (only subs that lasted ≥60 days — gates both numerator and denominator)
--     #10 engaged_subs_30_60_total (only engaged subs in the 30-60d window)
--   JOIN chain: NONE — single-table aggregation over fct_subscriber_activity_mixpanel via subscriber-level rollup CTE
--   Column used as denominator: COUNT(DISTINCT soundstripe_subscription_id) (with appropriate filters)
--   Does the absence of JOINs preserve the declared denominators? YES
--   Right-censoring caveat: cohort months close to the end of the 24m window have incomplete observation periods.
--     - Tile 7 (0-7d): cohorts in the most recent ~1 week are partially observed; near-edge months may be biased low
--     - Tile 8 (0-30d): cohorts in the most recent ~30d are partially observed
--     - Tile 9 (30-60d): cohorts in the most recent ~60d are partially observed
--     - Tile 10 (30-60d): same right-censoring as #9
--   RESULT: PASS structurally; recent-month values flagged as right-censored

------------------------------------------------------------------------
-- q03 — subscription_changes_retention tiles (12, 13) — 24m monthly series
------------------------------------------------------------------------
-- Tiles covered:
--   #12 expansion_rate (filtered to prior_plan IN ('personal','pro','pro-plus'))
--   #13 avg_1_yr_value_of_expansion (no prior_plan filter at the dashboard level)
--
-- Replicates the subscription_changes_retention LookML derived table.
-- Grain: one row per subscription (incrementer_desc = 1 keeps the most recent change event).

WITH sub_changes AS (
    SELECT
        a.start_date,
        a.subscription_id,
        a.start_date AS sub_start_date,
        COALESCE(c.plan_array, b.prior_plan_type) AS prior_plan_raw,
        CASE WHEN COALESCE(c.plan_array, b.prior_plan_type) ILIKE 'business%' THEN 'business'
             WHEN COALESCE(c.plan_array, b.prior_plan_type) ILIKE 'creator%'  THEN 'personal'
             WHEN COALESCE(c.plan_array, b.prior_plan_type) ILIKE 'enterprise%'
               OR COALESCE(c.plan_array, b.prior_plan_type) IN (
                  'pro-microsoft_production_studios','pro-portlandjesuit','pro-renderstudios',
                  'pro-shakr','pro-south-dakota-university','pro-volkswagon','pro-waymark') THEN 'enterprise'
             WHEN COALESCE(c.plan_array, b.prior_plan_type) ILIKE ANY('pro-plus%','video%') THEN 'pro-plus'
             WHEN COALESCE(c.plan_array, b.prior_plan_type) ILIKE ANY('music%','pro%','sfx%','standard%','premium%') THEN 'pro'
             WHEN COALESCE(c.plan_array, b.prior_plan_type) ILIKE 'straynote%'  THEN 'custom sync'
             WHEN COALESCE(c.plan_array, b.prior_plan_type) ILIKE 'subaccounts%' THEN 'subaccounts'
             WHEN COALESCE(c.plan_array, b.prior_plan_type) ILIKE 'twitch-pro%' THEN 'twitch-pro'
             ELSE 'other' END AS prior_plan,
        COALESCE(b.new_plan_type, c.plan_array) AS new_plan_raw,
        CASE WHEN COALESCE(b.new_plan_type, c.plan_array) ILIKE 'business%' THEN 'business'
             WHEN COALESCE(b.new_plan_type, c.plan_array) ILIKE 'creator%'  THEN 'personal'
             WHEN COALESCE(b.new_plan_type, c.plan_array) ILIKE 'enterprise%'
               OR COALESCE(b.new_plan_type, c.plan_array) IN (
                  'pro-microsoft_production_studios','pro-portlandjesuit','pro-renderstudios',
                  'pro-shakr','pro-south-dakota-university','pro-volkswagon','pro-waymark') THEN 'enterprise'
             WHEN COALESCE(b.new_plan_type, c.plan_array) ILIKE ANY('pro-plus%','video%') THEN 'pro-plus'
             WHEN COALESCE(b.new_plan_type, c.plan_array) ILIKE ANY('music%','pro%','sfx%','standard%','premium%') THEN 'pro'
             WHEN COALESCE(b.new_plan_type, c.plan_array) ILIKE 'straynote%'  THEN 'custom sync'
             WHEN COALESCE(b.new_plan_type, c.plan_array) ILIKE 'subaccounts%' THEN 'subaccounts'
             WHEN COALESCE(b.new_plan_type, c.plan_array) ILIKE 'twitch-pro%' THEN 'twitch-pro'
             ELSE 'other' END AS new_plan,
        ROW_NUMBER() OVER (PARTITION BY a.subscription_id ORDER BY b.occurred_at DESC) AS incrementer_desc
    FROM soundstripe_prod.core.subscription_periods a
        LEFT JOIN soundstripe_prod.transformations.chargebee_subscription_changes b
            ON a.subscription_id = b.chargebee_subscription_id
            AND DATEDIFF('day', a.start_date::DATE, b.occurred_at::DATE) <= 30
        LEFT JOIN soundstripe_prod.transformations.chargebee_subscription_invoices c
            ON a.subscription_id = c.subscription_id
            AND c.subscription_invoice_number = 1
    WHERE a.start_date >= '2024-05-01'
      AND a.start_date <  '2026-05-01'
),
ltv_joined AS (
    SELECT
        sc.start_date,
        sc.subscription_id,
        sc.prior_plan,
        sc.new_plan,
        CASE WHEN sc.prior_plan = 'enterprise' THEN 6000 ELSE bplan.ltv_1_yr_gm END AS prior_ltv_1_yr,
        CASE WHEN sc.new_plan   = 'enterprise' THEN 6000 ELSE nplan.ltv_1_yr_gm END AS new_ltv_1_yr
    FROM sub_changes sc
        LEFT JOIN soundstripe_prod.finance.subscription_ltv_assumptions bplan
            ON CASE WHEN sc.prior_plan = 'personal' THEN 'creator' ELSE sc.prior_plan END = bplan.plan
        LEFT JOIN soundstripe_prod.finance.subscription_ltv_assumptions nplan
            ON CASE WHEN sc.new_plan   = 'personal' THEN 'creator' ELSE sc.new_plan   END = nplan.plan
    WHERE sc.incrementer_desc = 1
)
SELECT
    DATE_TRUNC('month', start_date)::DATE                                         AS month_start,
    -- Tile #12 (filtered to prior_plan IN ('personal','pro','pro-plus'))
    COUNT(DISTINCT CASE WHEN prior_plan IN ('personal','pro','pro-plus')
                        THEN subscription_id END)                                 AS qualifying_subs_for_expansion_rate,
    COUNT(DISTINCT CASE WHEN prior_plan IN ('personal','pro','pro-plus')
                          AND new_ltv_1_yr > prior_ltv_1_yr
                        THEN subscription_id END)                                 AS expansions_qualifying,
    -- expansion_rate = expansions_qualifying / qualifying_subs_for_expansion_rate

    -- Tile #13 (NO prior_plan filter — counts all expansions)
    COUNT(DISTINCT CASE WHEN new_ltv_1_yr > prior_ltv_1_yr
                        THEN subscription_id END)                                 AS expansions_all,
    SUM(CASE WHEN new_ltv_1_yr > prior_ltv_1_yr
             THEN new_ltv_1_yr - prior_ltv_1_yr END)                              AS expansion_value_total,
    -- avg_1_yr_value_of_expansion = expansion_value_total / expansions_all

    -- Diagnostic context
    COUNT(DISTINCT subscription_id)                                               AS subscriptions_total,
    COUNT(DISTINCT CASE WHEN new_ltv_1_yr < prior_ltv_1_yr THEN subscription_id END) AS contractions_all
FROM ltv_joined
GROUP BY month_start
ORDER BY month_start;

-- TYPE AUDIT — q03:
--   Declared denominator (#12): qualifying_subs_for_expansion_rate (filtered to prior_plan IN list)
--   JOIN chain: subscription_periods LEFT JOIN chargebee_subscription_changes (30d window)
--                                    LEFT JOIN chargebee_subscription_invoices (invoice #1)
--                                    LEFT JOIN subscription_ltv_assumptions (twice — prior + new plan LTV)
--   LEFT JOIN behavior: every subscription_periods row preserved; missing chargebee_change rows fall through
--                       with NULL prior/new plan_type, defaults applied via COALESCE in the LookML logic.
--   Does JOIN type enforce declared denominator? YES — denominator is COUNT(DISTINCT subscription_id) from
--                       subscription_periods spine, with the prior_plan filter applied explicitly in CASE.
--   RESULT: PASS

------------------------------------------------------------------------
-- q04 — subscription_ltv_assumptions snapshot (small dim, for tile 1/3/14 LTV reconstruction)
------------------------------------------------------------------------
-- Pull the LTV-1yr assumption table to reconstruct total_revenue model in tiles 1, 3, 14.
-- Used downstream for tile 1/3/14 trend chart.

SELECT
    plan,
    billing_interval,
    ltv_1_yr_gm,
    -- additional cols for context
    *
FROM soundstripe_prod.finance.subscription_ltv_assumptions
ORDER BY plan, billing_interval;

------------------------------------------------------------------------
-- q05 — Stakeholder benchmark cross-check anchor (Stage 4 VERIFY)
------------------------------------------------------------------------
-- For 2025-09 (clean baseline month, mid-window): pull the exact session counts and
-- numerators that should reconcile to Looker dashboard tile values.
--
-- Comparison cells:
--   sessions_total            ≈ Looker tile 1 denominator at 2025-09 (week_truncated)
--   subscribing_sessions      ≈ Looker tile 4 numerator component
--   visitors_signed_up        ≈ Looker tile 5 numerator
--   mqls_total_3component     ≈ Looker tile 6 numerator (sum of 3 visitor-distinct components)
--
-- Tolerance: ±2% — exact match unlikely due to monthly vs week aggregation in dashboard, but >2% indicates a methodology bug.

SELECT
    DATE_TRUNC('month', session_started_at)::DATE AS month_start,
    COUNT(DISTINCT session_id)                                                   AS sessions_total,
    COUNT(DISTINCT CASE WHEN created_subscription > 0 THEN session_id END)       AS subscribing_sessions,
    COUNT(DISTINCT CASE WHEN signed_up > 0 THEN distinct_id END)                 AS visitors_signed_up,
    COUNT(DISTINCT CASE WHEN enterprise_form_submissions > 0 THEN distinct_id END)
      + COUNT(DISTINCT CASE WHEN enterprise_landing_form_submissions > 0 THEN distinct_id END)
      + COUNT(DISTINCT CASE WHEN enterprise_schedule_demo > 0 THEN distinct_id END) AS mqls_total_3component
FROM soundstripe_prod.core.fct_sessions
WHERE session_started_at >= '2025-09-01'
  AND session_started_at <  '2025-10-01'
GROUP BY month_start;
