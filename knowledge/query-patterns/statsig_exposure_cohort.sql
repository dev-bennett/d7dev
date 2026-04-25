-- PURPOSE:       Canonical exposed-user cohort pull for a Statsig experiment, with 1:1 identifier mapping and stable_id-sprawl exclusions applied.
-- TABLES:        soundstripe_prod._external_statsig.exposures
-- PARAMETERS:    :experiment_id (e.g. 'wcpm_pricing_test'), :start_date, :end_date
-- PRIOR USES:    2026-04-18-wcpm-test-audit (Findings 4 + 6); any future Statsig pulse-replication work
-- RATE BLOCK:    n/a (cohort pull — layer metric logic on top)
-- LAST UPDATED:  2026-04-24
--
-- Read `knowledge/domains/experimentation/identifier-mapping-and-exclusions.md` before modifying the exclusion logic.
-- The two OPEN issues this pattern encodes:
--   (a) project_statsig_model_late_arrival_open — fct_events rows with event_ts older than the incremental watermark
--       are dropped by statsig_clickstream_events_etl_output. Use EXPOSURES directly, not the ETL output, for first exposure.
--   (b) project_wcpm_1to1_mapping_exclusion  — enforced 1:1 + post-consolidation stable_id sprawl drops ~13.5% of
--       exposed user_ids from Pulse. The filter below keeps a single (user_id, experiment_id) pair by first exposure.

-- Confirmed schema (2026-04-24):
--   exposures: EXPERIMENT_ID, GROUP_ID, GROUP_NAME, USER_ID, STABLE_ID, TIMESTAMP, USER_DIMENSIONS (VARIANT)

WITH raw_exposures AS (
    SELECT
        e.experiment_id
      , e.group_id
      , e.group_name
      , e.user_id
      , e.stable_id
      , e.timestamp                       AS exposure_ts
    FROM soundstripe_prod._external_statsig.exposures e
    WHERE e.experiment_id = :experiment_id
      AND e.timestamp >= :start_date
      AND e.timestamp <  :end_date
)

-- First exposure per user_id (resolves stable_id sprawl — one user_id, one assignment)
, first_exposure_per_user AS (
    SELECT
        r.*
      , ROW_NUMBER() OVER (
          PARTITION BY r.user_id, r.experiment_id
          ORDER BY r.exposure_ts ASC
        )                                 AS exposure_rn
    FROM raw_exposures r
    WHERE r.user_id IS NOT NULL
)

SELECT
    experiment_id
  , user_id
  , stable_id
  , group_id
  , group_name
  , exposure_ts
FROM first_exposure_per_user
WHERE exposure_rn = 1
LIMIT 100;

-- Contract:
--   POSTCONDITION: (user_id, experiment_id) is unique in the result set
--   POSTCONDITION: user_id is never NULL
--   INVARIANT: group assignment is first-exposure-wins, not most-recent
