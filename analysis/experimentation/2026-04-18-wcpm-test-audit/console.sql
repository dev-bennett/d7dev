-- WCPM Pricing Test Audit -- validation queries
-- Author: Devon / Claude
-- Date: 2026-04-18
-- Purpose: Reconcile Mixpanel's 27 add-on purchases vs. Statsig's 12 (4 existing + 8 new)
-- Dependencies:
--   - pc_stitch_db.mixpanel.export (raw Mixpanel)
--   - soundstripe_prod.core.fct_events (dbt transform)
--   - soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output (Statsig sync)
--   - soundstripe_prod.core.subscription_periods (join used in the Statsig model)
-- Window (canonical per Q4a): 2026-03-13 to 2026-04-18
-- Key prior artifact: context/dbt/models/marts/_external_statsig/statsig_clickstream_events_etl_output.sql lines 103-106

-- ============================================================
-- q0: Schema probe -- confirm column names on pc_stitch_db.mixpanel.export
-- Purpose: Stitch may flatten Mixpanel properties into top-level columns
-- with different names (or keep them inside a VARIANT). Run this once to
-- confirm every column q1+ references actually exists. If a column isn't
-- top-level, it's likely under the `properties` VARIANT and needs
-- properties:"<name>"::string access.
-- ============================================================
SHOW COLUMNS IN TABLE pc_stitch_db.mixpanel.export;

-- Alternative probe -- single sample row of a Purchased Add-on event so we
-- can eyeball all field locations:
SELECT *
FROM pc_stitch_db.mixpanel.export
WHERE event = 'Purchased Add-on'
  AND event_created::date BETWEEN '2026-03-13' AND '2026-04-18'
LIMIT 1;

-- ============================================================
-- q1: Baseline -- raw Mixpanel WCPM add-on purchases, weekly bucketing
-- Reproduces Meredith's Mixpanel report shape. Three filter variants to
-- expose which one matches her "27" (plan slug vs. add-on name).
-- ============================================================
WITH mp_raw AS (
    SELECT
         a.__sdc_primary_key
        ,a.event_created::timestamp                                               AS event_ts
        ,a.distinct_id
        ,a.statsig_stable_id
        ,a.current_plan_id
        ,a.current_addons
    FROM pc_stitch_db.mixpanel.export a
    WHERE a.event = 'Purchased Add-on'
      AND a.event_created::date BETWEEN '2026-03-13' AND '2026-04-18'
)
SELECT
     DATE_TRUNC('week', event_ts)                                                 AS play_week
    ,COUNT(DISTINCT distinct_id)                                                  AS uniques_all_addons
    ,COUNT(DISTINCT CASE WHEN current_plan_id IN (
            'warner-chappell-production-music-monthly-usd'
           ,'warner-chappell-production-music-yearly-usd') THEN distinct_id END)  AS uniques_wcpm_only_by_plan
    ,COUNT(DISTINCT CASE WHEN current_addons ILIKE '%warner%' THEN distinct_id END) AS uniques_wcpm_by_addon_name
    ,COUNT(*)                                                                     AS row_count
FROM mp_raw
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- q2: Window-total baseline (same filters as q1, single row)
-- Target: one of these columns equals 27 -- that confirms the Mixpanel side.
-- Also reports statsig_stable_id fill rate (Q5a validation).
-- ============================================================
SELECT
     COUNT(*)                                                                     AS total_events
    ,COUNT(DISTINCT a.distinct_id)                                                AS distinct_users_all_addons
    ,COUNT(DISTINCT CASE WHEN a.current_plan_id IN (
            'warner-chappell-production-music-monthly-usd'
           ,'warner-chappell-production-music-yearly-usd') THEN a.distinct_id END) AS distinct_users_wcpm_plan_filter
    ,COUNT(DISTINCT CASE WHEN a.current_addons ILIKE '%warner%' THEN a.distinct_id END) AS distinct_users_wcpm_addon_filter
    ,COUNT(DISTINCT CASE WHEN a.statsig_stable_id IS NOT NULL THEN a.distinct_id END) AS distinct_users_with_stable_id
    ,ROUND(SUM(CASE WHEN a.statsig_stable_id IS NOT NULL THEN 1 ELSE 0 END) * 100.0 / COUNT(*), 2) AS stable_id_fill_rate_pct
FROM pc_stitch_db.mixpanel.export a
WHERE a.event = 'Purchased Add-on'
  AND a.event_created::date BETWEEN '2026-03-13' AND '2026-04-18';

-- ============================================================
-- q3: Add-on composition -- is WCPM the only add-on in-flight?
-- If other add-ons exist, the dbt model's 12 includes them (no WCPM filter
-- on the add_on_purchase_* columns), making the 12 vs. 27 comparison
-- apples-to-oranges.
-- ============================================================
SELECT
     a.current_addons
    ,COUNT(*)                                                                     AS events
    ,COUNT(DISTINCT a.distinct_id)                                                AS distinct_users
FROM pc_stitch_db.mixpanel.export a
WHERE a.event = 'Purchased Add-on'
  AND a.event_created::date BETWEEN '2026-03-13' AND '2026-04-18'
GROUP BY 1
ORDER BY events DESC;

-- ============================================================
-- q4: Reproduce Statsig's 12 from the dbt model output
-- Target: existing_sub_addons=4, new_sub_addons=8, total=12.
-- Also surfaces distinct stable_id count + any null-stable_id add-on rows.
-- ============================================================
SELECT
     SUM(a.add_on_purchase_total)                                                 AS total_addon_purchases
    ,SUM(a.add_on_purchase_existing_sub)                                          AS existing_sub_addons
    ,SUM(a.add_on_purchase_new_sub)                                               AS new_sub_addons
    ,COUNT(DISTINCT CASE WHEN a.add_on_purchase_total = 1 THEN a.distinct_id END) AS distinct_users
    ,COUNT(DISTINCT CASE WHEN a.add_on_purchase_total = 1 THEN a.statsig_stable_id END) AS distinct_stable_ids
    ,SUM(CASE WHEN a.add_on_purchase_total = 1 AND a.statsig_stable_id IS NULL THEN 1 ELSE 0 END) AS addon_rows_missing_stable_id
FROM soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output a
WHERE a.event = 'Purchased Add-on'
  AND a.event_ts::date BETWEEN '2026-03-13' AND '2026-04-18';

-- ============================================================
-- q5: Validate Existing-vs-New labeling (potential inversion bug)
-- Model logic (lines 103-106 of statsig_clickstream_events_etl_output.sql):
--   existing_sub = 1 WHEN abs(diff(event_ts, subscription_period.START_DATE)) < 1 hour
--   new_sub      = total - existing_sub
-- Reading: "existing_sub=1" fires when subscription started ~simultaneously
-- with the add-on -- that semantically describes a NEW subscriber, not an
-- existing one. Expected if the labels are inverted:
--   For existing_sub=1 rows: min/avg/median hours_since_sub_start ~ 0
--   For new_sub=1 rows:      min/avg/median hours_since_sub_start >> 0
-- Expected if the labels are correct, my read is wrong:
--   For existing_sub=1 rows: hours_since_sub_start > 0 (old subscriptions)
-- ============================================================
SELECT
     a.add_on_purchase_existing_sub                                               AS flagged_existing
    ,a.add_on_purchase_new_sub                                                    AS flagged_new
    ,COUNT(*)                                                                     AS row_count
    ,MIN(DATEDIFF('hours', f.start_date::timestamp, a.event_ts))                  AS min_hrs_since_sub_start
    ,AVG(DATEDIFF('hours', f.start_date::timestamp, a.event_ts))                  AS avg_hrs_since_sub_start
    ,MEDIAN(DATEDIFF('hours', f.start_date::timestamp, a.event_ts))               AS median_hrs_since_sub_start
    ,MAX(DATEDIFF('hours', f.start_date::timestamp, a.event_ts))                  AS max_hrs_since_sub_start
FROM soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output a
    LEFT JOIN soundstripe_prod.core.subscription_periods f
        ON a.current_subscription_id = f.soundstripe_subscription_id
WHERE a.event = 'Purchased Add-on'
  AND a.event_ts::date BETWEEN '2026-03-13' AND '2026-04-18'
GROUP BY 1, 2
ORDER BY 1 DESC, 2 DESC;

-- ============================================================
-- q6: Fan-out check on the subscription_periods join in the Statsig model
-- Join in the model has only ON a.current_subscription_id = f.soundstripe_subscription_id
-- with no period-selection predicate. Subscriptions with >1 period (renewals)
-- may produce multiple rows per add-on event.
-- If COUNT(*)>1 for any __sdc_primary_key, totals in q4 are inflated by fan-out.
-- ============================================================
SELECT
     a.__sdc_primary_key
    ,COUNT(*)                                                                     AS row_count_in_model
FROM soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output a
WHERE a.event = 'Purchased Add-on'
  AND a.event_ts::date BETWEEN '2026-03-13' AND '2026-04-18'
GROUP BY 1
HAVING COUNT(*) > 1
ORDER BY row_count_in_model DESC;

-- ============================================================
-- q7: End-to-end survival -- Mixpanel -> fct_events -> Statsig model
-- For each Mixpanel Purchased Add-on event in the window, bucket by where
-- in the pipeline it stops. Numerators should total the q2 Mixpanel count.
-- Buckets:
--   1_mixpanel_only_dropped_at_fct_events -- event in raw Mixpanel but not in fct_events
--   2_fct_events_but_not_in_statsig_model -- in fct_events but not in Statsig model
--   3_in_all_three                        -- made it through fully
-- ============================================================
WITH mp_addon AS (
    SELECT
         a.__sdc_primary_key
        ,a.distinct_id
        ,a.statsig_stable_id
        ,a.current_plan_id
    FROM pc_stitch_db.mixpanel.export a
    WHERE a.event = 'Purchased Add-on'
      AND a.event_created::date BETWEEN '2026-03-13' AND '2026-04-18'
),
fct_addon AS (
    SELECT DISTINCT
         b.__sdc_primary_key
    FROM soundstripe_prod.core.fct_events b
    WHERE b.event = 'Purchased Add-on'
      AND b.event_ts::date BETWEEN '2026-03-13' AND '2026-04-18'
),
statsig_addon AS (
    SELECT DISTINCT
         c.__sdc_primary_key
    FROM soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output c
    WHERE c.event = 'Purchased Add-on'
      AND c.event_ts::date BETWEEN '2026-03-13' AND '2026-04-18'
)
SELECT
     CASE
        WHEN f.__sdc_primary_key IS NULL                                        THEN '1_mixpanel_only_dropped_at_fct_events'
        WHEN s.__sdc_primary_key IS NULL                                        THEN '2_fct_events_but_not_in_statsig_model'
        ELSE                                                                         '3_in_all_three'
     END                                                                          AS bucket
    ,COUNT(*)                                                                     AS events
    ,COUNT(DISTINCT m.distinct_id)                                                AS distinct_users
    ,COUNT(DISTINCT CASE WHEN m.current_plan_id IN (
            'warner-chappell-production-music-monthly-usd'
           ,'warner-chappell-production-music-yearly-usd') THEN m.distinct_id END) AS distinct_users_wcpm_plan_only
FROM mp_addon m
    LEFT JOIN fct_addon       f ON m.__sdc_primary_key = f.__sdc_primary_key
    LEFT JOIN statsig_addon   s ON m.__sdc_primary_key = s.__sdc_primary_key
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- q8a: Hunt for the Statsig exposures table in soundstripe_prod.
-- Looks across information_schema for any table/view whose name references
-- statsig, exposures, or experiments.
-- ============================================================
SELECT table_catalog, table_schema, table_name, table_type, row_count
FROM soundstripe_prod.information_schema.tables
WHERE LOWER(table_name) LIKE '%statsig%'
   OR LOWER(table_name) LIKE '%exposure%'
   OR LOWER(table_name) LIKE '%experiment%'
ORDER BY table_schema, table_name;

-- ============================================================
-- q8b: Same hunt across pc_stitch_db (in case Statsig reverse-syncs via Stitch).
-- ============================================================
SELECT table_catalog, table_schema, table_name, table_type, row_count
FROM pc_stitch_db.information_schema.tables
WHERE LOWER(table_name) LIKE '%statsig%'
   OR LOWER(table_name) LIKE '%exposure%'
   OR LOWER(table_name) LIKE '%experiment%'
ORDER BY table_schema, table_name;

-- Exposures table confirmed via context/lookml/views/Statsig/exposures.view.lkml:
--   soundstripe_prod._external_statsig.exposures
--   columns: experiment_id, group_id, group_name, stable_id, timestamp,
--            user_id, user_dimensions
--   LookML dedup pattern: first exposure per (stable_id, experiment_id) by timestamp asc

-- ============================================================
-- q9a: Column structure of the exposures table (confirm names / types before joining)
-- ============================================================
SHOW COLUMNS IN TABLE soundstripe_prod._external_statsig.exposures;

-- ============================================================
-- q9b: One sample row, scoped to wcpm_pricing_test, to eyeball actual values
-- ============================================================
SELECT *
FROM soundstripe_prod._external_statsig.exposures
WHERE LOWER(experiment_id) = 'wcpm_pricing_test'
LIMIT 1;

-- ============================================================
-- q9c: Experiment-window scoped count -- should roughly match 18,224 exposed units
-- across the three arms from the pulse CSV. Minor deviation possible if the
-- Statsig console filters for bots differently than the raw table.
-- ============================================================
SELECT
     COUNT(*)                                                                     AS total_exposure_events
    ,COUNT(DISTINCT stable_id)                                                    AS distinct_exposed_stable_ids
FROM soundstripe_prod._external_statsig.exposures
WHERE LOWER(experiment_id) = 'wcpm_pricing_test'
  AND timestamp::date BETWEEN '2026-03-13' AND '2026-04-18';

-- ============================================================
-- q9d: Per-arm distinct exposed stable_ids.
-- Target: Control 6,115 / Mid Reduction 5,972 / Deep Reduction 6,137 (pulse CSV).
-- ============================================================
SELECT
     LOWER(group_name)                                                            AS arm
    ,COUNT(DISTINCT stable_id)                                                    AS distinct_exposed_stable_ids
FROM soundstripe_prod._external_statsig.exposures
WHERE LOWER(experiment_id) = 'wcpm_pricing_test'
  AND timestamp::date BETWEEN '2026-03-13' AND '2026-04-18'
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- q10: DEPRECATED -- joined against raw `exposures` table, which includes
-- ~10K exposures per arm that Statsig's pulse filters out (bot / dedup /
-- unit-quality). q10 sum reconciles (22 rows) but per-arm inflated ~50%.
-- Superseded by q12 which uses first_exposures_wcpm_pricing_test (18,224
-- rows, exact arm-size match to the pulse CSV).
-- ============================================================

SELECT CURRENT_USER(), CURRENT_ROLE(), CURRENT_WAREHOUSE();
SHOW GRANTS TO USER DEVONB;
USE ROLE TRANSFORMER;
SHOW GRANTS ON TABLE "first_exposures_wcpm_pricing_test";

-- ============================================================
-- q11a: Column structure of the per-experiment first-exposures table.
-- ============================================================
SHOW COLUMNS IN TABLE "first_exposures_wcpm_pricing_test";

-- ============================================================
-- q11b: Sample row to confirm column semantics.
-- ============================================================
SELECT *
FROM soundstripe_prod._external_statsig."first_exposures_wcpm_pricing_test"
LIMIT 1;

-- ============================================================
-- q11c: Per-arm confirm -- distinct unit_ids by arm.
-- Structural notes from q11a/q11b:
--   - Table identifier is lowercase -- must be double-quoted
--   - Join key on the events side (statsig_stable_id) maps to UNIT_ID here,
--     not STABLE_ID (that column doesn't exist on this table)
--   - No GROUP_NAME column; resolve arm name via GROUP_ID lookup from the
--     raw exposures table
-- Target (pulse CSV): Control 6,115 / Mid Reduction 5,972 / Deep Reduction 6,137
-- ============================================================
WITH group_lookup AS (
    SELECT DISTINCT group_id, LOWER(group_name) AS arm
    FROM soundstripe_prod._external_statsig.exposures
    WHERE LOWER(experiment_id) = 'wcpm_pricing_test'
)
SELECT
     COALESCE(gl.arm, '<unmapped:' || fe.group_id || '>')                         AS arm
    ,COUNT(DISTINCT fe.unit_id)                                                   AS distinct_exposed_unit_ids
    ,COUNT(*)                                                                     AS rows_in_table
FROM soundstripe_prod._external_statsig."first_exposures_wcpm_pricing_test" fe
    LEFT JOIN group_lookup gl ON fe.group_id = gl.group_id
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- q12: Final decomposition using the pulse-aligned exposures table.
-- Joins the 22 Statsig-model add-on rows to first_exposures on UNIT_ID
-- and resolves arm name via a GROUP_ID lookup from the raw exposures table.
-- Target: per-arm add-on rows exactly match the pulse CSV
--   Control:        2 (1 existing + 1 new)
--   Mid Reduction:  8 (3 existing + 5 new)
--   Deep Reduction: 2 (0 existing + 2 new)
--   not_exposed:    10 (residual that closes 22 -> 12)
-- ============================================================
WITH statsig_addon_rows AS (
    SELECT
         a.__sdc_primary_key
        ,a.event_ts
        ,a.distinct_id
        ,a.statsig_stable_id
        ,a.add_on_purchase_total
        ,a.add_on_purchase_existing_sub
        ,a.add_on_purchase_new_sub
    FROM soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output a
    WHERE a.event = 'Purchased Add-on'
      AND a.event_ts::date BETWEEN '2026-03-13' AND '2026-04-18'
),
group_lookup AS (
    SELECT DISTINCT group_id, LOWER(group_name) AS arm
    FROM soundstripe_prod._external_statsig.exposures
    WHERE LOWER(experiment_id) = 'wcpm_pricing_test'
)
SELECT
     COALESCE(gl.arm, 'not_exposed')                                              AS arm_or_missing
    ,SUM(sa.add_on_purchase_total)                                                AS addon_rows
    ,SUM(sa.add_on_purchase_existing_sub)                                         AS existing_sub_rows
    ,SUM(sa.add_on_purchase_new_sub)                                              AS new_sub_rows
    ,COUNT(DISTINCT sa.statsig_stable_id)                                         AS distinct_stable_ids
FROM statsig_addon_rows sa
    LEFT JOIN soundstripe_prod._external_statsig."first_exposures_wcpm_pricing_test" fe
        ON sa.statsig_stable_id = fe.unit_id
    LEFT JOIN group_lookup gl
        ON fe.group_id = gl.group_id
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- q13: Same as q12 but enforces Statsig's attribution rule --
-- add-on event must occur at or after first_exposure to count as exposed.
-- Hypothesis: q12 over-attributes by 2 units because users who purchased
-- BEFORE being exposed are currently folded into their eventual arm.
-- Target: Control 2 / Mid 8 / Deep 2 / not_exposed 10 (exact pulse match)
-- Deltas vs. q12 will be +2 in not_exposed, -1 each in Mid and Deep existing_sub.
-- ============================================================
WITH statsig_addon_rows AS (
    SELECT
         a.__sdc_primary_key
        ,a.event_ts
        ,a.distinct_id
        ,a.statsig_stable_id
        ,a.add_on_purchase_total
        ,a.add_on_purchase_existing_sub
        ,a.add_on_purchase_new_sub
    FROM soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output a
    WHERE a.event = 'Purchased Add-on'
      AND a.event_ts::date BETWEEN '2026-03-13' AND '2026-04-18'
),
group_lookup AS (
    SELECT DISTINCT group_id, LOWER(group_name) AS arm
    FROM soundstripe_prod._external_statsig.exposures
    WHERE LOWER(experiment_id) = 'wcpm_pricing_test'
)
SELECT
     COALESCE(gl.arm, 'not_exposed')                                              AS arm_or_missing
    ,SUM(sa.add_on_purchase_total)                                                AS addon_rows
    ,SUM(sa.add_on_purchase_existing_sub)                                         AS existing_sub_rows
    ,SUM(sa.add_on_purchase_new_sub)                                              AS new_sub_rows
    ,COUNT(DISTINCT sa.statsig_stable_id)                                         AS distinct_stable_ids
FROM statsig_addon_rows sa
    LEFT JOIN soundstripe_prod._external_statsig."first_exposures_wcpm_pricing_test" fe
        ON sa.statsig_stable_id = fe.unit_id
        AND fe.first_exposure <= sa.event_ts
    LEFT JOIN group_lookup gl
        ON fe.group_id = gl.group_id
GROUP BY 1
ORDER BY 1;

-- ============================================================
-- q14: Row-level diagnostic for the 2 suspect units.
-- Shows for every in-model add-on row: purchase time, first_exposure time,
-- and whether the exposure preceded the purchase. Use this to confirm
-- exactly which stable_ids are moving between buckets between q12 and q13.
-- ============================================================
WITH statsig_addon_rows AS (
    SELECT
         a.__sdc_primary_key
        ,a.event_ts                                                               AS purchase_ts
        ,a.distinct_id
        ,a.statsig_stable_id
        ,a.add_on_purchase_existing_sub
        ,a.add_on_purchase_new_sub
    FROM soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output a
    WHERE a.event = 'Purchased Add-on'
      AND a.event_ts::date BETWEEN '2026-03-13' AND '2026-04-18'
),
group_lookup AS (
    SELECT DISTINCT group_id, LOWER(group_name) AS arm
    FROM soundstripe_prod._external_statsig.exposures
    WHERE LOWER(experiment_id) = 'wcpm_pricing_test'
)
SELECT
     sa.statsig_stable_id
    ,sa.purchase_ts
    ,fe.first_exposure
    ,DATEDIFF('minutes', fe.first_exposure, sa.purchase_ts)                       AS mins_purchase_after_exposure
    ,CASE
        WHEN fe.unit_id IS NULL                          THEN 'never_exposed'
        WHEN fe.first_exposure <= sa.purchase_ts         THEN 'exposed_before_purchase'
        ELSE                                                  'exposed_after_purchase'
     END                                                                          AS attribution_bucket
    ,gl.arm
    ,sa.add_on_purchase_existing_sub                                              AS flagged_existing
    ,sa.add_on_purchase_new_sub                                                   AS flagged_new
FROM statsig_addon_rows sa
    LEFT JOIN soundstripe_prod._external_statsig."first_exposures_wcpm_pricing_test" fe
        ON sa.statsig_stable_id = fe.unit_id
    LEFT JOIN group_lookup gl
        ON fe.group_id = gl.group_id
ORDER BY attribution_bucket, gl.arm, sa.purchase_ts;

-- ============================================================
-- q15 + q16: OBSOLETE. These were written to diagnose a 4-unit gap in
-- the 03-13 -> 03-15 slice that turned out not to exist -- the stakeholder
-- clarified that Mixpanel's weekly-bucket UI pulls the full week-of-03-09
-- (including 03-09 through 03-12 pre-experiment events) into the first
-- row despite a 03-13 date filter. The gap is fully explained by that UI
-- behavior; no further diagnostics needed. Leaving the code for history.
-- ============================================================
-- q15: Diagnose the 4-unit gap in the 03-13 -> 03-15 slice.
-- Meredith's Mixpanel report shows 8 distinct purchasers in week-of-03-09
-- (constrained by her filter to 03-13 to 03-15); my q1 showed 4.
-- Pull every candidate WCPM add-on event in early March with every
-- timestamp column available, ordered by time, to see whether the 4 extra
-- users fall into the window under a different timestamp or filter.
-- ============================================================
SELECT
     a.__sdc_primary_key
    ,a.distinct_id
    ,a.event
    ,a.event_created                                                              AS event_created_raw
    ,a.event_created::timestamp                                                   AS event_created_ts
    ,a.time                                                                       AS mp_time
    ,a.server_event_created_at_timestamp                                          AS server_event_created_ts
    ,a.server_event_processed_at_timestamp                                        AS server_event_processed_ts
    ,a.current_addons
    ,a.current_plan_id
    ,a.current_plan_name
    ,a.current_subscription_id
    ,a.current_subscription_status
    ,a.statsig_stable_id
FROM pc_stitch_db.mixpanel.export a
WHERE a.event = 'Purchased Add-on'
  AND a.event_created::timestamp BETWEEN '2026-03-09' AND '2026-03-20'
ORDER BY a.event_created::timestamp;

-- ============================================================
-- q16: Mixpanel "Purchased Add-on" bucket sizing under every candidate
-- timestamp column. If one of these columns produces 8 distinct users in
-- the 03-13 to 03-15 slice instead of 4, that column is the one Mixpanel
-- is using for bucketing.
-- ============================================================
SELECT
     'event_created'                                                              AS ts_column
    ,COUNT(DISTINCT a.distinct_id)                                                AS distinct_users_03_13_to_03_15
FROM pc_stitch_db.mixpanel.export a
WHERE a.event = 'Purchased Add-on'
  AND a.current_addons ILIKE '%warner%'
  AND a.event_created::date BETWEEN '2026-03-13' AND '2026-03-15'

UNION ALL

SELECT
     'time'                                                                       AS ts_column
    ,COUNT(DISTINCT a.distinct_id)
FROM pc_stitch_db.mixpanel.export a
WHERE a.event = 'Purchased Add-on'
  AND a.current_addons ILIKE '%warner%'
  AND TO_TIMESTAMP(a.time::number)::date BETWEEN '2026-03-13' AND '2026-03-15'

UNION ALL

SELECT
     'server_event_created_at_timestamp'                                          AS ts_column
    ,COUNT(DISTINCT a.distinct_id)
FROM pc_stitch_db.mixpanel.export a
WHERE a.event = 'Purchased Add-on'
  AND a.current_addons ILIKE '%warner%'
  AND a.server_event_created_at_timestamp::date BETWEEN '2026-03-13' AND '2026-03-15'

UNION ALL

SELECT
     'server_event_processed_at_timestamp'                                        AS ts_column
    ,COUNT(DISTINCT a.distinct_id)
FROM pc_stitch_db.mixpanel.export a
WHERE a.event = 'Purchased Add-on'
  AND a.current_addons ILIKE '%warner%'
  AND a.server_event_processed_at_timestamp::date BETWEEN '2026-03-13' AND '2026-03-15'

UNION ALL

-- No WCPM filter at all -- tests whether Meredith's filter is broader
SELECT
     'event_created_no_wcpm_filter'                                               AS ts_column
    ,COUNT(DISTINCT a.distinct_id)
FROM pc_stitch_db.mixpanel.export a
WHERE a.event = 'Purchased Add-on'
  AND a.event_created::date BETWEEN '2026-03-13' AND '2026-03-15';

-- ============================================================
-- q17: Per-user pipeline audit. One row per distinct_id with a WCPM
-- add-on event in raw Mixpanel (in-window). Shows how many events that
-- user has at each layer. The user(s) driving the 22 vs. 23 gap will
-- have events_in_statsig_model = 0.
-- ============================================================
WITH raw_addon_events AS (
    SELECT
         a.__sdc_primary_key
        ,a.distinct_id
        ,a.statsig_stable_id
        ,a.event_created::timestamp                                               AS mp_event_ts
        ,a.current_addons
        ,a.current_plan_id
        ,a.current_plan_name
        ,a.current_subscription_id
        ,a.current_subscription_status
    FROM pc_stitch_db.mixpanel.export a
    WHERE a.event = 'Purchased Add-on'
      AND a.event_created::date BETWEEN '2026-03-13' AND '2026-04-18'
      AND a.current_addons ILIKE '%warner%'
),
fct AS (
    SELECT DISTINCT __sdc_primary_key
    FROM soundstripe_prod.core.fct_events
    WHERE event = 'Purchased Add-on'
      AND event_ts::date BETWEEN '2026-03-13' AND '2026-04-18'
),
sm AS (
    SELECT DISTINCT __sdc_primary_key
    FROM soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output
    WHERE event = 'Purchased Add-on'
      AND event_ts::date BETWEEN '2026-03-13' AND '2026-04-18'
)
SELECT
     re.distinct_id
    ,MAX(re.statsig_stable_id)                                                    AS statsig_stable_id
    ,MAX(re.current_plan_id)                                                      AS current_plan_id
    ,MAX(re.current_plan_name)                                                    AS current_plan_name
    ,MAX(re.current_subscription_id)                                              AS current_subscription_id
    ,MAX(re.current_subscription_status)                                          AS current_subscription_status
    ,MIN(re.current_addons)                                                       AS addons_on_event
    ,MIN(re.mp_event_ts)                                                          AS first_mp_event_ts
    ,MAX(re.mp_event_ts)                                                          AS last_mp_event_ts
    ,COUNT(*)                                                                     AS raw_mp_events
    ,COUNT(fct.__sdc_primary_key)                                                 AS events_in_fct
    ,COUNT(sm.__sdc_primary_key)                                                  AS events_in_statsig_model
FROM raw_addon_events re
    LEFT JOIN fct ON re.__sdc_primary_key = fct.__sdc_primary_key
    LEFT JOIN sm  ON re.__sdc_primary_key = sm.__sdc_primary_key
GROUP BY re.distinct_id
ORDER BY events_in_statsig_model ASC, events_in_fct ASC, raw_mp_events DESC;

-- ============================================================
-- q18a: Every raw Mixpanel "Purchased Add-on" event for the dropped
-- distinct_id, with downstream presence flags. Expected: 5 raw rows per
-- q17; each gets a 0/1 indicator for fct_events and for the Statsig model.
-- ============================================================
SELECT
     a.__sdc_primary_key
    ,a.event
    ,a.event_created::timestamp                                                   AS mp_event_ts
    ,a._sdc_received_at                                                           AS mp_sdc_received_at
    ,a.current_addons
    ,a.current_plan_id
    ,a.current_subscription_id
    ,a.statsig_stable_id
    ,CASE WHEN fe.__sdc_primary_key IS NOT NULL THEN 1 ELSE 0 END                 AS in_fct_events
    ,CASE WHEN sm.__sdc_primary_key IS NOT NULL THEN 1 ELSE 0 END                 AS in_statsig_model
FROM pc_stitch_db.mixpanel.export a
    LEFT JOIN soundstripe_prod.core.fct_events fe
        ON a.__sdc_primary_key = fe.__sdc_primary_key
    LEFT JOIN soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output sm
        ON a.__sdc_primary_key = sm.__sdc_primary_key
WHERE a.distinct_id = '$device:1939e3fa043955-024c8c634ccb85-3f626b4b-16a7f0-1939e3fa043955'
  AND a.event = 'Purchased Add-on'
ORDER BY a.event_created;

-- ============================================================
-- q18b: The fct_events row(s) for the dropped user's add-on events.
-- Pulls SDC metadata so we can see when fct_events received the row
-- and compare it against the Statsig model's incremental watermark (q18d).
-- If _sdc_received_at is AFTER the model's max event_ts at the time of
-- its next run, the incremental-watermark-skip hypothesis is confirmed.
-- ============================================================
SELECT
     fe.__sdc_primary_key
    ,fe.distinct_id
    ,fe.event
    ,fe.event_ts
    ,fe.statsig_stable_id
    ,fe.current_subscription_id
    --,fe.__sdc_received_at                                                          AS fct_sdc_received_at
    --,fe.__sdc_batched_at                                                           AS fct_sdc_batched_at
FROM soundstripe_prod.core.fct_events fe
WHERE fe.distinct_id = '$device:1939e3fa043955-024c8c634ccb85-3f626b4b-16a7f0-1939e3fa043955'
  AND fe.event = 'Purchased Add-on'
ORDER BY fe.event_ts;

-- ============================================================
-- q18c: Directed search in the Statsig model for this user and this PK,
-- with NO event-name or date filter. If the row is present here but was
-- excluded by my q17 window filter, the "lost" finding is an artifact of
-- my query. If it's genuinely absent, the drop is real.
-- ============================================================
SELECT
     sm.__sdc_primary_key
    ,sm.distinct_id
    ,sm.event
    ,sm.event_ts
    ,sm.statsig_stable_id
FROM soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output sm
WHERE sm.distinct_id = '$device:1939e3fa043955-024c8c634ccb85-3f626b4b-16a7f0-1939e3fa043955'
ORDER BY sm.event_ts;

-- ============================================================
-- q18d: Statsig model's current watermark(s) -- what is max(event_ts) and
-- max(_sdc_received_at) in the model right now? Compare to q18b's
-- fct_sdc_received_at to see whether the fct_events row arrived late.
-- ============================================================
SELECT
     MAX(event_ts)                                                                AS model_max_event_ts
    ,MAX(event_ts::date)                                                          AS model_max_event_date
    ,COUNT(*)                                                                     AS total_rows_in_model
FROM soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output;

-- ============================================================
-- q19: Identity resolution for the 10 users in q14 with
-- attribution_bucket IN ('never_exposed', 'exposed_after_purchase').
--
-- Reconciliation paths (per d7dev identity model):
--   - fct_events.user_id is COALESCE(user_id, mp_reserved_user_id,
--     mp_reserved_distinct_id_before_identity) -- already the canonical
--     user identifier as far as the warehouse is concerned. Join by
--     __sdc_primary_key (1:1 with the Statsig model row).
--   - soundstripe_prod.transformations.distinct_id_mapping resolves
--     distinct_id_old -> consolidated_id across identify/alias events.
--     Join on the Statsig model's distinct_id as distinct_id_old to
--     recover the post-identify canonical distinct_id.
--   - Statsig model also carries current_subscription_id /
--     current_account_id from fct_events -- pulled alongside as
--     independent business-key anchors.
-- ============================================================
WITH statsig_addon_rows AS (
    SELECT
         a.__sdc_primary_key
        ,a.event_ts                                                               AS purchase_ts
        ,a.distinct_id
        ,a.statsig_stable_id
        ,a.current_subscription_id
        ,a.current_account_id
    FROM soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output a
    WHERE a.event = 'Purchased Add-on'
      AND a.event_ts::date BETWEEN '2026-03-13' AND '2026-04-18'
),
group_lookup AS (
    SELECT DISTINCT group_id, LOWER(group_name) AS arm
    FROM soundstripe_prod._external_statsig.exposures
    WHERE LOWER(experiment_id) = 'wcpm_pricing_test'
),
bucketed AS (
    SELECT
         sa.__sdc_primary_key
        ,sa.purchase_ts
        ,sa.distinct_id
        ,sa.statsig_stable_id
        ,sa.current_subscription_id
        ,sa.current_account_id
        ,fe.first_exposure
        ,CASE
            WHEN fe.unit_id IS NULL                          THEN 'never_exposed'
            WHEN fe.first_exposure <= sa.purchase_ts         THEN 'exposed_before_purchase'
            ELSE                                                  'exposed_after_purchase'
         END                                                                          AS attribution_bucket
        ,gl.arm
    FROM statsig_addon_rows sa
        LEFT JOIN soundstripe_prod._external_statsig."first_exposures_wcpm_pricing_test" fe
            ON sa.statsig_stable_id = fe.unit_id
        LEFT JOIN group_lookup gl
            ON fe.group_id = gl.group_id
),
suspects AS (
    SELECT *
    FROM bucketed
    WHERE attribution_bucket IN ('never_exposed', 'exposed_after_purchase')
),
dm_latest AS (
    -- distinct_id_mapping has one row per (consolidated_id, distinct_id_old);
    -- collapse to one consolidated_id per distinct_id_old via the most-recent mapping.
    SELECT
         distinct_id_old
        ,consolidated_id
    FROM soundstripe_prod.transformations.distinct_id_mapping
    WHERE distinct_id_old IN (SELECT distinct_id FROM suspects WHERE distinct_id IS NOT NULL)
    QUALIFY ROW_NUMBER() OVER (PARTITION BY distinct_id_old ORDER BY last_mapping_event_ts DESC) = 1
)
SELECT
     s.attribution_bucket
    ,s.arm
    ,s.statsig_stable_id
    ,s.distinct_id                                                                    AS statsig_model_distinct_id
    ,dm.consolidated_id                                                               AS consolidated_distinct_id
    ,fe.user_id                                                                       AS fct_events_user_id
    ,s.current_subscription_id
    ,s.current_account_id
    ,s.purchase_ts
    ,s.first_exposure
FROM suspects s
    LEFT JOIN soundstripe_prod.core.fct_events fe
        ON fe.__sdc_primary_key = s.__sdc_primary_key
    LEFT JOIN dm_latest dm
        ON dm.distinct_id_old = s.distinct_id
ORDER BY s.attribution_bucket, s.arm, s.purchase_ts;
