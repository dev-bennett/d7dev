-- Purpose:       Domain Consolidation Impact — Non-Current-Customer Cut
-- Author:        d7admin / Devon Bennett
-- Date:          2026-04-27
-- Stakeholder:   Sourav (CFO)
-- Parent task:   analysis/data-health/2026-04-24-domain-consolidation-impact/
-- Dependencies:
--   soundstripe_prod.core.fct_sessions
--   soundstripe_prod.core.dim_daily_kpis (identity check only)
-- Calibration artifacts:
--   knowledge/data-dictionary/calibration/core__fct_sessions.md (with pitfall #3a)
--   knowledge/data-dictionary/calibration/core__dim_daily_kpis.md
--
-- Segment definitions:
--   Def A (non-current-customer at session time): is_existing_subscriber = false
--     ↔ subscriber_category IN ('non subscriber', 'subscribing session')
--   Def C (logged-out proxy):                     user_id IS NULL
--   Robustness A∩C (anonymous + non-subscriber):  is_existing_subscriber = false AND user_id IS NULL
--
-- Comparison windows (carry over from parent):
--   A_2026_pre               2026-01-19 (Mon) → 2026-03-04 (Wed)  45d
--   A_2025_pre_dow_aligned   2025-01-20 (Mon) → 2025-03-05 (Wed)  45d
--   C_2026_post              2026-03-26 (Thu) → 2026-04-13 (Mon)  19d
--   C_2025_post_dow_aligned  2025-03-27 (Thu) → 2025-04-14 (Mon)  19d
-- Contamination zones (hard-excluded from headline): 2026-03-05→2026-03-25, 2026-04-14→2026-04-17

------------------------------------------------------------------------------------
-- q1: is_existing_subscriber population sanity — weekly distribution × channel
-- Purpose: confirm the column is populated and stable across the cutover.
--   Expected: subscriber_category one of three values; non-subscriber dominant in
--   acquisition channels (Organic, Paid, Direct); subscribing-session is a thin slice;
--   existing-subscriber dominates Direct return-visit traffic.
-- Cost:    fct_sessions, date-scoped 30-week window, one aggregate ~ <1s, <200KB.
------------------------------------------------------------------------------------
WITH base AS (
    SELECT
        DATE_TRUNC('week', session_started_at)::date AS week_start,
        last_channel_non_direct AS channel,
        subscriber_category,
        session_id
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2025-10-01' AND CURRENT_DATE()
)
SELECT week_start, channel, subscriber_category,
    COUNT(DISTINCT session_id) AS sessions
FROM base
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

------------------------------------------------------------------------------------
-- q1.5: PURCHASED_PRODUCT semantics discovery
-- Purpose: resolve whether PURCHASED_PRODUCT is the umbrella event covering subscription
--   creates + transactional, or an independent axis. dbt code (fct_sessions_build.sql:78-89)
--   shows each is sourced from a distinct Mixpanel event with no algebraic identity. The
--   front-end firing rules determine the actual relationship.
-- Result interpretation:
--   If row {CREATED>0, PURCHASED>0} dominates row {CREATED>0, PURCHASED=0}:
--     PURCHASED_PRODUCT is the umbrella; CREATED ⊆ PURCHASED — CVR numerator = PURCHASED_PRODUCT > 0
--   If diagonal dominates:
--     Independent axes — CVR numerator = (CREATED_SUBSCRIPTION > 0 OR PURCHASED_PRODUCT > 0)
--   Also reports SUM(PURCHASED_PRODUCT_COUNT) vs SUM(SINGLE_SONG + SFX + MARKET) at the
--   COUNT level — independent confirmation of additive identity vs umbrella.
-- Cost:    fct_sessions, 7-day window, single aggregate.
------------------------------------------------------------------------------------
WITH base AS (
    SELECT
        session_id,
        CASE WHEN CREATED_SUBSCRIPTION > 0 THEN 1 ELSE 0 END AS has_created_sub,
        CASE WHEN PURCHASED_PRODUCT > 0 THEN 1 ELSE 0 END AS has_purchased_product,
        CREATED_SUBSCRIPTION,
        PURCHASED_PRODUCT_COUNT,
        NVL(SINGLE_SONG_PURCHASE_COUNT, 0) AS single_song_count,
        NVL(SFX_PURCHASE_COUNT, 0) AS sfx_count,
        NVL(MARKET_PURCHASE_COUNT, 0) AS market_count
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2026-04-13' AND '2026-04-19'
)
SELECT 'cell_count' AS metric_kind,
    has_created_sub::TEXT || '_' || has_purchased_product::TEXT AS bucket,
    COUNT(DISTINCT session_id)::TEXT AS value,
    NULL::TEXT AS extra
FROM base
GROUP BY 1, 2
UNION ALL
SELECT 'count_sum', 'sum_PURCHASED_PRODUCT_COUNT',
    SUM(PURCHASED_PRODUCT_COUNT)::TEXT, NULL FROM base
UNION ALL
SELECT 'count_sum', 'sum_SINGLE_SONG_COUNT',
    SUM(single_song_count)::TEXT, NULL FROM base
UNION ALL
SELECT 'count_sum', 'sum_SFX_COUNT',
    SUM(sfx_count)::TEXT, NULL FROM base
UNION ALL
SELECT 'count_sum', 'sum_MARKET_COUNT',
    SUM(market_count)::TEXT, NULL FROM base
UNION ALL
SELECT 'count_sum', 'sum_SINGLE_SONG+SFX+MARKET',
    (SUM(single_song_count) + SUM(sfx_count) + SUM(market_count))::TEXT, NULL FROM base
UNION ALL
SELECT 'created_sub_count', 'sum_CREATED_SUBSCRIPTION',
    SUM(CREATED_SUBSCRIPTION)::TEXT, NULL FROM base
ORDER BY 1, 2;

------------------------------------------------------------------------------------
-- q2: Def A vs Def C cross-tab — single recent week
-- Purpose: quantify the gap between A (subscriber_category) and C (user_id IS NULL)
--   so the headline (A) is reported alongside a robustness cell (A∩C).
-- Cost:    fct_sessions, 7-day window.
------------------------------------------------------------------------------------
WITH base AS (
    SELECT
        session_id,
        CASE WHEN is_existing_subscriber = false THEN 1 ELSE 0 END AS def_a_nc,
        CASE WHEN user_id IS NULL THEN 1 ELSE 0 END AS def_c_anon
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2026-04-07' AND '2026-04-13'
)
SELECT
    def_a_nc, def_c_anon,
    COUNT(DISTINCT session_id) AS sessions
FROM base
GROUP BY 1, 2
ORDER BY 1, 2;

-- q1.5 result (2026-04-27): PURCHASED_PRODUCT IS the umbrella event covering subscription
-- creates + transactional purchases. Cell {CREATED=1, PURCHASED=0} = 0; CREATED ⊆ PURCHASED.
-- count_sum: PURCHASED_PRODUCT_COUNT=155, SINGLE_SONG+SFX+MARKET=34, CREATED_SUBSCRIPTION=118.
-- The 155-34=121 gap closely matches the 118 created_subs (residual ~3 = add-ons / plan changes).
-- CVR construction:
--   sub_cvr        = sessions WHERE CREATED_SUBSCRIPTION > 0
--   combined_cvr   = sessions WHERE PURCHASED_PRODUCT > 0   (CREATED ⊆ PURCHASED)
--   transact_cvr   = sessions WHERE PURCHASED_PRODUCT > 0 AND CREATED_SUBSCRIPTION = 0
--
-- q2 result (2026-04-27): Def A captures 82.4% of sessions; Def C 75.7%; A∩C 74.5%.
-- Def A − C = 9,476 sessions (logged-in non-customers) — Def C undercount.
-- Def C − A = 1,499 sessions (logged-out customers)    — Def C miscount.
-- Headline = Def A; robustness cell = A∩C; pure C dropped (dominated).

------------------------------------------------------------------------------------
-- q3: NC weekly sessions by channel × host_bucket — Def A (non-customer at session time)
-- Mirrors parent task q2 (which was all-traffic). Headline: NC Organic Search trajectory
-- across cutover. Cost: ~30-week scope, fct_sessions, single aggregate, <1s expected.
------------------------------------------------------------------------------------
WITH base AS (
    SELECT
        DATE_TRUNC('week', session_started_at)::date AS week_start,
        last_channel_non_direct AS channel,
        CASE
            WHEN landing_page_host = 'www.soundstripe.com' THEN 'www'
            WHEN landing_page_host = 'app.soundstripe.com' THEN 'app'
            WHEN landing_page_host = 'soundstripe.com' THEN 'apex'
            ELSE 'other'
        END AS host_bucket,
        session_id, distinct_id
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2025-10-01' AND CURRENT_DATE()
      AND is_existing_subscriber = false  -- Def A
)
SELECT week_start, channel, host_bucket,
    COUNT(DISTINCT session_id) AS sessions,
    COUNT(DISTINCT distinct_id) AS visitors
FROM base
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

------------------------------------------------------------------------------------
-- q4: NC DID — DoW-aligned YoY anchors — HEADLINE
-- Mirrors parent task q16. Same four windows, Def A filter applied.
--   A_2026_pre               2026-01-19 (Mon) → 2026-03-04 (Wed)  45d
--   A_2025_pre_dow_aligned   2025-01-20 (Mon) → 2025-03-05 (Wed)  45d
--   C_2026_post              2026-03-26 (Thu) → 2026-04-13 (Mon)  19d
--   C_2025_post_dow_aligned  2025-03-27 (Thu) → 2025-04-14 (Mon)  19d
-- DID = (YoY ratio post) - (YoY ratio pre), expressed in pp.
--
-- §1 RATE block — yoy_ratio:
--   RATE: yoy_ratio_<channel>_<period>
--   NUMERATOR: 2026 NC sessions/day in window
--   DENOMINATOR: 2025 DoW-aligned NC sessions/day in window
--   TYPE: 2026_nc_sessions_per_day / 2025_nc_sessions_per_day
--   NOT: total-window sessions (window lengths differ across pre/post — daily rate normalizes)
-- TYPE AUDIT — yoy_ratio: implicit; rate computed downstream from per-window absolute counts.
--   No JOIN; same-table filter scope; PASS.
------------------------------------------------------------------------------------
WITH base AS (
    SELECT
        CASE
            WHEN session_started_at::date BETWEEN '2026-01-19' AND '2026-03-04' THEN 'A_2026_pre'
            WHEN session_started_at::date BETWEEN '2025-01-20' AND '2025-03-05' THEN 'A_2025_pre_dow_aligned'
            WHEN session_started_at::date BETWEEN '2026-03-26' AND '2026-04-13' THEN 'C_2026_post'
            WHEN session_started_at::date BETWEEN '2025-03-27' AND '2025-04-14' THEN 'C_2025_post_dow_aligned'
        END AS window_label,
        last_channel_non_direct AS channel,
        session_id, distinct_id
    FROM soundstripe_prod.core.fct_sessions
    WHERE ((session_started_at::date BETWEEN '2025-01-20' AND '2025-04-14')
        OR (session_started_at::date BETWEEN '2026-01-19' AND '2026-04-13'))
      AND is_existing_subscriber = false  -- Def A
)
SELECT window_label, channel,
    COUNT(DISTINCT session_id) AS sessions,
    COUNT(DISTINCT distinct_id) AS visitors
FROM base WHERE window_label IS NOT NULL
GROUP BY 1, 2 ORDER BY 2, 1;

------------------------------------------------------------------------------------
-- q5: NC DID — robustness alternative using A ∩ C (anonymous + non-customer)
-- Same construct as q4 with the additional `user_id IS NULL` filter. Confirms headline
-- isn't sensitive to the 8% logged-in-non-customer band that Def A includes but Def C excludes.
------------------------------------------------------------------------------------
WITH base AS (
    SELECT
        CASE
            WHEN session_started_at::date BETWEEN '2026-01-19' AND '2026-03-04' THEN 'A_2026_pre'
            WHEN session_started_at::date BETWEEN '2025-01-20' AND '2025-03-05' THEN 'A_2025_pre_dow_aligned'
            WHEN session_started_at::date BETWEEN '2026-03-26' AND '2026-04-13' THEN 'C_2026_post'
            WHEN session_started_at::date BETWEEN '2025-03-27' AND '2025-04-14' THEN 'C_2025_post_dow_aligned'
        END AS window_label,
        last_channel_non_direct AS channel,
        session_id, distinct_id
    FROM soundstripe_prod.core.fct_sessions
    WHERE ((session_started_at::date BETWEEN '2025-01-20' AND '2025-04-14')
        OR (session_started_at::date BETWEEN '2026-01-19' AND '2026-04-13'))
      AND is_existing_subscriber = false  -- Def A
      AND user_id IS NULL                  -- ∩ Def C
)
SELECT window_label, channel,
    COUNT(DISTINCT session_id) AS sessions,
    COUNT(DISTINCT distinct_id) AS visitors
FROM base WHERE window_label IS NOT NULL
GROUP BY 1, 2 ORDER BY 2, 1;

------------------------------------------------------------------------------------
-- q6: NC summary roll-up — six windows × channel, sessions/visitors/bounce/duration/pageviews
-- Mirrors parent task q14. Def A filter. Includes contamination zones B/D so the readout
-- can show their inflated counts alongside the clean post window for context.
--   A_pre_recency  2026-01-19 → 2026-03-04 (45d)
--   B_contam1      2026-03-05 → 2026-03-25 (21d) — Fastly artifact, hard-excluded from headline
--   C_post_clean   2026-03-26 → 2026-04-13 (19d) — primary post window
--   D_contam2      2026-04-14 → 2026-04-17 (4d)  — APAC spike, hard-excluded
--   E_tail         2026-04-18 → 2026-04-24 (7d)
--   F_yoy_2025     2025-03-26 → 2025-04-13 (19d)
------------------------------------------------------------------------------------
WITH base AS (
    SELECT
        CASE
            WHEN session_started_at::date BETWEEN '2026-01-19' AND '2026-03-04' THEN 'A_pre_recency'
            WHEN session_started_at::date BETWEEN '2026-03-05' AND '2026-03-25' THEN 'B_contam1'
            WHEN session_started_at::date BETWEEN '2026-03-26' AND '2026-04-13' THEN 'C_post_clean'
            WHEN session_started_at::date BETWEEN '2026-04-14' AND '2026-04-17' THEN 'D_contam2'
            WHEN session_started_at::date BETWEEN '2026-04-18' AND '2026-04-24' THEN 'E_tail'
            WHEN session_started_at::date BETWEEN '2025-03-26' AND '2025-04-13' THEN 'F_yoy_2025'
        END AS window_label,
        last_channel_non_direct AS channel,
        session_id, distinct_id, bounced_sessions, session_duration_seconds, pageviews
    FROM soundstripe_prod.core.fct_sessions
    WHERE ((session_started_at::date BETWEEN '2025-03-26' AND '2025-04-13')
        OR (session_started_at::date BETWEEN '2026-01-19' AND '2026-04-24'))
      AND is_existing_subscriber = false  -- Def A
)
SELECT window_label, channel,
    COUNT(DISTINCT session_id) AS sessions, COUNT(DISTINCT distinct_id) AS visitors,
    ROUND(SUM(bounced_sessions) / NULLIF(COUNT(DISTINCT session_id), 0) * 100, 1) AS bounce_pct,
    ROUND(AVG(session_duration_seconds), 0) AS avg_duration_sec,
    ROUND(MEDIAN(session_duration_seconds), 0) AS median_duration_sec,
    ROUND(AVG(pageviews), 2) AS avg_pageviews
FROM base WHERE window_label IS NOT NULL
GROUP BY 1, 2 ORDER BY 1, 2;

------------------------------------------------------------------------------------
-- q7: NC CVR — pre vs post — three numerators side-by-side
-- §1 RATE block — sub_cvr_<period>:
--   NUMERATOR: NC sessions WHERE CREATED_SUBSCRIPTION > 0 in window
--   DENOMINATOR: NC sessions in window
--   TYPE: nc_subscribing_sessions / nc_sessions
--   NOT: NC sessions WHERE purchased_product > 0 (broader; that's combined_cvr)
-- §1 RATE block — combined_cvr_<period>:
--   NUMERATOR: NC sessions WHERE PURCHASED_PRODUCT > 0 in window (umbrella; per q1.5)
--   DENOMINATOR: NC sessions in window
--   TYPE: nc_monetizing_sessions / nc_sessions
-- §1 RATE block — transact_cvr_<period>:
--   NUMERATOR: NC sessions WHERE PURCHASED_PRODUCT > 0 AND CREATED_SUBSCRIPTION = 0
--   DENOMINATOR: NC sessions in window
--   TYPE: nc_transactional_only_sessions / nc_sessions
-- TYPE AUDIT — all three: same-row predicate on filtered population; no JOIN; PASS.
--
-- Contamination filter applied per parent calibration pitfalls #1 (Fastly POP) and #2 (APAC).
-- Reports per-channel for Organic Search, Direct, Paid Search; pre vs post-clean only.
------------------------------------------------------------------------------------
WITH base AS (
    SELECT
        CASE
            WHEN session_started_at::date BETWEEN '2026-01-19' AND '2026-03-04' THEN 'A_pre_recency'
            WHEN session_started_at::date BETWEEN '2026-03-26' AND '2026-04-13' THEN 'C_post_clean'
        END AS window_label,
        last_channel_non_direct AS channel,
        session_id,
        CASE WHEN created_subscription > 0 THEN 1 ELSE 0 END AS subbed,
        CASE WHEN purchased_product > 0 THEN 1 ELSE 0 END AS purchased,
        CASE WHEN purchased_product > 0 AND created_subscription = 0 THEN 1 ELSE 0 END AS transact_only
    FROM soundstripe_prod.core.fct_sessions
    WHERE ((session_started_at::date BETWEEN '2026-01-19' AND '2026-03-04')
        OR (session_started_at::date BETWEEN '2026-03-26' AND '2026-04-13'))
      AND is_existing_subscriber = false  -- Def A
      -- Contamination filters not needed for these two windows (both are clean periods).
)
SELECT window_label, channel,
    COUNT(DISTINCT session_id) AS nc_sessions,
    SUM(subbed) AS subbed_sessions,
    SUM(purchased) AS purchased_sessions,
    SUM(transact_only) AS transact_only_sessions,
    ROUND(SUM(subbed) / NULLIF(COUNT(DISTINCT session_id), 0)::FLOAT * 10000, 2) AS sub_cvr_bps,
    ROUND(SUM(purchased) / NULLIF(COUNT(DISTINCT session_id), 0)::FLOAT * 10000, 2) AS combined_cvr_bps,
    ROUND(SUM(transact_only) / NULLIF(COUNT(DISTINCT session_id), 0)::FLOAT * 10000, 2) AS transact_cvr_bps
FROM base WHERE window_label IS NOT NULL
GROUP BY 1, 2 ORDER BY 2, 1;

------------------------------------------------------------------------------------
-- q8: Direct sprawl test — for logged-in users, distinct profile_ids per user per week
-- Logged-in users have a stable user_id, so the dbt bridge (distinct_id_mapping → identify
-- events) has visibility on their identity. If profile_ids-per-user inflates POST-cutover,
-- sprawl is real in the consolidated fct_sessions namespace despite stitching.
--
-- Bridge mechanism (read from context/dbt/models/transformations/mixpanel/distinct_id_mapping.sql):
--   - Captures a row per Identify event mapping anonymous distinct_id_old → consolidated distinct_id
--   - Anonymous-only never-login users have NO Identify event → their distinct_id flows unchanged
--     through the LEFT JOIN in fct_sessions_build_step2
--   - Logged-in users DO trigger Identify → bridge populates → post-stitch they get one profile_id
--
-- Hypothesis decision rule:
--   avg_dids_per_user stable across cutover (pre ≈ post)  → bridge is doing its job for logged-in;
--                                                            pitfall #3a sprawl claim is overclaimed;
--                                                            NC sessions/visitors inflation is most
--                                                            parsimoniously real-traffic
--   avg_dids_per_user materially higher post-cutover      → sprawl penetrates the consolidated
--                                                            namespace even for users the bridge can
--                                                            see; pitfall #3a is supported; sessions-level
--                                                            metrics carry an unquantified inflation
--
-- Cost: fct_sessions, 12-week scope, user-level aggregate. Expected <1s.
------------------------------------------------------------------------------------
WITH user_dids_per_week AS (
    SELECT
        user_id,
        DATE_TRUNC('week', session_started_at)::date AS week_start,
        COUNT(DISTINCT distinct_id) AS dids_in_week,
        COUNT(DISTINCT session_id) AS sessions_in_week
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2026-01-19' AND '2026-04-13'
      AND user_id IS NOT NULL
    GROUP BY 1, 2
)
SELECT
    CASE
      WHEN week_start < '2026-03-05' THEN 'A_pre_clean'
      WHEN week_start BETWEEN '2026-03-05' AND '2026-03-22' THEN 'B_cutover_zone'
      WHEN week_start >= '2026-03-23' THEN 'C_post_clean'
    END AS period,
    week_start,
    COUNT(*) AS active_logged_in_users,
    ROUND(AVG(dids_in_week), 3) AS avg_dids_per_user,
    SUM(CASE WHEN dids_in_week > 1 THEN 1 ELSE 0 END) AS users_with_multiple_dids,
    ROUND(SUM(CASE WHEN dids_in_week > 1 THEN 1 ELSE 0 END) / COUNT(*)::FLOAT * 100, 2) AS pct_users_with_multiple,
    MAX(dids_in_week) AS max_dids_in_week,
    ROUND(AVG(sessions_in_week), 2) AS avg_sessions_per_user
FROM user_dids_per_week
GROUP BY 1, 2
ORDER BY 2;

------------------------------------------------------------------------------------
-- q9: Legit-traffic tier sizing — NC sessions/day per tier × channel × window
-- See `legit_traffic_definitions.md` in this folder for tier definitions.
-- Tiers (nested):
--   T0 = all NC; T1 = T0 - documented contamination; T2 = T1 - (pv=1 AND dur≤1);
--   T3 = T2 AND (pv≥2 OR any engagement event); T4 = T3 AND dur≥30s.
-- Window scope: A_pre_recency (45d) + C_post_clean (19d) only — the same windows
-- the headline uses.
-- Cost: fct_sessions, ~64-day scope, single aggregate, expected <1s.
------------------------------------------------------------------------------------
WITH base AS (
    SELECT
        CASE
            WHEN session_started_at::date BETWEEN '2026-01-19' AND '2026-03-04' THEN 'A_pre_recency'
            WHEN session_started_at::date BETWEEN '2026-03-26' AND '2026-04-13' THEN 'C_post_clean'
        END AS window_label,
        last_channel_non_direct AS channel,
        session_id, country, last_channel_non_direct AS lc, bounced_sessions,
        pageviews, session_duration_seconds,
        played_songs_count, searched_songs_count, downloaded_songs_count,
        searched_sound_effects_count, played_sound_effects_count, downloaded_sound_effects_count,
        enterprise_form_submissions, signed_up, signed_in,
        created_subscription, purchased_product,
        session_started_at::date AS sess_date
    FROM soundstripe_prod.core.fct_sessions
    WHERE ((session_started_at::date BETWEEN '2026-01-19' AND '2026-03-04')
        OR (session_started_at::date BETWEEN '2026-03-26' AND '2026-04-13'))
      AND is_existing_subscriber = false  -- Def A
),
flagged AS (
    SELECT *,
        -- T1 contamination filter (T1 = T0 minus this flag = 1)
        CASE WHEN
              (sess_date BETWEEN '2026-03-05' AND '2026-03-25'
                AND lc = 'Direct' AND country IN ('DE','NL','CA') AND bounced_sessions = 1)
           OR (sess_date BETWEEN '2026-04-14' AND '2026-04-17'
                AND lc = 'Direct' AND country IN ('CN','SG','VN','HK','JP') AND bounced_sessions = 1)
        THEN 1 ELSE 0 END AS is_documented_contamination,
        -- T2 generic technical-artifact filter
        CASE WHEN pageviews = 1 AND session_duration_seconds <= 1 THEN 1 ELSE 0 END AS is_instant_bounce,
        -- T3 engagement-positive
        CASE WHEN pageviews >= 2
              OR played_songs_count > 0
              OR searched_songs_count > 0
              OR downloaded_songs_count > 0
              OR searched_sound_effects_count > 0
              OR played_sound_effects_count > 0
              OR downloaded_sound_effects_count > 0
              OR enterprise_form_submissions > 0
              OR signed_up > 0
              OR signed_in > 0
              OR created_subscription > 0
              OR purchased_product > 0
        THEN 1 ELSE 0 END AS is_engaged
    FROM base
)
SELECT window_label, channel,
    COUNT(DISTINCT session_id) AS t0_sessions,
    COUNT(DISTINCT CASE WHEN is_documented_contamination = 0 THEN session_id END) AS t1_sessions,
    COUNT(DISTINCT CASE WHEN is_documented_contamination = 0 AND is_instant_bounce = 0 THEN session_id END) AS t2_sessions,
    COUNT(DISTINCT CASE WHEN is_documented_contamination = 0 AND is_instant_bounce = 0 AND is_engaged = 1 THEN session_id END) AS t3_sessions,
    COUNT(DISTINCT CASE WHEN is_documented_contamination = 0 AND is_instant_bounce = 0 AND is_engaged = 1 AND session_duration_seconds >= 30 THEN session_id END) AS t4_sessions
FROM flagged WHERE window_label IS NOT NULL
GROUP BY 1, 2 ORDER BY 2, 1;

------------------------------------------------------------------------------------
-- q10: Tier × returning-vs-first-time cross-cut on NC Organic Search
-- session_counter = 1 → first-time; >= 2 → returning. Independent of tier.
------------------------------------------------------------------------------------
WITH base AS (
    SELECT
        CASE
            WHEN session_started_at::date BETWEEN '2026-01-19' AND '2026-03-04' THEN 'A_pre_recency'
            WHEN session_started_at::date BETWEEN '2026-03-26' AND '2026-04-13' THEN 'C_post_clean'
        END AS window_label,
        session_id, session_counter,
        pageviews, session_duration_seconds,
        played_songs_count, searched_songs_count, downloaded_songs_count,
        searched_sound_effects_count, played_sound_effects_count, downloaded_sound_effects_count,
        enterprise_form_submissions, signed_up, signed_in,
        created_subscription, purchased_product
    FROM soundstripe_prod.core.fct_sessions
    WHERE ((session_started_at::date BETWEEN '2026-01-19' AND '2026-03-04')
        OR (session_started_at::date BETWEEN '2026-03-26' AND '2026-04-13'))
      AND is_existing_subscriber = false
      AND last_channel_non_direct = 'Organic Search'
),
flagged AS (
    SELECT *,
        CASE WHEN pageviews = 1 AND session_duration_seconds <= 1 THEN 1 ELSE 0 END AS is_instant_bounce,
        CASE WHEN pageviews >= 2
              OR played_songs_count > 0 OR searched_songs_count > 0 OR downloaded_songs_count > 0
              OR searched_sound_effects_count > 0 OR played_sound_effects_count > 0 OR downloaded_sound_effects_count > 0
              OR enterprise_form_submissions > 0 OR signed_up > 0 OR signed_in > 0
              OR created_subscription > 0 OR purchased_product > 0
        THEN 1 ELSE 0 END AS is_engaged,
        CASE WHEN session_counter = 1 THEN 'first_time' ELSE 'returning' END AS visitor_kind
    FROM base
)
SELECT window_label, visitor_kind,
    COUNT(DISTINCT session_id) AS t0_sessions,
    COUNT(DISTINCT CASE WHEN is_instant_bounce = 0 THEN session_id END) AS t2_sessions,
    COUNT(DISTINCT CASE WHEN is_instant_bounce = 0 AND is_engaged = 1 THEN session_id END) AS t3_sessions
FROM flagged WHERE window_label IS NOT NULL
GROUP BY 1, 2 ORDER BY 1, 2;

------------------------------------------------------------------------------------
-- q11: DID under tier filters — NC Organic only, T1 / T2 / T3 sensitivity
-- Re-runs the q4 DID construct (DoW-aligned YoY anchors) at three tier levels.
-- Decision rule: if T3 DID magnitude ≈ T0 DID, the +29.5/+49.6pp headline survives
-- noise removal. If T3 collapses materially, the headline is partially noise.
------------------------------------------------------------------------------------
WITH base AS (
    SELECT
        CASE
            WHEN session_started_at::date BETWEEN '2026-01-19' AND '2026-03-04' THEN 'A_2026_pre'
            WHEN session_started_at::date BETWEEN '2025-01-20' AND '2025-03-05' THEN 'A_2025_pre_dow_aligned'
            WHEN session_started_at::date BETWEEN '2026-03-26' AND '2026-04-13' THEN 'C_2026_post'
            WHEN session_started_at::date BETWEEN '2025-03-27' AND '2025-04-14' THEN 'C_2025_post_dow_aligned'
        END AS window_label,
        session_id, country, last_channel_non_direct AS lc, bounced_sessions,
        pageviews, session_duration_seconds,
        played_songs_count, searched_songs_count, downloaded_songs_count,
        searched_sound_effects_count, played_sound_effects_count, downloaded_sound_effects_count,
        enterprise_form_submissions, signed_up, signed_in,
        created_subscription, purchased_product,
        session_started_at::date AS sess_date
    FROM soundstripe_prod.core.fct_sessions
    WHERE ((session_started_at::date BETWEEN '2025-01-20' AND '2025-04-14')
        OR (session_started_at::date BETWEEN '2026-01-19' AND '2026-04-13'))
      AND is_existing_subscriber = false
      AND last_channel_non_direct = 'Organic Search'
),
flagged AS (
    SELECT *,
        CASE WHEN
              (sess_date BETWEEN '2026-03-05' AND '2026-03-25'
                AND lc = 'Direct' AND country IN ('DE','NL','CA') AND bounced_sessions = 1)
           OR (sess_date BETWEEN '2026-04-14' AND '2026-04-17'
                AND lc = 'Direct' AND country IN ('CN','SG','VN','HK','JP') AND bounced_sessions = 1)
        THEN 1 ELSE 0 END AS is_documented_contamination,
        CASE WHEN pageviews = 1 AND session_duration_seconds <= 1 THEN 1 ELSE 0 END AS is_instant_bounce,
        CASE WHEN pageviews >= 2
              OR played_songs_count > 0 OR searched_songs_count > 0 OR downloaded_songs_count > 0
              OR searched_sound_effects_count > 0 OR played_sound_effects_count > 0 OR downloaded_sound_effects_count > 0
              OR enterprise_form_submissions > 0 OR signed_up > 0 OR signed_in > 0
              OR created_subscription > 0 OR purchased_product > 0
        THEN 1 ELSE 0 END AS is_engaged
    FROM base
)
SELECT window_label,
    COUNT(DISTINCT session_id) AS t0_sessions,
    COUNT(DISTINCT CASE WHEN is_documented_contamination = 0 THEN session_id END) AS t1_sessions,
    COUNT(DISTINCT CASE WHEN is_documented_contamination = 0 AND is_instant_bounce = 0 THEN session_id END) AS t2_sessions,
    COUNT(DISTINCT CASE WHEN is_documented_contamination = 0 AND is_instant_bounce = 0 AND is_engaged = 1 THEN session_id END) AS t3_sessions
FROM flagged WHERE window_label IS NOT NULL
GROUP BY 1 ORDER BY 1;

------------------------------------------------------------------------------------
-- q12: Known-bad-signature audit — distribution of NC sessions where pv=1 AND dur≤1
-- by country × channel × week. Surfaces non-documented contamination patterns or
-- channels with anomalous concentration of the instant-bounce signature.
------------------------------------------------------------------------------------
SELECT
    DATE_TRUNC('week', session_started_at)::date AS week_start,
    last_channel_non_direct AS channel,
    country,
    COUNT(DISTINCT session_id) AS instant_bounce_sessions
FROM soundstripe_prod.core.fct_sessions
WHERE session_started_at::date BETWEEN '2026-01-19' AND '2026-04-13'
  AND is_existing_subscriber = false
  AND pageviews = 1
  AND session_duration_seconds <= 1
GROUP BY 1, 2, 3
HAVING COUNT(DISTINCT session_id) >= 100   -- floor to keep the output focused
ORDER BY 1, 4 DESC;
