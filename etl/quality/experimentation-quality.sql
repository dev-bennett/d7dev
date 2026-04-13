-- Experimentation Data Quality Checks
-- Purpose: validate experiment data integrity in _external_statsig schema
-- Author: d7admin
-- Date: 2026-04-01
-- Dependencies: _external_statsig.statsig_clickstream_events_etl_output, core.fct_events

-- Q1: statsig_stable_id coverage in recent events
-- Expectation: >95% of app sessions should have a stable_id
SELECT session_started_at::date AS session_date
    ,COUNT(DISTINCT session_id) AS total_sessions
    ,COUNT(DISTINCT CASE WHEN statsig_stable_id IS NOT NULL THEN session_id END) AS sessions_with_stable_id
    ,ROUND(sessions_with_stable_id / NULLIF(total_sessions, 0) * 100, 1) AS coverage_pct
FROM soundstripe_prod.core.fct_sessions
WHERE session_started_at::date >= DATEADD('days', -7, CURRENT_DATE())
  AND landing_page_host = 'app.soundstripe.com'
GROUP BY 1
ORDER BY 1
;

-- Q2: clickstream ETL freshness
-- Expectation: max event_ts should be within 24 hours of current time
SELECT MAX(event_ts) AS latest_event
    ,DATEDIFF('hours', MAX(event_ts), CURRENT_TIMESTAMP()) AS hours_behind
FROM soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output
