-- PURPOSE:       Funnel step-rate template with explicit population nesting. Step N population is a subset of step N-1 by construction.
-- TABLES:        <any event-grain table, e.g. fct_events>
-- PARAMETERS:    :start_date, :end_date; adapt step CTE predicates to the funnel
-- PRIOR USES:    2026-04-18-wcpm-test-audit (post-nesting fix); any funnel step-rate work after feedback_population_nesting_in_step_rates
-- RATE BLOCK:    below
-- LAST UPDATED:  2026-04-24
--
-- WHY THIS TEMPLATE EXISTS:
--   Independent `SELECT DISTINCT` CTEs per step do NOT nest automatically. Two step CTEs that happen to share
--   (window, user) do not guarantee step N's users are a subset of step N-1's users. If you compute step rates
--   as (step N distinct users / step N-1 distinct users) without enforcing subset, the ratio can exceed 1.0
--   or silently inflate.
--
-- ENFORCEMENT: each step CTE below INNER JOINs the prior step's CTE on (window, user). That makes the nesting
-- a hard SQL constraint, not a semantic assumption. See sql-snowflake.md STEP NESTING AUDIT.

-- RATE: step_2_rate
--   NUMERATOR:   distinct (window, user) reaching step 2
--   DENOMINATOR: distinct (window, user) reaching step 1 (INNER JOIN enforces subset)
--   TYPE:        users_at_step_2 / users_at_step_1
--   NOT:         all_users_in_window (that would inflate the denominator beyond the funnel entry)

WITH step_1 AS (
    SELECT DISTINCT
        DATE_TRUNC('week', event_ts)       AS window_start
      , distinct_id
    FROM soundstripe_prod.core.fct_events
    WHERE event_ts >= :start_date
      AND event_ts <  :end_date
      AND event = 'viewed pricing'         -- step 1 predicate
)

, step_2 AS (
    SELECT DISTINCT
        DATE_TRUNC('week', e.event_ts)     AS window_start
      , e.distinct_id
    FROM soundstripe_prod.core.fct_events e
    INNER JOIN step_1 s1                   -- ENFORCES NESTING: step 2 ⊆ step 1
      ON DATE_TRUNC('week', e.event_ts) = s1.window_start
     AND e.distinct_id               = s1.distinct_id
    WHERE e.event_ts >= :start_date
      AND e.event_ts <  :end_date
      AND e.event = 'clicked subscribe'    -- step 2 predicate
)

-- Step 3, step 4, ... follow the same pattern: INNER JOIN to the prior step's CTE on (window_start, distinct_id).

SELECT
    s1.window_start
  , COUNT(DISTINCT s1.distinct_id)                                                       AS users_step_1
  , COUNT(DISTINCT s2.distinct_id)                                                       AS users_step_2
  , COUNT(DISTINCT s2.distinct_id) / NULLIF(COUNT(DISTINCT s1.distinct_id), 0)           AS step_2_rate
FROM step_1 s1
LEFT JOIN step_2 s2
  USING (window_start, distinct_id)
GROUP BY 1
ORDER BY 1
LIMIT 100;

-- STEP NESTING AUDIT:
--   Step 1 population: (week, distinct_id) who fired 'viewed pricing' in [start, end)
--   Step 2 population: (week, distinct_id) who fired 'clicked subscribe' AND were in step 1 (INNER JOIN)
--   Is step 2 a subset of step 1? YES — enforced by INNER JOIN on (window_start, distinct_id)
--   RESULT: PASS
