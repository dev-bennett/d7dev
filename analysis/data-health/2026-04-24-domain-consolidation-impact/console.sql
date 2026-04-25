-- Purpose:       Diagnostic queries for Domain Consolidation Impact Analysis
-- Author:        d7admin / Devon Bennett
-- Date:          2026-04-24
-- Asana:         https://app.asana.com/1/411777761188590/project/1205525083743256/task/1213715723297289
-- Stakeholder:   Meredith Knott
-- Plan:          /Users/dev/.claude/plans/expressive-nibbling-rabin.md
-- Dependencies:
--   soundstripe_prod.core.fct_sessions
--   soundstripe_prod.core.dim_daily_kpis
--   soundstripe_prod.core.fct_sessions_attribution (reserved; not yet referenced)
-- Calibration artifacts:
--   knowledge/data-dictionary/calibration/core__fct_sessions.md
--   knowledge/data-dictionary/calibration/core__dim_daily_kpis.md
--   knowledge/data-dictionary/calibration/core__fct_sessions_attribution.md
-- Channel column: use last_channel_non_direct (NOT raw channel) per calibration pitfall #3 on fct_sessions
-- Reproduction predicate for dim_daily_kpis identity check:
--   WHERE last_channel_non_direct = 'Direct' AND marketing_test_ind = 0
-- Comparison windows (see CLAUDE.md): pre-long 2025-10-01..2026-03-04, contam-1 2026-03-05..2026-03-25,
--   post-clean 2026-03-26..2026-04-13, contam-2 2026-04-14..2026-04-17, tail 2026-04-18..2026-04-24,
--   YoY 2025-03-26..2025-04-13.

------------------------------------------------------------------------------------
-- q1: Calibration sanity — date range, channel distribution, host distribution
------------------------------------------------------------------------------------
WITH base AS (
    SELECT *
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2025-10-01' AND CURRENT_DATE()
)
SELECT 'total_rows_in_window' AS metric, COUNT(*)::TEXT AS value FROM base
UNION ALL SELECT 'min_date', MIN(session_started_at::date)::TEXT FROM base
UNION ALL SELECT 'max_date', MAX(session_started_at::date)::TEXT FROM base
UNION ALL SELECT 'distinct_channels_last_non_direct',
    LISTAGG(DISTINCT last_channel_non_direct, '|') WITHIN GROUP (ORDER BY last_channel_non_direct) FROM base
UNION ALL SELECT 'distinct_landing_hosts_pre_2026_03_16',
    LISTAGG(DISTINCT landing_page_host, '|') WITHIN GROUP (ORDER BY landing_page_host) FROM base
    WHERE session_started_at::date < '2026-03-16'
UNION ALL SELECT 'distinct_landing_hosts_post_2026_03_16',
    LISTAGG(DISTINCT landing_page_host, '|') WITHIN GROUP (ORDER BY landing_page_host) FROM base
    WHERE session_started_at::date >= '2026-03-16';

-- q1 result: 3,830,294 rows in window. 9 channels (Affiliate/Direct/Email/Organic Search/Organic Social/Paid Content/Paid Search/Paid Social/Referral).
-- Pre-cutover canonical hosts: www.soundstripe.com, app.soundstripe.com (plus long tail of 200+ embed/scrape hosts).
-- Post-cutover canonical hosts: www.soundstripe.com (now serves both), app.soundstripe.com (residual 301-redirect-source), soundstripe.com (apex).
-- Per PRD page 26 final rollout: canonical = www.soundstripe.com (NOT soundstripe.com apex as initially planned).

------------------------------------------------------------------------------------
-- q2: Weekly sessions by channel × canonical host bucket (the load-bearing dataset)
------------------------------------------------------------------------------------
-- Bucketing: www | app | apex | other (everything else = embeds/iframes/scrapes/dev)
-- channel = last_channel_non_direct per fct_sessions calibration pitfall #3
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
        session_id,
        distinct_id
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2025-10-01' AND CURRENT_DATE()
)
SELECT week_start, channel, host_bucket,
    COUNT(DISTINCT session_id) AS sessions,
    COUNT(DISTINCT distinct_id) AS visitors
FROM base
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3;

-- q2 headline (host-consolidated, channel-attributed):
-- Pre-cutover organic (week 2026-03-09): app+www = 39,676 sessions
-- Post-cutover clean window (week 2026-03-30): www+app = 50,615 sessions  → +27.5%
-- Post-cutover clean window (week 2026-04-06): www+app = 49,202 sessions  → +24.0%
-- Direct (host-consolidated):
-- Pre-cutover (week 2026-03-09): 52,896
-- Post-cutover clean (week 2026-04-06): 49,731 → -6.0%
-- 2026-04-13 week shows 119,714 Direct on www — contamination zone 2 spike (excluded from headline).

------------------------------------------------------------------------------------
-- q3: Paid spend control + acquisition by channel (dim_daily_kpis)
-- Result headline: Paid spend went UP from ~$17K/wk pre to ~$30K/wk clean post (+75%) → RULES OUT paid pull-back alt mechanism.
-- Organic_search_subs: pre avg ~58/wk, post clean avg ~73/wk → +25.9%
------------------------------------------------------------------------------------
SELECT DATE_TRUNC('week', date)::date AS week_start,
    SUM(paid_search_spend) AS paid_search_spend,
    SUM(paid_social_spend) AS paid_social_spend,
    SUM(display_spend) AS display_spend,
    SUM(core_spend) AS total_core_spend,
    SUM(visitors) AS visitors_total,
    SUM(sessions) AS sessions_total,
    SUM(direct_subscriptions) AS direct_subs,
    SUM(paid_search_subscriptions) AS paid_search_subs,
    SUM(paid_social_subscriptions) AS paid_social_subs,
    SUM(display_subscriptions) AS display_subs,
    SUM(organic_search_subscriptions) AS organic_search_subs,
    SUM(social_subscriptions) AS social_subs,
    SUM(referral_subscriptions) AS referral_subs,
    SUM(email_subscriptions) AS email_subs,
    SUM(affiliate_subscriptions) AS affiliate_subs,
    SUM(other_subscriptions) AS other_subs,
    SUM(mixpanel_subscriptions) AS total_subs,
    SUM(enterprise_form_submissions) AS enterprise_form_submissions,
    SUM(new_subscribers) AS new_subscribers
FROM soundstripe_prod.core.dim_daily_kpis
WHERE date BETWEEN '2025-10-01' AND CURRENT_DATE()
GROUP BY 1
ORDER BY 1;

------------------------------------------------------------------------------------
-- q4: Channel-classifier audit — referrer NULL rate by channel × week
-- Result headline: Organic Search referrer-NULL rate dropped 47% pre → 34% post-cutover.
-- Suggests improved Referer header capture. Partially inflates Organic count via better classification but
-- does not zero-sum re-attribute Direct (which held flat).
------------------------------------------------------------------------------------
WITH base AS (
    SELECT DATE_TRUNC('week', session_started_at)::date AS week_start,
        last_channel_non_direct AS channel,
        session_id,
        CASE WHEN referrer IS NULL THEN 1 ELSE 0 END AS referrer_null,
        CASE WHEN referring_domain IS NULL THEN 1 ELSE 0 END AS rdom_null
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2025-10-01' AND CURRENT_DATE()
)
SELECT week_start, channel, COUNT(*) AS sessions,
    SUM(referrer_null) AS referrer_null_count,
    ROUND(SUM(referrer_null) / COUNT(*)::FLOAT * 100, 1) AS referrer_null_pct,
    ROUND(SUM(rdom_null) / COUNT(*)::FLOAT * 100, 1) AS rdom_null_pct
FROM base
GROUP BY 1, 2 ORDER BY 1, 2;

------------------------------------------------------------------------------------
-- q5: Branded vs non-branded organic split
-- Result: Branded ~250-300/wk stable. "no_referrer" Organic ~17-19K/wk stable.
-- "non_branded" (has referrer, no brand keyword): 21K pre → 33K post = +57% — drives the entire +25% organic uplift.
-- This is consistent with a real SEO mechanism (more search-engine referrals from non-branded queries).
------------------------------------------------------------------------------------
WITH base AS (
    SELECT DATE_TRUNC('week', session_started_at)::date AS week_start,
        session_id, distinct_id, referrer,
        CASE
            WHEN referrer ILIKE '%soundstripe%' THEN 'branded'
            WHEN referrer IS NOT NULL THEN 'non_branded'
            WHEN referring_domain IS NOT NULL AND referring_domain != '' THEN 'non_branded'
            ELSE 'no_referrer'
        END AS brand_bucket
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2025-10-01' AND CURRENT_DATE()
      AND last_channel_non_direct = 'Organic Search'
)
SELECT week_start, brand_bucket,
    COUNT(DISTINCT session_id) AS sessions,
    COUNT(DISTINCT distinct_id) AS visitors
FROM base GROUP BY 1, 2 ORDER BY 1, 2;

------------------------------------------------------------------------------------
-- q8: YoY anchor — same metrics for 2025-03-26 → 2025-04-13 vs 2026-03-26 → 2026-04-13
-- Result headline:
--   Organic Search: 2025 = 162,216 sessions over 19d (8,538/d). 2026 = 134,433 (7,075/d). YoY -17.1%
--   Direct: 2025 = 166,633 (8,770/d). 2026 = 138,209 (7,274/d). YoY -17.0%
-- 2026 organic is recovering from a Q1 trough (~38-40K/wk Jan-Feb 2026) but still below 2025 same-period.
------------------------------------------------------------------------------------
WITH yoy AS (
    SELECT
        CASE
            WHEN session_started_at::date BETWEEN '2025-03-26' AND '2025-04-13' THEN '2025'
            WHEN session_started_at::date BETWEEN '2026-03-26' AND '2026-04-13' THEN '2026'
        END AS year_label,
        last_channel_non_direct AS channel,
        CASE
            WHEN landing_page_host = 'www.soundstripe.com' THEN 'www'
            WHEN landing_page_host = 'app.soundstripe.com' THEN 'app'
            WHEN landing_page_host = 'soundstripe.com' THEN 'apex'
            ELSE 'other'
        END AS host_bucket,
        session_id, distinct_id
    FROM soundstripe_prod.core.fct_sessions
    WHERE (session_started_at::date BETWEEN '2025-03-26' AND '2025-04-13')
       OR (session_started_at::date BETWEEN '2026-03-26' AND '2026-04-13')
)
SELECT year_label, channel,
    COUNT(DISTINCT session_id) AS sessions_total,
    COUNT(DISTINCT distinct_id) AS visitors_total,
    SUM(CASE WHEN host_bucket = 'www' THEN 1 ELSE 0 END) AS sessions_www,
    SUM(CASE WHEN host_bucket = 'app' THEN 1 ELSE 0 END) AS sessions_app,
    SUM(CASE WHEN host_bucket = 'other' THEN 1 ELSE 0 END) AS sessions_other
FROM yoy WHERE year_label IS NOT NULL
GROUP BY 1, 2 ORDER BY 2, 1;

------------------------------------------------------------------------------------
-- q9: 04-17 spike substantiation — distribution-at-rollup × concentration on Direct
-- Result headline: 04-14→04-17 spike confirmed. APAC concentration jumped from 49% baseline to 78% in spike,
-- 8K/day → 21K/day Direct. Tail (04-18→04-24) at 12K/day still elevated above baseline.
-- Landing paths are NOT primarily /library/* — sessions land on root/non-library and enumerate library assets in events.
------------------------------------------------------------------------------------
WITH base AS (
    SELECT
        CASE
            WHEN session_started_at::date BETWEEN '2026-03-26' AND '2026-04-08' THEN 'A_baseline'
            WHEN session_started_at::date BETWEEN '2026-04-09' AND '2026-04-13' THEN 'B_pre_spike'
            WHEN session_started_at::date BETWEEN '2026-04-14' AND '2026-04-17' THEN 'C_spike'
            WHEN session_started_at::date BETWEEN '2026-04-18' AND '2026-04-24' THEN 'D_tail'
        END AS window_label,
        country, bounced_sessions, landing_page_path, session_id, distinct_id,
        CASE
            WHEN landing_page_path LIKE '%/library/sound-effects/%' THEN 'sfx_detail'
            WHEN landing_page_path LIKE '%/library/songs/%' THEN 'song_detail'
            WHEN landing_page_path LIKE '%/library/video%' THEN 'video_detail'
            WHEN landing_page_path LIKE '%/library/%' THEN 'library_other'
            ELSE 'non_library'
        END AS path_category
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2026-03-26' AND '2026-04-24'
      AND last_channel_non_direct = 'Direct'
)
SELECT window_label, path_category,
    COUNT(DISTINCT session_id) AS sessions,
    SUM(bounced_sessions) AS bounced,
    ROUND(SUM(bounced_sessions) / NULLIF(COUNT(DISTINCT session_id), 0) * 100, 1) AS bounce_pct,
    SUM(CASE WHEN country IN ('CN','SG','VN','HK','JP') THEN 1 ELSE 0 END) AS apac_sessions,
    SUM(CASE WHEN country IN ('DE','NL','CA') THEN 1 ELSE 0 END) AS shield_sessions,
    SUM(CASE WHEN country = 'US' THEN 1 ELSE 0 END) AS us_sessions
FROM base WHERE window_label IS NOT NULL
GROUP BY 1, 2 ORDER BY 1, 3 DESC;

------------------------------------------------------------------------------------
-- q10: New-page velocity — weekly count of distinct organic landing paths first-seen-in-week
-- Result headline: Pre-cutover ~600-800 new organic landing paths per week (declining trend Q1 2026).
-- Post-cutover: 5,000-7,000/week. Mostly mechanical (URL renames /pricing → /library/pricing) plus
-- some real new-page crawl. Caveat for findings: organic uplift is partly distributed across more entry points.
------------------------------------------------------------------------------------
WITH first_seen AS (
    SELECT landing_page_path,
        MIN(DATE_TRUNC('week', session_started_at)::date) AS first_week_seen
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2025-10-01' AND CURRENT_DATE()
      AND last_channel_non_direct = 'Organic Search'
      AND landing_page_host IN ('www.soundstripe.com', 'app.soundstripe.com', 'soundstripe.com')
    GROUP BY 1
)
SELECT first_week_seen AS week_start, COUNT(*) AS new_organic_landing_paths
FROM first_seen GROUP BY 1 ORDER BY 1;

------------------------------------------------------------------------------------
-- q12: Bounce + session-duration on organic landings
-- Result headline (host-blended): bounce 57% pre → 64% post (+7pp), pageviews 2.50 → 2.21 (-12%),
-- median duration 43s → 21s (host-blended).
-- Pre-cutover: www-organic 41% bounce / 3.20 pv, app-organic 67% / 2.06 pv (different page mixes).
-- Post-cutover www now contains both; mix shift explains most of the apparent quality decrease.
------------------------------------------------------------------------------------
SELECT DATE_TRUNC('week', session_started_at)::date AS week_start,
    CASE
        WHEN landing_page_host = 'www.soundstripe.com' THEN 'www'
        WHEN landing_page_host = 'app.soundstripe.com' THEN 'app'
        WHEN landing_page_host = 'soundstripe.com' THEN 'apex'
        ELSE 'other'
    END AS host_bucket,
    COUNT(DISTINCT session_id) AS organic_sessions,
    SUM(bounced_sessions) AS bounced,
    ROUND(SUM(bounced_sessions) / NULLIF(COUNT(DISTINCT session_id), 0) * 100, 1) AS bounce_pct,
    ROUND(AVG(session_duration_seconds), 1) AS avg_duration_sec,
    ROUND(MEDIAN(session_duration_seconds), 1) AS median_duration_sec,
    ROUND(AVG(pageviews), 2) AS avg_pageviews
FROM soundstripe_prod.core.fct_sessions
WHERE session_started_at::date BETWEEN '2025-10-01' AND CURRENT_DATE()
  AND last_channel_non_direct = 'Organic Search'
GROUP BY 1, 2 ORDER BY 1, 2;

------------------------------------------------------------------------------------
-- q14: Pre-vs-post summary roll-up — single table, six windows, per-channel
-- Headline numbers (organic search):
--   A_pre_recency (Jan 19 → Mar 4, 45d): 253,506 sessions = 5,633/d
--   B_contam1 (Mar 5-25, 21d): 124,216 sessions = 5,915/d (artifact-inflated)
--   C_post_clean (Mar 26 → Apr 13, 19d): 134,433 = 7,075/d → +25.6% vs A
--   D_contam2 (Apr 14-17, 4d): 32,524 = 8,131/d (likely artifact-inflated)
--   E_tail (Apr 18-24, 7d): 42,530 = 6,076/d → +7.9% vs A (slight tail slow-down)
--   F_yoy_2025 (Mar 26 → Apr 13 2025, 19d): 162,216 = 8,538/d → C is -17.1% YoY
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
    WHERE (session_started_at::date BETWEEN '2025-03-26' AND '2025-04-13')
       OR (session_started_at::date BETWEEN '2026-01-19' AND '2026-04-24')
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
------------------------------------------------------------------------------------
-- q16: Difference-in-differences (DID) — DoW-aligned YoY anchors
-- Replaces raw YoY (q14 F_yoy_2025) with a proper incrementality construct.
-- The original F_yoy was DoW-misaligned (2025-03-26 = Wed, 2026-03-26 = Thu); also raw YoY confounds
-- consolidation impact with 12-month company-state changes (paid ramp, content velocity, product mix).
-- DID controls for both: anchors 2026 against 2025 in BOTH the pre-cutover and post-cutover windows,
-- with DoW-matched 2025 windows (start dates aligned to same DoW as the 2026 windows).
--
-- Windows used:
--   A_2026_pre               2026-01-19 (Mon) → 2026-03-04 (Wed)  45d  -- pre-cutover 2026
--   A_2025_pre_dow_aligned   2025-01-20 (Mon) → 2025-03-05 (Wed)  45d  -- DoW-aligned to A_2026_pre
--   C_2026_post              2026-03-26 (Thu) → 2026-04-13 (Mon)  19d  -- post-cutover 2026 (clean)
--   C_2025_post_dow_aligned  2025-03-27 (Thu) → 2025-04-14 (Mon)  19d  -- DoW-aligned to C_2026_post
--
-- DID = (YoY ratio post) - (YoY ratio pre), expressed in pp.
--
-- Result headlines:
--   Organic Search sessions/day:   pre YoY −38.8%, post YoY −12.8%   → DID +26.0pp incremental
--   Organic Search visitors/day:   pre YoY −37.2%, post YoY +15.1%   → DID +52.3pp incremental (crossed zero)
--   Direct sessions/day:           pre YoY +1.7%,  post YoY −17.1%   → DID −18.8pp (consistent with attribution shift)
--   Paid Search sessions/day:      pre YoY −53.4%, post YoY −37.1%   → DID +16.3pp (closed gap, but at higher spend)
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
    WHERE (session_started_at::date BETWEEN '2025-01-20' AND '2025-04-14')
       OR (session_started_at::date BETWEEN '2026-01-19' AND '2026-04-13')
)
SELECT window_label, channel,
    COUNT(DISTINCT session_id) AS sessions,
    COUNT(DISTINCT distinct_id) AS visitors
FROM base WHERE window_label IS NOT NULL
GROUP BY 1, 2 ORDER BY 2, 1;

------------------------------------------------------------------------------------
-- q15: Identity check — fct_sessions.sessions vs dim_daily_kpis.sessions weekly
-- Result: sessions_fct == sessions_ddk for ALL weeks (delta_pct = 0). Identity check PASSES.
-- Visitors_fct < visitors_ddk by 7-16% (methodology divergence: fct_sessions uses post-consolidation profile_id,
-- dim_daily_kpis appears to count raw distinct_id). Not a fatal divergence; flag in findings.
------------------------------------------------------------------------------------
WITH fct AS (
    SELECT DATE_TRUNC('week', session_started_at)::date AS week_start,
        COUNT(DISTINCT session_id) AS sessions_fct,
        COUNT(DISTINCT distinct_id) AS visitors_fct
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2025-10-01' AND CURRENT_DATE()
    GROUP BY 1
), ddk AS (
    SELECT DATE_TRUNC('week', date)::date AS week_start,
        SUM(sessions) AS sessions_ddk, SUM(visitors) AS visitors_ddk
    FROM soundstripe_prod.core.dim_daily_kpis
    WHERE date BETWEEN '2025-10-01' AND CURRENT_DATE()
    GROUP BY 1
)
SELECT fct.week_start, fct.sessions_fct, ddk.sessions_ddk,
    ROUND((fct.sessions_fct - ddk.sessions_ddk) / NULLIF(ddk.sessions_ddk, 0)::FLOAT * 100, 2) AS sessions_delta_pct,
    fct.visitors_fct, ddk.visitors_ddk,
    ROUND((fct.visitors_fct - ddk.visitors_ddk) / NULLIF(ddk.visitors_ddk, 0)::FLOAT * 100, 2) AS visitors_delta_pct
FROM fct JOIN ddk ON fct.week_start = ddk.week_start ORDER BY 1;


