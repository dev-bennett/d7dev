-- PURPOSE:       Bridge fct_events and fct_sessions via dim_session_mapping. fct_events.session_id and fct_sessions.session_id do NOT join directly.
-- TABLES:        soundstripe_prod.core.fct_events, soundstripe_prod.core.dim_session_mapping, soundstripe_prod.core.fct_sessions
-- PARAMETERS:    :start_date, :end_date (event date range), additional event/session filters as needed
-- PRIOR USES:    Pattern encoded in memory reference_session_event_join; repeats across fct_events-joined analyses
-- RATE BLOCK:    n/a (bridge template — layer rate logic on top)
-- LAST UPDATED:  2026-04-24

-- Column reality check (confirmed 2026-04-24):
--   dim_session_mapping: SESSION_ID, DISTINCT_ID, SESSION_STARTED_AT, SESSION_ID_EVENTS
--   The event-side key is SESSION_ID_EVENTS; the session-side key is SESSION_ID.

WITH events AS (
    SELECT
        e.session_id    AS event_session_id
      , e.distinct_id
      , e.user_id
      , e.event_ts
      , e.event
      , e.url
    FROM soundstripe_prod.core.fct_events e
    WHERE e.event_ts >= :start_date
      AND e.event_ts <  :end_date
)

, bridged AS (
    SELECT
        ev.*
      , m.session_id  AS session_id  -- fct_sessions-compatible session_id
    FROM events ev
    LEFT JOIN soundstripe_prod.core.dim_session_mapping m
      ON m.session_id_events = ev.event_session_id
)

SELECT
    b.*
  , s.session_started_at
  , s.session_ended_at
  , s.session_duration_seconds
  , s.channel
  , s.utm_source
  , s.utm_medium
  , s.utm_campaign
FROM bridged b
LEFT JOIN soundstripe_prod.core.fct_sessions s
  ON s.session_id = b.session_id
LIMIT 100;

-- Join-type discipline: LEFT JOIN preserves the event population (the left side).
-- If you need the session population as the denominator, swap the driving CTE — do NOT
-- just flip LEFT to INNER after the fact. The JOIN type IS the denominator (sql-snowflake.md §1).
