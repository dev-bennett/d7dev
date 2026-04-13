with sessions as (select session_id,
                         distinct_id,
                         last_channel_non_direct as channel,
                         session_started_at::date as session_date,
                         browser
                  from soundstripe_prod.core.fct_sessions
                  where session_started_at::date between '2026-03-01' and dateadd(day, -1, current_date()))

select session_date,
       channel,
       count(distinct session_id) as sessions,
       count(distinct distinct_id) as visitors
from sessions
group by 1,2
order by 1,2
;

-- Q2: Browser distribution — spike days vs baseline
-- Spike days: 03/05, 03/17, 03/18, 03/19, 03/25
WITH sessions AS (
    SELECT session_id
        ,distinct_id
        ,last_channel_non_direct AS channel
        ,session_started_at::date AS session_date
        ,browser
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2026-03-01' AND DATEADD(DAY, -1, CURRENT_DATE())
)
,classified AS (
    SELECT *
        ,CASE
            WHEN session_date IN ('2026-03-05','2026-03-17','2026-03-18','2026-03-19','2026-03-25')
            THEN 'spike'
            ELSE 'baseline'
        END AS day_type
    FROM sessions
    WHERE channel = 'Direct'
)
SELECT day_type
    ,browser
    ,COUNT(DISTINCT session_id) AS sessions
    ,COUNT(DISTINCT distinct_id) AS visitors
    ,ROUND(sessions / visitors, 2) AS sessions_per_visitor
FROM classified
GROUP BY 1, 2
ORDER BY 1, 3 DESC
;

-- Q3: Daily Direct sessions by browser — isolate what's spiking
WITH sessions AS (
    SELECT session_id
        ,distinct_id
        ,last_channel_non_direct AS channel
        ,session_started_at::date AS session_date
        ,browser
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2026-03-01' AND DATEADD(DAY, -1, CURRENT_DATE())
      AND last_channel_non_direct = 'Direct'
)
SELECT session_date
    ,browser
    ,COUNT(DISTINCT session_id) AS sessions
    ,COUNT(DISTINCT distinct_id) AS visitors
FROM sessions
GROUP BY 1, 2
ORDER BY 1, 3 DESC
;

-- Q4: Landing page host + bounce rate for Chrome Direct on spike vs baseline
-- Purpose: determine if spike traffic is hitting a specific host (domain consolidation redirect target)
WITH sessions AS (
    SELECT session_id
        ,session_started_at::date AS session_date
        ,landing_page_host
        ,landing_page_path
        ,pageviews
        ,bounced_sessions
        ,country
        ,session_duration_seconds
        ,channel  -- raw entry channel (before last-non-direct override)
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2026-03-01' AND DATEADD(DAY, -1, CURRENT_DATE())
      AND last_channel_non_direct = 'Direct'
      AND browser = 'Chrome'
)
,classified AS (
    SELECT *
        ,CASE
            WHEN session_date IN ('2026-03-05','2026-03-17','2026-03-18','2026-03-19','2026-03-25')
            THEN 'spike'
            ELSE 'baseline'
        END AS day_type
    FROM sessions
)
SELECT day_type
    ,landing_page_host
    ,COUNT(DISTINCT session_id) AS sessions
    ,ROUND(AVG(pageviews), 2) AS avg_pageviews
    ,ROUND(SUM(bounced_sessions) / COUNT(DISTINCT session_id) * 100, 1) AS bounce_rate_pct
    ,ROUND(AVG(session_duration_seconds), 1) AS avg_duration_sec
FROM classified
GROUP BY 1, 2
ORDER BY 1, 3 DESC
;

-- Q5: Raw entry channel for spike-day Chrome Direct traffic
-- Purpose: check if these sessions have channel = NULL (true direct) or something else
--          before the last-non-direct override fills in 'Direct'
WITH sessions AS (
    SELECT session_id
        ,session_started_at::date AS session_date
        ,channel  -- raw entry channel
        ,last_channel_non_direct
        ,referring_domain
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date IN ('2026-03-05','2026-03-17','2026-03-18','2026-03-19','2026-03-25')
      AND last_channel_non_direct = 'Direct'
      AND browser = 'Chrome'
)
SELECT channel AS raw_entry_channel
    ,referring_domain
    ,COUNT(DISTINCT session_id) AS sessions
FROM sessions
GROUP BY 1, 2
ORDER BY 3 DESC
;

-- Q6: Country distribution — spike vs baseline Chrome Direct
-- Purpose: bot traffic often concentrates in unexpected geos
WITH sessions AS (
    SELECT session_id
        ,session_started_at::date AS session_date
        ,country
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2026-03-01' AND DATEADD(DAY, -1, CURRENT_DATE())
      AND last_channel_non_direct = 'Direct'
      AND browser = 'Chrome'
)
,classified AS (
    SELECT *
        ,CASE
            WHEN session_date IN ('2026-03-05','2026-03-17','2026-03-18','2026-03-19','2026-03-25')
            THEN 'spike'
            ELSE 'baseline'
        END AS day_type
    FROM sessions
)
SELECT day_type
    ,country
    ,COUNT(DISTINCT session_id) AS sessions
FROM classified
GROUP BY 1, 2
ORDER BY 1, 3 DESC
;

-- Q7: Correlate spike traffic with landing_page_host shift over time
-- Purpose: test whether www.soundstripe.com sessions surged when DNS moved to Fastly
-- and whether the geo shifted to Fastly shield POP locations (DE, NL, CA)
WITH sessions AS (
    SELECT session_id
        ,session_started_at::date AS session_date
        ,landing_page_host
        ,country
        ,bounced_sessions
        ,pageviews
        ,session_duration_seconds
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2026-03-01' AND DATEADD(DAY, -1, CURRENT_DATE())
      AND last_channel_non_direct = 'Direct'
      AND browser = 'Chrome'
)
SELECT session_date
    ,landing_page_host
    ,COUNT(DISTINCT session_id) AS sessions
    ,SUM(CASE WHEN country IN ('DE', 'NL', 'CA') THEN 1 ELSE 0 END) AS fastly_shield_geo_sessions
    ,ROUND(fastly_shield_geo_sessions / NULLIF(sessions, 0) * 100, 1) AS shield_geo_pct
    ,ROUND(AVG(pageviews), 2) AS avg_pageviews
    ,ROUND(SUM(bounced_sessions) / NULLIF(COUNT(DISTINCT session_id), 0) * 100, 1) AS bounce_rate_pct
    ,ROUND(AVG(session_duration_seconds), 1) AS avg_duration_sec
FROM sessions
GROUP BY 1, 2
HAVING sessions >= 10
ORDER BY 1, 3 DESC
;

-- Q8: Compare geo distribution for www.soundstripe.com Direct Chrome sessions
--     pre-consolidation (03/01-03/04) vs post-consolidation spikes
-- Purpose: if Fastly shield POPs are leaking IP into Mixpanel geo resolution,
--          DE/NL/CA share should jump dramatically post-cutover while real user
--          geos (US, etc.) drop proportionally
WITH sessions AS (
    SELECT session_id
        ,session_started_at::date AS session_date
        ,country
        ,CASE
            WHEN session_started_at::date BETWEEN '2026-03-01' AND '2026-03-04'
            THEN 'pre_consolidation'
            WHEN session_started_at::date IN ('2026-03-17','2026-03-18','2026-03-19')
            THEN 'peak_spike'
            ELSE 'other'
        END AS period
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2026-03-01' AND DATEADD(DAY, -1, CURRENT_DATE())
      AND last_channel_non_direct = 'Direct'
      AND browser = 'Chrome'
      AND landing_page_host = 'www.soundstripe.com'
)
SELECT period
    ,country
    ,COUNT(DISTINCT session_id) AS sessions
FROM sessions
WHERE period IN ('pre_consolidation', 'peak_spike')
GROUP BY 1, 2
ORDER BY 1, 3 DESC
;

-- Q9: March daily conversion rates — reported vs corrected (excluding consolidation artifacts)
-- Purpose: provide stakeholders with realistic Q1 conversion metrics
-- Contamination signature (broadened from v1):
--   Chrome + Direct + bounced + (www OR app landing host) + duration < 20s
--   during the known affected window (03/05-03/25)
--   No geo constraint — pre-rendering service and crawlers hit from multiple POPs
WITH sessions AS (
    SELECT session_id
        ,session_started_at::date AS session_date
        ,DATE_TRUNC('week', session_started_at::date) AS week_start
        ,CASE
            WHEN session_started_at::date BETWEEN '2026-03-05' AND '2026-03-25'
                AND browser = 'Chrome'
                AND last_channel_non_direct = 'Direct'
                AND landing_page_host IN ('www.soundstripe.com', 'app.soundstripe.com')
                AND bounced_sessions = 1
                AND session_duration_seconds <= 20
            THEN 1 ELSE 0
        END AS is_consolidation_artifact
        ,CASE WHEN signed_up > 0 THEN 1 ELSE 0 END AS has_signup
        ,CASE WHEN created_subscription > 0 THEN 1 ELSE 0 END AS has_subscription
        ,CASE WHEN GREATEST(NVL(single_song_purchase_count, 0), NVL(sfx_purchase_count, 0), NVL(market_purchase_count, 0)) > 0
            THEN 1 ELSE 0
        END AS has_transaction
    FROM soundstripe_prod.core.fct_sessions
    WHERE session_started_at::date BETWEEN '2026-03-01' AND '2026-03-31'
)
SELECT session_date

    -- Session counts
    ,COUNT(DISTINCT session_id) AS reported_sessions
    ,COUNT(DISTINCT CASE WHEN is_consolidation_artifact = 0 THEN session_id END) AS corrected_sessions
    ,SUM(is_consolidation_artifact) AS excluded_sessions

    -- Signups
    ,SUM(has_signup) AS reported_signups
    ,SUM(CASE WHEN is_consolidation_artifact = 0 THEN has_signup ELSE 0 END) AS corrected_signups

    -- Subscribing sessions
    ,SUM(has_subscription) AS reported_subscriptions
    ,SUM(CASE WHEN is_consolidation_artifact = 0 THEN has_subscription ELSE 0 END) AS corrected_subscriptions

    -- Transacting sessions
    ,SUM(has_transaction) AS reported_transactions
    ,SUM(CASE WHEN is_consolidation_artifact = 0 THEN has_transaction ELSE 0 END) AS corrected_transactions

    -- Conversion rates — reported
    ,ROUND(SUM(has_signup) / NULLIF(COUNT(DISTINCT session_id), 0) * 100, 3) AS reported_signup_rate
    ,ROUND(SUM(has_subscription) / NULLIF(COUNT(DISTINCT session_id), 0) * 100, 3) AS reported_sub_cvr
    ,ROUND(SUM(has_transaction) / NULLIF(COUNT(DISTINCT session_id), 0) * 100, 3) AS reported_txn_cvr

    -- Conversion rates — corrected
    ,ROUND(SUM(CASE WHEN is_consolidation_artifact = 0 THEN has_signup ELSE 0 END)
        / NULLIF(COUNT(DISTINCT CASE WHEN is_consolidation_artifact = 0 THEN session_id END), 0) * 100, 3) AS corrected_signup_rate
    ,ROUND(SUM(CASE WHEN is_consolidation_artifact = 0 THEN has_subscription ELSE 0 END)
        / NULLIF(COUNT(DISTINCT CASE WHEN is_consolidation_artifact = 0 THEN session_id END), 0) * 100, 3) AS corrected_sub_cvr
    ,ROUND(SUM(CASE WHEN is_consolidation_artifact = 0 THEN has_transaction ELSE 0 END)
        / NULLIF(COUNT(DISTINCT CASE WHEN is_consolidation_artifact = 0 THEN session_id END), 0) * 100, 3) AS corrected_txn_cvr

FROM sessions
GROUP BY 1
ORDER BY 1