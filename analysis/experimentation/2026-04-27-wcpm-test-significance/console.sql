-- ============================================================
-- WCPM Pricing Test — Significance Read-out (2026-04-27)
--
-- Purpose: Refresh the 2026-04-18 audit through 2026-04-27 AND produce
-- the per-arm exposed_n / purchased_n input row for the frequentist
-- significance test in stats/wcpm_significance.py.
--
-- Window: 2026-03-13 → 2026-04-27 (test still running at refresh time).
-- Cohort: warehouse-recovered (raw _external_statsig.exposures, stable_id-grain
--         first-exposure, multi-arm stable_ids tie-broken by earliest exposure).
-- Primary metric: WCPM add-on attach rate (Existing-Sub + New-Sub combined).
--
-- Convention (per feedback_one_sql_file_per_query_set):
--   one SELECT per labeled q##; consolidate multi-angle checks via UNION ALL.
--   Reserved-word aliases avoided per feedback_snowflake_reserved_aliases.
--
-- Author: Devon Bennett (with Claude). 2026-04-27.
-- Dependencies: pc_stitch_db.mixpanel.export, _external_statsig.exposures,
--               _external_statsig.statsig_clickstream_events_etl_output,
--               _external_statsig."first_exposures_wcpm_pricing_test",
--               core.fct_events.
-- ============================================================


-- ============================================================
-- q01: Mixpanel WCPM add-on weekly bucketing — refresh of audit q1.
-- Reproduces Meredith's Mixpanel report shape with extended window.
-- Two filter variants surfaced for comparison; current_addons ILIKE '%warner%'
-- is canonical per pc_stitch_db__mixpanel__export.md calibration.
-- Expected: counts grow vs. 2026-04-18 (test running 9 more days).
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
      AND a.event_created::date BETWEEN '2026-03-13' AND '2026-04-27'
)
SELECT
     DATE_TRUNC('week', event_ts)                                                 AS purchase_week
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
-- q02: Window-total Mixpanel baseline + statsig_stable_id fill rate.
-- Audit at 2026-04-18: total 27 distinct purchasers, fill rate 98.96%.
-- Refresh expectation: total > 27; fill rate stable.
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
  AND a.event_created::date BETWEEN '2026-03-13' AND '2026-04-27';


-- ============================================================
-- q03: Add-on composition sanity. Confirms WCPM-vs-other-addons mix is
-- still WCPM-dominant. If a non-WCPM add-on appears at material volume
-- in the 9-day extension, that affects whether Statsig's metric source
-- (which has no WCPM filter) over-counts.
-- ============================================================
SELECT
     a.current_addons
    ,COUNT(*)                                                                     AS event_count
    ,COUNT(DISTINCT a.distinct_id)                                                AS distinct_users
FROM pc_stitch_db.mixpanel.export a
WHERE a.event = 'Purchased Add-on'
  AND a.event_created::date BETWEEN '2026-03-13' AND '2026-04-27'
GROUP BY 1
ORDER BY event_count DESC;


-- ============================================================
-- q04: Statsig dbt model count refresh. At 2026-04-18: existing=4, new=8,
-- total=12 across 22 model rows (10 not_exposed). Expected at refresh:
-- both totals grow, ratio of not_exposed to exposed roughly stable
-- unless trigger coverage has changed.
-- ============================================================
SELECT
     SUM(a.add_on_purchase_total)                                                 AS total_addon_purchases
    ,SUM(a.add_on_purchase_existing_sub)                                          AS existing_sub_addons
    ,SUM(a.add_on_purchase_new_sub)                                               AS new_sub_addons
    ,COUNT(DISTINCT CASE WHEN a.add_on_purchase_total = 1 THEN a.distinct_id END) AS distinct_users_purchased
    ,COUNT(DISTINCT CASE WHEN a.add_on_purchase_total = 1 THEN a.statsig_stable_id END) AS distinct_stable_ids_purchased
    ,SUM(CASE WHEN a.add_on_purchase_total = 1 AND a.statsig_stable_id IS NULL THEN 1 ELSE 0 END) AS addon_rows_missing_stable_id
FROM soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output a
WHERE a.event = 'Purchased Add-on'
  AND a.event_ts::date BETWEEN '2026-03-13' AND '2026-04-27';


-- ============================================================
-- q05: Per-arm distinct exposed stable_ids from RAW exposures table.
-- This is the warehouse-recovered cohort sizing — no 1:1 enforcement.
-- Audit at 2026-04-18: Control 6,115 / Mid 5,972 / Deep 6,137.
-- Expected at refresh: monotonic growth (test still running).
-- ============================================================
SELECT
     LOWER(group_name)                                                            AS arm
    ,COUNT(DISTINCT stable_id)                                                    AS distinct_exposed_stable_ids
    ,COUNT(*)                                                                     AS exposure_event_count
FROM soundstripe_prod._external_statsig.exposures
WHERE LOWER(experiment_id) = 'wcpm_pricing_test'
  AND timestamp::date BETWEEN '2026-03-13' AND '2026-04-27'
GROUP BY 1
ORDER BY 1;


-- ============================================================
-- q06: Per-arm Pulse-cohort sizing from first_exposures (1:1-filtered
-- by Statsig). This is the population Statsig Pulse reports against.
-- Refresh expectation: ~13.5% smaller per arm than q05 (Finding 6 magnitude).
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
-- q07: WAREHOUSE-RECOVERED COHORT DEFINITION (the §12 ALIGNMENT-CHECK target).
--
-- One row per (stable_id, first_arm). For stable_ids exposed to multiple
-- arms (rare at stable_id grain — most sprawl is at user_id ↔ stable_id),
-- earliest-exposure-timestamp wins. This becomes the denominator for the
-- headline WCPM add-on attach metric in q09.
--
-- Output: per-arm distinct stable_id count + multi-arm stable_id count
-- so the cohort definition is auditable in one row per arm.
-- ============================================================
WITH first_exposure_per_stable_id AS (
    SELECT
         stable_id
        ,LOWER(group_name)                                                        AS arm
        ,timestamp                                                                AS exposure_ts
        ,ROW_NUMBER() OVER (
            PARTITION BY stable_id
            ORDER BY timestamp ASC
         )                                                                        AS rn
    FROM soundstripe_prod._external_statsig.exposures
    WHERE LOWER(experiment_id) = 'wcpm_pricing_test'
      AND timestamp::date BETWEEN '2026-03-13' AND '2026-04-27'
      AND stable_id IS NOT NULL
),
cohort AS (
    SELECT stable_id, arm, exposure_ts
    FROM first_exposure_per_stable_id
    WHERE rn = 1
),
multi_arm_stable_ids AS (
    SELECT
         stable_id
        ,COUNT(DISTINCT LOWER(group_name))                                        AS distinct_arms
    FROM soundstripe_prod._external_statsig.exposures
    WHERE LOWER(experiment_id) = 'wcpm_pricing_test'
      AND timestamp::date BETWEEN '2026-03-13' AND '2026-04-27'
      AND stable_id IS NOT NULL
    GROUP BY 1
)
SELECT
     c.arm
    ,COUNT(*)                                                                     AS exposed_n_warehouse_recovered
    ,SUM(CASE WHEN ma.distinct_arms > 1 THEN 1 ELSE 0 END)                        AS multi_arm_stable_ids
    ,ROUND(100.0 * SUM(CASE WHEN ma.distinct_arms > 1 THEN 1 ELSE 0 END) / COUNT(*), 3) AS multi_arm_pct
FROM cohort c
    LEFT JOIN multi_arm_stable_ids ma ON c.stable_id = ma.stable_id
GROUP BY 1
ORDER BY 1;


-- ============================================================
-- q08: WCPM purchaser stable_id resolution (Mixpanel side).
-- One row per (statsig_stable_id, purchase_ts) of Mixpanel WCPM purchases.
-- Resolved against fct_events as a sanity-check fallback for events whose
-- Mixpanel stable_id is null.
--
-- Used by q09 as the outcome population.
-- ============================================================
WITH mp_wcpm_purchasers AS (
    SELECT
         a.__sdc_primary_key
        ,a.event_created::timestamp                                               AS purchase_ts
        ,a.distinct_id
        ,a.statsig_stable_id                                                      AS mp_stable_id
    FROM pc_stitch_db.mixpanel.export a
    WHERE a.event = 'Purchased Add-on'
      AND a.current_addons ILIKE '%warner%'
      AND a.event_created::date BETWEEN '2026-03-13' AND '2026-04-27'
)
SELECT
     COUNT(*)                                                                     AS purchase_event_count
    ,COUNT(DISTINCT distinct_id)                                                  AS distinct_purchasers_by_distinct_id
    ,COUNT(DISTINCT mp_stable_id)                                                 AS distinct_purchasers_by_stable_id
    ,SUM(CASE WHEN mp_stable_id IS NULL THEN 1 ELSE 0 END)                        AS purchases_missing_stable_id
FROM mp_wcpm_purchasers;


-- ============================================================
-- q09: PER-ARM ATTACH RATE — HEADLINE METRIC (input to stats script).
--
-- Cohort (denominator): warehouse-recovered cohort from q07 logic.
-- Outcome (numerator): mp_wcpm_purchasers from q08 logic with first_exposure_ts <= purchase_ts.
--
-- §1 RATE block (see methodology.md):
--   numerator   = distinct stable_ids in cohort with WCPM purchase post-first-exposure
--   denominator = distinct stable_ids in warehouse-recovered cohort, per arm
--   type        = addon_purchasers / first_exposure_units
--
-- TYPE AUDIT (filled in after execution): the LEFT JOIN preserves all cohort
-- stable_ids regardless of whether a purchase exists; numerator = SUM(CASE)
-- counts only matching joins; denominator = COUNT(DISTINCT cohort stable_id)
-- which is unaffected by the join.
-- ============================================================
WITH first_exposure_per_stable_id AS (
    SELECT
         stable_id
        ,LOWER(group_name)                                                        AS arm
        ,timestamp                                                                AS first_exposure_ts
        ,ROW_NUMBER() OVER (PARTITION BY stable_id ORDER BY timestamp ASC)        AS rn
    FROM soundstripe_prod._external_statsig.exposures
    WHERE LOWER(experiment_id) = 'wcpm_pricing_test'
      AND timestamp::date BETWEEN '2026-03-13' AND '2026-04-27'
      AND stable_id IS NOT NULL
),
cohort AS (
    SELECT stable_id, arm, first_exposure_ts
    FROM first_exposure_per_stable_id
    WHERE rn = 1
),
mp_wcpm_purchasers AS (
    SELECT
         a.statsig_stable_id                                                      AS mp_stable_id
        ,MIN(a.event_created::timestamp)                                          AS first_purchase_ts
    FROM pc_stitch_db.mixpanel.export a
    WHERE a.event = 'Purchased Add-on'
      AND a.current_addons ILIKE '%warner%'
      AND a.event_created::date BETWEEN '2026-03-13' AND '2026-04-27'
      AND a.statsig_stable_id IS NOT NULL
    GROUP BY 1
)
SELECT
     c.arm
    ,COUNT(DISTINCT c.stable_id)                                                  AS exposed_n
    ,COUNT(DISTINCT CASE WHEN p.mp_stable_id IS NOT NULL
                          AND c.first_exposure_ts <= p.first_purchase_ts
                         THEN c.stable_id END)                                    AS purchased_n
    ,ROUND(
        100.0 * COUNT(DISTINCT CASE WHEN p.mp_stable_id IS NOT NULL
                                     AND c.first_exposure_ts <= p.first_purchase_ts
                                    THEN c.stable_id END)
        / NULLIF(COUNT(DISTINCT c.stable_id), 0)
     , 4)                                                                         AS attach_rate_pct
FROM cohort c
    LEFT JOIN mp_wcpm_purchasers p
        ON c.stable_id = p.mp_stable_id
GROUP BY 1
ORDER BY 1;


-- ============================================================
-- q10: Existing-Sub vs New-Sub split per arm — matches Statsig's two
-- value columns (ADD_ON_PURCHASE_EXISTING_SUB / ADD_ON_PURCHASE_NEW_SUB).
--
-- Uses Statsig's clickstream model for the Existing/New flag (it carries
-- the labels) but the warehouse-recovered cohort for the denominator.
-- This is a hybrid: outcome flag from clickstream model + cohort from
-- raw exposures stable_id grain. It introduces Finding-4 bias on the
-- numerator side (late arrivals dropped) but only for the Existing/New
-- split — the q09 headline uses Mixpanel directly and is Finding-4-clean.
-- ============================================================
WITH first_exposure_per_stable_id AS (
    SELECT
         stable_id
        ,LOWER(group_name)                                                        AS arm
        ,timestamp                                                                AS first_exposure_ts
        ,ROW_NUMBER() OVER (PARTITION BY stable_id ORDER BY timestamp ASC)        AS rn
    FROM soundstripe_prod._external_statsig.exposures
    WHERE LOWER(experiment_id) = 'wcpm_pricing_test'
      AND timestamp::date BETWEEN '2026-03-13' AND '2026-04-27'
      AND stable_id IS NOT NULL
),
cohort AS (
    SELECT stable_id, arm, first_exposure_ts
    FROM first_exposure_per_stable_id
    WHERE rn = 1
),
statsig_addon_rows AS (
    SELECT
         a.statsig_stable_id
        ,a.event_ts                                                               AS purchase_ts
        ,a.add_on_purchase_existing_sub
        ,a.add_on_purchase_new_sub
    FROM soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output a
    WHERE a.event = 'Purchased Add-on'
      AND a.event_ts::date BETWEEN '2026-03-13' AND '2026-04-27'
      AND a.add_on_purchase_total = 1
)
SELECT
     c.arm
    ,COUNT(DISTINCT c.stable_id)                                                  AS exposed_n
    ,SUM(CASE WHEN sa.add_on_purchase_existing_sub = 1
                 AND c.first_exposure_ts <= sa.purchase_ts THEN 1 ELSE 0 END)     AS existing_sub_purchases
    ,SUM(CASE WHEN sa.add_on_purchase_new_sub = 1
                 AND c.first_exposure_ts <= sa.purchase_ts THEN 1 ELSE 0 END)     AS new_sub_purchases
FROM cohort c
    LEFT JOIN statsig_addon_rows sa
        ON c.stable_id = sa.statsig_stable_id
GROUP BY 1
ORDER BY 1;


-- ============================================================
-- q11: Multi-arm-stable_id sensitivity check.
-- Counts stable_ids exposed to >1 arm and reports their distribution
-- across "first arm" (the arm we assign them to via tie-break).
-- If any arm carries a materially-asymmetric multi-arm rate, flag.
-- ============================================================
WITH per_stable_id AS (
    SELECT
         stable_id
        ,COUNT(DISTINCT LOWER(group_name))                                        AS distinct_arms
        ,MIN(CASE WHEN rn_first_arm = 1 THEN LOWER(group_name) END)               AS first_arm
    FROM (
        SELECT
             stable_id
            ,group_name
            ,timestamp
            ,ROW_NUMBER() OVER (PARTITION BY stable_id ORDER BY timestamp ASC)    AS rn_first_arm
        FROM soundstripe_prod._external_statsig.exposures
        WHERE LOWER(experiment_id) = 'wcpm_pricing_test'
          AND timestamp::date BETWEEN '2026-03-13' AND '2026-04-27'
          AND stable_id IS NOT NULL
    )
    GROUP BY 1
)
SELECT
     first_arm
    ,distinct_arms
    ,COUNT(*)                                                                     AS stable_id_count
FROM per_stable_id
GROUP BY 1, 2
ORDER BY first_arm, distinct_arms;


-- ============================================================
-- q12: Finding-4 size check — events orphaned by clickstream model's
-- incremental-predicate skip.
--
-- core.fct_events does NOT carry `current_addons` (dropped during dbt
-- transform). To identify WCPM events on the fct_events side, anchor on
-- __sdc_primary_keys from Mixpanel's WCPM-filtered set, then check which
-- of those keys appear in fct_events vs the Statsig clickstream model.
--
-- Audit at 2026-04-18: 1 dropped event. Refresh expectation: still small.
-- ============================================================
WITH mp_wcpm_pks AS (
    SELECT DISTINCT __sdc_primary_key
    FROM pc_stitch_db.mixpanel.export
    WHERE event = 'Purchased Add-on'
      AND current_addons ILIKE '%warner%'
      AND event_created::date BETWEEN '2026-03-13' AND '2026-04-27'
),
fct_pks AS (
    SELECT DISTINCT __sdc_primary_key
    FROM soundstripe_prod.core.fct_events
    WHERE event = 'Purchased Add-on'
      AND event_ts::date BETWEEN '2026-03-13' AND '2026-04-27'
      AND __sdc_primary_key IN (SELECT __sdc_primary_key FROM mp_wcpm_pks)
),
statsig_pks AS (
    SELECT DISTINCT __sdc_primary_key
    FROM soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output
    WHERE event = 'Purchased Add-on'
      AND event_ts::date BETWEEN '2026-03-13' AND '2026-04-27'
      AND add_on_purchase_total = 1
      AND __sdc_primary_key IN (SELECT __sdc_primary_key FROM mp_wcpm_pks)
)
SELECT
     (SELECT COUNT(*) FROM mp_wcpm_pks)                                           AS mp_wcpm_pk_count
    ,(SELECT COUNT(*) FROM fct_pks)                                               AS fct_events_wcpm_pk_count
    ,(SELECT COUNT(*) FROM statsig_pks)                                           AS statsig_model_wcpm_pk_count
    ,(SELECT COUNT(*) FROM fct_pks WHERE __sdc_primary_key NOT IN (SELECT __sdc_primary_key FROM statsig_pks)) AS finding4_orphans
    ,(SELECT COUNT(*) FROM mp_wcpm_pks WHERE __sdc_primary_key NOT IN (SELECT __sdc_primary_key FROM fct_pks)) AS in_mp_not_in_fct;


-- ============================================================
-- q13: Finding-6 global scale — 1:1 mapping exclusion magnitude.
-- Refresh of audit q21 with extended window. Reports stable_id arm-count
-- distribution and user_id sprawl distribution.
-- Was at 2026-04-18: 2,709 of 20,072 logged-in user_ids (~13.5%) carried multi-arm exposures.
-- Refresh expectation: rate stable or growing as test accrues exposures.
-- ============================================================
WITH exp AS (
    SELECT
         e.stable_id
        ,e.user_id
        ,LOWER(e.group_name)                                                      AS arm
    FROM soundstripe_prod._external_statsig.exposures e
    WHERE LOWER(e.experiment_id) = 'wcpm_pricing_test'
      AND e.timestamp::date BETWEEN '2026-03-13' AND '2026-04-27'
),
per_stable_id AS (
    SELECT
         stable_id
        ,COUNT(DISTINCT arm)                                                      AS distinct_arms
    FROM exp
    WHERE stable_id IS NOT NULL
    GROUP BY 1
),
per_user_id AS (
    SELECT
         user_id
        ,COUNT(DISTINCT stable_id)                                                AS distinct_stable_ids
        ,COUNT(DISTINCT arm)                                                      AS distinct_arms
    FROM exp
    WHERE user_id IS NOT NULL
    GROUP BY 1
)
SELECT
     'a. stable_ids: arm count distribution'                                      AS metric
    ,distinct_arms::string                                                        AS bucket
    ,COUNT(*)                                                                     AS unit_count
FROM per_stable_id
GROUP BY 1, 2

UNION ALL

SELECT
     'b. user_ids: arm count distribution (logged-in only)'                       AS metric
    ,distinct_arms::string                                                        AS bucket
    ,COUNT(*)                                                                     AS unit_count
FROM per_user_id
GROUP BY 1, 2

UNION ALL

SELECT
     'c. user_ids: stable_id count distribution (identity sprawl)'                AS metric
    ,distinct_stable_ids::string                                                  AS bucket
    ,COUNT(*)                                                                     AS unit_count
FROM per_user_id
GROUP BY 1, 2

ORDER BY metric, bucket;


-- ============================================================
-- q14: Reconciliation table — ONE ROW per population-definition flavor.
-- Closes the loop on which population each downstream readout uses.
-- Single SELECT via UNION ALL with discriminator column 'population'.
-- ============================================================
WITH mp_total AS (
    SELECT COUNT(DISTINCT distinct_id) AS n
    FROM pc_stitch_db.mixpanel.export
    WHERE event = 'Purchased Add-on'
      AND current_addons ILIKE '%warner%'
      AND event_created::date BETWEEN '2026-03-13' AND '2026-04-27'
),
statsig_model_total AS (
    SELECT SUM(add_on_purchase_total) AS n
    FROM soundstripe_prod._external_statsig.statsig_clickstream_events_etl_output
    WHERE event = 'Purchased Add-on'
      AND event_ts::date BETWEEN '2026-03-13' AND '2026-04-27'
),
pulse_cohort AS (
    SELECT COUNT(DISTINCT unit_id) AS n
    FROM soundstripe_prod._external_statsig."first_exposures_wcpm_pricing_test"
),
warehouse_cohort AS (
    SELECT COUNT(DISTINCT stable_id) AS n
    FROM (
        SELECT stable_id
              ,ROW_NUMBER() OVER (PARTITION BY stable_id ORDER BY timestamp ASC)  AS rn
        FROM soundstripe_prod._external_statsig.exposures
        WHERE LOWER(experiment_id) = 'wcpm_pricing_test'
          AND timestamp::date BETWEEN '2026-03-13' AND '2026-04-27'
          AND stable_id IS NOT NULL
    )
    WHERE rn = 1
)
SELECT '01_mp_total_distinct_purchasers'      AS population, n FROM mp_total
UNION ALL SELECT '02_statsig_model_addon_total' AS population, n FROM statsig_model_total
UNION ALL SELECT '03_pulse_cohort_total'        AS population, n FROM pulse_cohort
UNION ALL SELECT '04_warehouse_cohort_total'    AS population, n FROM warehouse_cohort
ORDER BY population;


-- ============================================================
-- q15: CUPED sufficient statistics per arm — engagement covariate.
--
-- Y_post = WCPM add-on purchase event count per cohort stable_id from
--          first_exposure_ts through 2026-04-27 (sum metric).
-- X_pre  = total fct_events count per cohort stable_id in
--          [first_exposure_ts - 7 days, first_exposure_ts).
--          Engagement is the right covariate class for a near-zero-baseline
--          conversion metric: well-populated, high variance, proxies for
--          purchase propensity. Using same-metric WCPM purchases as the
--          covariate would be degenerate (pre/post attachers are disjoint
--          populations on this rare-event metric → Cov(X, Y) ≈ 0).
--
-- Returns per-arm sufficient statistics so the Python script can compute
-- pooled theta, rho-squared, and CUPED-adjusted means/variances without
-- exporting the full 32K-row per-stable_id table.
-- ============================================================
WITH first_exposure_per_stable_id AS (
    SELECT
         stable_id
        ,LOWER(group_name)                                                        AS arm
        ,timestamp                                                                AS first_exposure_ts
        ,ROW_NUMBER() OVER (PARTITION BY stable_id ORDER BY timestamp ASC)        AS rn
    FROM soundstripe_prod._external_statsig.exposures
    WHERE LOWER(experiment_id) = 'wcpm_pricing_test'
      AND timestamp::date BETWEEN '2026-03-13' AND '2026-04-27'
      AND stable_id IS NOT NULL
),
cohort AS (
    SELECT stable_id, arm, first_exposure_ts
    FROM first_exposure_per_stable_id
    WHERE rn = 1
),
pre_activity AS (
    SELECT
         c.stable_id
        ,c.arm
        ,COUNT(e.__sdc_primary_key)                                               AS pre_event_count
    FROM cohort c
        LEFT JOIN soundstripe_prod.core.fct_events e
            ON e.statsig_stable_id = c.stable_id
           AND e.event_ts < c.first_exposure_ts
           AND e.event_ts >= DATEADD('day', -7, c.first_exposure_ts)
           AND e.event_ts::date BETWEEN '2026-03-06' AND '2026-04-27'
    GROUP BY 1, 2
),
mp_wcpm AS (
    SELECT
         a.statsig_stable_id                                                      AS mp_stable_id
        ,a.event_created::timestamp                                               AS purchase_ts
    FROM pc_stitch_db.mixpanel.export a
    WHERE a.event = 'Purchased Add-on'
      AND a.current_addons ILIKE '%warner%'
      AND a.event_created::date BETWEEN '2026-03-13' AND '2026-04-27'
      AND a.statsig_stable_id IS NOT NULL
),
post_outcome AS (
    SELECT
         c.stable_id
        ,SUM(CASE WHEN p.purchase_ts >= c.first_exposure_ts
                    AND p.purchase_ts <= '2026-04-27 23:59:59'
                  THEN 1 ELSE 0 END)                                              AS y_post
    FROM cohort c
        LEFT JOIN mp_wcpm p ON c.stable_id = p.mp_stable_id
    GROUP BY 1
),
joined AS (
    SELECT
         pa.arm
        ,pa.stable_id
        ,COALESCE(pa.pre_event_count, 0)                                          AS x_pre
        ,COALESCE(po.y_post, 0)                                                   AS y_post
    FROM pre_activity pa
        LEFT JOIN post_outcome po ON pa.stable_id = po.stable_id
)
SELECT
     arm
    ,COUNT(*)                                                                     AS n
    ,SUM(y_post)                                                                  AS sum_y
    ,SUM(x_pre)                                                                   AS sum_x
    ,SUM(y_post * x_pre)                                                          AS sum_xy
    ,SUM(y_post * y_post)                                                         AS sum_y2
    ,SUM(x_pre * x_pre)                                                           AS sum_x2
    ,AVG(x_pre)                                                                   AS mean_x
    ,SUM(CASE WHEN x_pre > 0 THEN 1 ELSE 0 END)                                   AS units_with_pre_activity
FROM joined
GROUP BY 1
ORDER BY 1;
