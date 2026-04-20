-- =============================================================================
-- Phase C: Ryan Feb-Shift Diagnostic
-- =============================================================================
-- Context: Ryan Severns (Floodlight Growth) reports avg lead score for free
--   account sign-ups was ~0.5 Aug-Jan 2025 and ~0.65 Feb 2026+. Two unknowns:
--   (1) which score field he's querying, (2) which free-signup cohort.
-- Approach: stratify monthly means across all 7 candidate numeric score fields
--   and 3 candidate cohort definitions. The combination whose Aug-Jan mean
--   clusters near 0.5 and Feb-Apr mean clusters near 0.65 is Ryan's slice.
-- Rate Declaration documented in ./CLAUDE.md
-- Export convention: each query result as cN.csv into this folder.
--
-- REVISION 2026-04-15 after Phase A results:
--   Original cohort (a) included "chargebee_customer_id IS NULL". Phase A11
--   showed every Soundstripe user has a chargebee_customer_id (89.4% of contacts
--   have all three identity keys; only 0.04% have soundstripe_user_id without
--   chargebee). So that filter excluded all free product users. Primary cohort
--   (a) is now simply lifecyclestage='subscriber' (44,932 contacts table-wide).
-- Author: d7admin via Claude, 2026-04-15
-- =============================================================================


-- -----------------------------------------------------------------------------
-- C1 -- Monthly free-signup cohort volumes for each candidate definition
-- Purpose: quantify the three plausible "free account sign-ups" cohorts per
--   month Aug 2025 - Apr 2026. This establishes denominators for C2 and reveals
--   which cohort Ryan likely pulled from (by magnitude, stability, shape).
-- Cohort (a): HubSpot contact, lifecyclestage in ('subscriber','lead'),
--   no chargebee_customer_id, createdate in month M.
-- Cohort (b): HubSpot contact with has_free_account='true', createdate in month M.
-- Cohort (c): Mixpanel sessions with SIGNED_UP=1 joined to HubSpot via email,
--   signup month = session_started_at month. (Left join preserves signup count
--   even when no HubSpot contact exists -- signup_no_match flags that case.)
-- -----------------------------------------------------------------------------
WITH hubspot_typed AS (
    SELECT
          hc.object_id                                           AS hubspot_uid
        , NULLIF(hc.properties:email::string, '')                AS email
        , NULLIF(hc.properties:lifecyclestage::string, '')       AS lifecyclestage
        , NULLIF(hc.properties:chargebee_customer_id::string, '') AS chargebee_customer_id
        , NULLIF(hc.properties:has_free_account::string, '')     AS has_free_account
        , TRY_CAST(hc.properties:createdate::string AS BIGINT)   AS createdate_millis
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
)
, cohort_a AS (
    SELECT
          DATE_TRUNC('month', TO_TIMESTAMP(ht.createdate_millis / 1000))::DATE AS signup_month
        , COUNT(*)                                               AS cohort_a_contacts
    FROM hubspot_typed ht
    WHERE ht.lifecyclestage = 'subscriber'
      AND ht.createdate_millis IS NOT NULL
      AND TO_TIMESTAMP(ht.createdate_millis / 1000) >= '2025-08-01'
      AND TO_TIMESTAMP(ht.createdate_millis / 1000) <  '2026-05-01'
    GROUP BY 1
)
, cohort_b AS (
    SELECT
          DATE_TRUNC('month', TO_TIMESTAMP(ht.createdate_millis / 1000))::DATE AS signup_month
        , COUNT(*)                                               AS cohort_b_contacts
    FROM hubspot_typed ht
    WHERE LOWER(ht.has_free_account) = 'true'
      AND ht.createdate_millis IS NOT NULL
      AND TO_TIMESTAMP(ht.createdate_millis / 1000) >= '2025-08-01'
      AND TO_TIMESTAMP(ht.createdate_millis / 1000) <  '2026-05-01'
    GROUP BY 1
)
, cohort_c AS (
    SELECT
          DATE_TRUNC('month', fs.session_started_at)::DATE       AS signup_month
        , COUNT(*)                                               AS cohort_c_signups
    FROM soundstripe_prod.core.fct_sessions fs
    WHERE fs.signed_up > 0
      AND fs.session_started_at >= '2025-08-01'
      AND fs.session_started_at <  '2026-05-01'
    GROUP BY 1
)
SELECT
      COALESCE(a.signup_month, b.signup_month, c.signup_month)   AS signup_month
    , a.cohort_a_contacts                                         AS cohort_a_lifecycle_free
    , b.cohort_b_contacts                                         AS cohort_b_has_free_account
    , c.cohort_c_signups                                          AS cohort_c_mixpanel_signed_up
FROM cohort_a a
    FULL OUTER JOIN cohort_b b ON a.signup_month = b.signup_month
    FULL OUTER JOIN cohort_c c ON COALESCE(a.signup_month, b.signup_month) = c.signup_month
ORDER BY 1
;


-- -----------------------------------------------------------------------------
-- C2 -- Monthly mean for EVERY candidate score field, Cohort (a)
-- Purpose: the matchmaker query. Monthly mean/median of each candidate score
--   field for cohort (a) -- the most likely Ryan interpretation. Flag which
--   field's Aug-Jan window means cluster near 0.5 AND Feb-Apr window means
--   cluster near 0.65.
-- Candidates (7 numeric fields; hs_predictivescoringtier is categorical and
--   covered in C4/C5 via source/bucket stratification):
--   hubspotscore, lead_score_2_0, hs_predictivecontactscore_v2,
--   customer_health_score, new_member_health_score, ryan___lead_score_value,
--   snowflake__lead_score.
-- -----------------------------------------------------------------------------
WITH cohort_a AS (
    SELECT
          hc.object_id                                           AS hubspot_uid
        , DATE_TRUNC('month', TO_TIMESTAMP(
            TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000))::DATE AS signup_month
        , TRY_CAST(hc.properties:hubspotscore::string AS FLOAT)                 AS hubspotscore
        , TRY_CAST(hc.properties:lead_score_2_0::string AS FLOAT)               AS lead_score_2_0
        , TRY_CAST(hc.properties:hs_predictivecontactscore_v2::string AS FLOAT) AS hs_predictivecontactscore_v2
        , TRY_CAST(hc.properties:customer_health_score::string AS FLOAT)        AS customer_health_score
        , TRY_CAST(hc.properties:new_member_health_score::string AS FLOAT)      AS new_member_health_score
        , TRY_CAST(hc.properties:ryan___lead_score_value::string AS FLOAT)      AS ryan___lead_score_value
        , TRY_CAST(hc.properties:snowflake__lead_score::string AS FLOAT)        AS snowflake__lead_score
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
    WHERE hc.properties:lifecyclestage::string = 'subscriber'
      AND TRY_CAST(hc.properties:createdate::string AS BIGINT) IS NOT NULL
      AND TO_TIMESTAMP(TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000) >= '2025-08-01'
      AND TO_TIMESTAMP(TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000) <  '2026-05-01'
)
SELECT
      ca.signup_month
    , COUNT(*)                                                                  AS cohort_contacts

    , COUNT(ca.hubspotscore)                                                    AS hubspotscore_n
    , AVG(ca.hubspotscore)                                                      AS hubspotscore_mean
    , APPROX_PERCENTILE(ca.hubspotscore, 0.50)                                  AS hubspotscore_p50

    , COUNT(ca.lead_score_2_0)                                                  AS lead_score_2_0_n
    , AVG(ca.lead_score_2_0)                                                    AS lead_score_2_0_mean
    , APPROX_PERCENTILE(ca.lead_score_2_0, 0.50)                                AS lead_score_2_0_p50

    , COUNT(ca.hs_predictivecontactscore_v2)                                    AS hs_predictive_n
    , AVG(ca.hs_predictivecontactscore_v2)                                      AS hs_predictive_mean
    , APPROX_PERCENTILE(ca.hs_predictivecontactscore_v2, 0.50)                  AS hs_predictive_p50

    , COUNT(ca.customer_health_score)                                           AS customer_health_n
    , AVG(ca.customer_health_score)                                             AS customer_health_mean
    , APPROX_PERCENTILE(ca.customer_health_score, 0.50)                         AS customer_health_p50

    , COUNT(ca.new_member_health_score)                                         AS new_member_health_n
    , AVG(ca.new_member_health_score)                                           AS new_member_health_mean
    , APPROX_PERCENTILE(ca.new_member_health_score, 0.50)                       AS new_member_health_p50

    , COUNT(ca.ryan___lead_score_value)                                         AS ryan_score_n
    , AVG(ca.ryan___lead_score_value)                                           AS ryan_score_mean
    , APPROX_PERCENTILE(ca.ryan___lead_score_value, 0.50)                       AS ryan_score_p50

    , COUNT(ca.snowflake__lead_score)                                           AS snowflake_lead_n
    , AVG(ca.snowflake__lead_score)                                             AS snowflake_lead_mean
    , APPROX_PERCENTILE(ca.snowflake__lead_score, 0.50)                         AS snowflake_lead_p50
FROM cohort_a ca
GROUP BY ca.signup_month
ORDER BY ca.signup_month
;


-- -----------------------------------------------------------------------------
-- C2-alt -- Same matchmaker but for Cohort (b): has_free_account='true'
-- Purpose: Cohort (a) narrows to non-paying but known HubSpot contacts.
--   Cohort (b) uses a HubSpot custom property that may more closely match
--   Ryan's filter. Run both -- whichever produces the 0.5 -> 0.65 shift
--   pattern wins.
-- -----------------------------------------------------------------------------
WITH cohort_b AS (
    SELECT
          hc.object_id                                           AS hubspot_uid
        , DATE_TRUNC('month', TO_TIMESTAMP(
            TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000))::DATE AS signup_month
        , TRY_CAST(hc.properties:hubspotscore::string AS FLOAT)                 AS hubspotscore
        , TRY_CAST(hc.properties:lead_score_2_0::string AS FLOAT)               AS lead_score_2_0
        , TRY_CAST(hc.properties:hs_predictivecontactscore_v2::string AS FLOAT) AS hs_predictivecontactscore_v2
        , TRY_CAST(hc.properties:customer_health_score::string AS FLOAT)        AS customer_health_score
        , TRY_CAST(hc.properties:new_member_health_score::string AS FLOAT)      AS new_member_health_score
        , TRY_CAST(hc.properties:ryan___lead_score_value::string AS FLOAT)      AS ryan___lead_score_value
        , TRY_CAST(hc.properties:snowflake__lead_score::string AS FLOAT)        AS snowflake__lead_score
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
    WHERE LOWER(NULLIF(hc.properties:has_free_account::string, '')) = 'true'
      AND TRY_CAST(hc.properties:createdate::string AS BIGINT) IS NOT NULL
      AND TO_TIMESTAMP(TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000) >= '2025-08-01'
      AND TO_TIMESTAMP(TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000) <  '2026-05-01'
)
SELECT
      cb.signup_month
    , COUNT(*)                                                                  AS cohort_contacts
    , COUNT(cb.hubspotscore)                                                    AS hubspotscore_n
    , AVG(cb.hubspotscore)                                                      AS hubspotscore_mean
    , COUNT(cb.lead_score_2_0)                                                  AS lead_score_2_0_n
    , AVG(cb.lead_score_2_0)                                                    AS lead_score_2_0_mean
    , COUNT(cb.hs_predictivecontactscore_v2)                                    AS hs_predictive_n
    , AVG(cb.hs_predictivecontactscore_v2)                                      AS hs_predictive_mean
    , COUNT(cb.customer_health_score)                                           AS customer_health_n
    , AVG(cb.customer_health_score)                                             AS customer_health_mean
    , COUNT(cb.new_member_health_score)                                         AS new_member_health_n
    , AVG(cb.new_member_health_score)                                           AS new_member_health_mean
    , COUNT(cb.ryan___lead_score_value)                                         AS ryan_score_n
    , AVG(cb.ryan___lead_score_value)                                           AS ryan_score_mean
    , COUNT(cb.snowflake__lead_score)                                           AS snowflake_lead_n
    , AVG(cb.snowflake__lead_score)                                             AS snowflake_lead_mean
FROM cohort_b cb
GROUP BY cb.signup_month
ORDER BY cb.signup_month
;


-- -----------------------------------------------------------------------------
-- C3 -- Score-bucket distribution per month (shift-share decomposition, §5)
-- Purpose: once C2 reveals Ryan's field, this query decomposes the 0.5 -> 0.65
--   move into: mean-shift (whole distribution moves), tail-shift (fat tail
--   appears in Feb+), or null-shift (more high-score contacts, same low-score
--   population). RUN WITH [FIELD] SUBSTITUTED once C2 identifies it.
-- Default below targets snowflake__lead_score since it's the most-likely
--   candidate for the 0.5-0.65 range given the pipeline math. For any other
--   field, swap in the field's expression in place of the snowflake__lead_score
--   cast below.
-- -----------------------------------------------------------------------------
WITH scored AS (
    SELECT
          DATE_TRUNC('month', TO_TIMESTAMP(
            TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000))::DATE AS signup_month
        , TRY_CAST(hc.properties:snowflake__lead_score::string AS FLOAT)        AS score
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
    WHERE hc.properties:lifecyclestage::string = 'subscriber'
      AND TRY_CAST(hc.properties:createdate::string AS BIGINT) IS NOT NULL
      AND TO_TIMESTAMP(TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000) >= '2025-08-01'
      AND TO_TIMESTAMP(TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000) <  '2026-05-01'
)
SELECT
      scored.signup_month
    , COUNT(*)                                                                  AS cohort_contacts
    , COUNT(scored.score)                                                       AS contacts_with_score
    , COUNT_IF(scored.score < 0.3)                                              AS bucket_0_to_0p3
    , COUNT_IF(scored.score >= 0.3 AND scored.score < 0.5)                      AS bucket_0p3_to_0p5
    , COUNT_IF(scored.score >= 0.5 AND scored.score < 0.65)                     AS bucket_0p5_to_0p65
    , COUNT_IF(scored.score >= 0.65 AND scored.score < 0.8)                     AS bucket_0p65_to_0p8
    , COUNT_IF(scored.score >= 0.8)                                             AS bucket_0p8_plus
FROM scored
GROUP BY scored.signup_month
ORDER BY scored.signup_month
;


-- -----------------------------------------------------------------------------
-- C4 -- Monthly cohort volume by hs_analytics_source (population composition)
-- Purpose: did Feb's cohort composition change? A 30% mean-score jump can
--   arise purely from source-mix shift if high-source and low-source buckets
--   score differently.
-- -----------------------------------------------------------------------------
WITH cohort_a AS (
    SELECT
          DATE_TRUNC('month', TO_TIMESTAMP(
            TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000))::DATE AS signup_month
        , COALESCE(hc.properties:hs_analytics_source::string, 'UNKNOWN')        AS analytics_source
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
    WHERE hc.properties:lifecyclestage::string = 'subscriber'
      AND TRY_CAST(hc.properties:createdate::string AS BIGINT) IS NOT NULL
      AND TO_TIMESTAMP(TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000) >= '2025-08-01'
      AND TO_TIMESTAMP(TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000) <  '2026-05-01'
)
SELECT
      cohort_a.signup_month
    , cohort_a.analytics_source
    , COUNT(*)                                                                  AS contacts
FROM cohort_a
GROUP BY 1, 2
ORDER BY 1, 3 DESC
;


-- -----------------------------------------------------------------------------
-- C5 -- Per-source monthly mean score (isolates uniform vs. source-specific shift)
-- Purpose: if mean shift is uniform across sources, suggests scoring rule
--   change. If source-specific, suggests composition / channel-launch change.
-- Targets snowflake__lead_score; swap field if C2 identifies a different one.
-- -----------------------------------------------------------------------------
WITH cohort_a AS (
    SELECT
          DATE_TRUNC('month', TO_TIMESTAMP(
            TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000))::DATE AS signup_month
        , COALESCE(hc.properties:hs_analytics_source::string, 'UNKNOWN')        AS analytics_source
        , TRY_CAST(hc.properties:snowflake__lead_score::string AS FLOAT)        AS score
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
    WHERE hc.properties:lifecyclestage::string = 'subscriber'
      AND TRY_CAST(hc.properties:createdate::string AS BIGINT) IS NOT NULL
      AND TO_TIMESTAMP(TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000) >= '2025-08-01'
      AND TO_TIMESTAMP(TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000) <  '2026-05-01'
)
SELECT
      cohort_a.signup_month
    , cohort_a.analytics_source
    , COUNT(*)                                                                  AS contacts
    , COUNT(cohort_a.score)                                                     AS contacts_with_score
    , AVG(cohort_a.score)                                                       AS mean_score
FROM cohort_a
GROUP BY 1, 2
ORDER BY 1, 3 DESC
;


-- -----------------------------------------------------------------------------
-- C6 -- Monthly null-rate for each candidate score field
-- Purpose: if Feb 2026 suddenly had more contacts scored (Polytomic started
--   writing more / fewer), mean jumps mechanically if the newly-written scores
--   cluster higher than the un-written average.
-- RATE: score_null_rate
-- NUMERATOR: cohort_a contacts with null score for that field
-- DENOMINATOR: cohort_a contacts in signup_month
-- TYPE: unscored / all-in-cohort
-- NOT: fraction of scored contacts with a specific value -- this is coverage, not value.
-- -----------------------------------------------------------------------------
WITH cohort_a AS (
    SELECT
          DATE_TRUNC('month', TO_TIMESTAMP(
            TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000))::DATE AS signup_month
        , hc.properties:hubspotscore::string                                    AS hubspotscore_raw
        , hc.properties:lead_score_2_0::string                                  AS lead_score_2_0_raw
        , hc.properties:hs_predictivecontactscore_v2::string                    AS hs_predictive_raw
        , hc.properties:customer_health_score::string                           AS customer_health_raw
        , hc.properties:new_member_health_score::string                         AS new_member_health_raw
        , hc.properties:ryan___lead_score_value::string                         AS ryan_score_raw
        , hc.properties:snowflake__lead_score::string                           AS snowflake_lead_raw
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
    WHERE hc.properties:lifecyclestage::string = 'subscriber'
      AND TRY_CAST(hc.properties:createdate::string AS BIGINT) IS NOT NULL
      AND TO_TIMESTAMP(TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000) >= '2025-08-01'
      AND TO_TIMESTAMP(TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000) <  '2026-05-01'
)
SELECT
      cohort_a.signup_month
    , COUNT(*)                                                                  AS cohort_contacts
    , ROUND(COUNT_IF(cohort_a.hubspotscore_raw IS NULL)         * 100.0 / COUNT(*), 2) AS hubspotscore_null_pct
    , ROUND(COUNT_IF(cohort_a.lead_score_2_0_raw IS NULL)       * 100.0 / COUNT(*), 2) AS lead_score_2_0_null_pct
    , ROUND(COUNT_IF(cohort_a.hs_predictive_raw IS NULL)        * 100.0 / COUNT(*), 2) AS hs_predictive_null_pct
    , ROUND(COUNT_IF(cohort_a.customer_health_raw IS NULL)      * 100.0 / COUNT(*), 2) AS customer_health_null_pct
    , ROUND(COUNT_IF(cohort_a.new_member_health_raw IS NULL)    * 100.0 / COUNT(*), 2) AS new_member_health_null_pct
    , ROUND(COUNT_IF(cohort_a.ryan_score_raw IS NULL)           * 100.0 / COUNT(*), 2) AS ryan_score_null_pct
    , ROUND(COUNT_IF(cohort_a.snowflake_lead_raw IS NULL)       * 100.0 / COUNT(*), 2) AS snowflake_lead_null_pct
FROM cohort_a
GROUP BY cohort_a.signup_month
ORDER BY cohort_a.signup_month
;


-- -----------------------------------------------------------------------------
-- C10 -- Signup-month x write-month cross-tab (nails down the actual timing)
-- Purpose: settle the open question of why the cohort mean shifts at Feb 2026
--   specifically. For has_free_account='true' contacts with snowflake__lead_score
--   populated, cross-tab signup_month x polytomic_write_month (from
--   snowflake__update_at) x count x mean_score.
-- Reading the output: a Dec 2025 signup-month row should show when those contacts
--   got their scores written and what the mean of those writes is. Matched against
--   B7 (daily model-output mean) this reveals whether Dec signups got written with
--   (a) old-model scores from a stale backlog, (b) new-model scores that happen
--   to be low for this subset, or (c) they simply have not been written yet and
--   the 1,494 "scored" Dec signups are a non-representative early-enriched minority.
-- -----------------------------------------------------------------------------
WITH typed AS (
    SELECT
          hc.object_id                                           AS hubspot_uid
        , DATE_TRUNC('month', TO_TIMESTAMP(
            TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000))::DATE AS signup_month
        , DATE_TRUNC('month', TO_TIMESTAMP(
            TRY_CAST(hc.properties:snowflake__update_at::string AS BIGINT) / 1000))::DATE AS write_month
        , TRY_CAST(hc.properties:snowflake__lead_score::string AS FLOAT)        AS lead_score
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
    WHERE LOWER(NULLIF(hc.properties:has_free_account::string, '')) = 'true'
      AND TRY_CAST(hc.properties:snowflake__lead_score::string AS FLOAT) IS NOT NULL
      AND TRY_CAST(hc.properties:snowflake__update_at::string AS BIGINT) IS NOT NULL
      AND TRY_CAST(hc.properties:createdate::string AS BIGINT) IS NOT NULL
      AND TO_TIMESTAMP(TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000) >= '2025-08-01'
      AND TO_TIMESTAMP(TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000) <  '2026-05-01'
)
SELECT
      typed.signup_month
    , typed.write_month
    , COUNT(*)                                                  AS contacts
    , AVG(typed.lead_score)                                     AS mean_score
FROM typed
GROUP BY 1, 2
ORDER BY 1, 2
;


-- -----------------------------------------------------------------------------
-- C9 -- Per-contact Polytomic write-back timing via snowflake__update_at
-- Purpose: A3 inventory revealed snowflake__update_at exists on 1.51% of
--   contacts (matching snowflake__lead_score coverage ~1.52%). Assume this is
--   Polytomic's per-contact last-sync timestamp. Monthly histogram reveals
--   when Polytomic wrote scores back to each contact -- independent of when
--   the contact signed up.
-- -----------------------------------------------------------------------------
WITH typed AS (
    SELECT
          hc.object_id
        , TRY_CAST(hc.properties:snowflake__lead_score::string AS FLOAT) AS lead_score
        , TRY_CAST(hc.properties:snowflake__update_at::string AS BIGINT) AS update_at_millis
        , DATE_TRUNC('month', TO_TIMESTAMP(
            TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000))::DATE AS signup_month
        , hc.properties:lifecyclestage::string                  AS lifecyclestage
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
    WHERE TRY_CAST(hc.properties:snowflake__lead_score::string AS FLOAT) IS NOT NULL
)
SELECT
      DATE_TRUNC('month', TO_TIMESTAMP(typed.update_at_millis / 1000))::DATE AS polytomic_write_month
    , typed.lifecyclestage
    , COUNT(*)                                                  AS contacts_written
    , AVG(typed.lead_score)                                     AS mean_score_written
    , APPROX_PERCENTILE(typed.lead_score, 0.50)                 AS p50_score_written
FROM typed
WHERE typed.update_at_millis IS NOT NULL
GROUP BY 1, 2
ORDER BY 1, 2
;


-- -----------------------------------------------------------------------------
-- C7 -- Polytomic write-back timing: when did snowflake__lead_score populate?
-- Purpose: separates signup-month from score-assignment-time. If many free
--   signups from Aug 2025 got their first score in Feb 2026, their contribution
--   to Feb's mean is driven by backfill, not by Feb sign-ups being qualitatively
--   different.
-- Data path: soundstripe_prod._external_polytomic.polytomic_sync_hubspot_leads_with_scores
--   is the incremental queue that writes to HubSpot. lead_score_ts is the
--   warehouse-side timestamp at which the model scored the contact.
-- -----------------------------------------------------------------------------
-- Note (2026-04-15): cohort_a (subscriber stage) returned NULL for every month
-- in C1 because "subscriber" lifecyclestage + createdate-in-window finds very
-- few rows (subscriber is mostly historical). has_free_account='true' (cohort_b)
-- returns the actual free-signup population. Using cohort_b here for alignment
-- with Ryan's data. Also quoted the polytomic column names per the schema
-- preservation quirk that surfaced in B3/B5.
WITH signup_score AS (
    SELECT
          hc.object_id                                           AS hubspot_uid
        , DATE_TRUNC('month', TO_TIMESTAMP(
            TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000))::DATE AS signup_month
        , psh."lead_score_ts"                                    AS warehouse_score_ts
        , DATE_TRUNC('month', psh."lead_score_ts")::DATE         AS score_month
        , TRY_CAST(psh."lead_score" AS FLOAT)                    AS lead_score
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
        INNER JOIN soundstripe_prod._external_polytomic.polytomic_sync_hubspot_leads_with_scores psh
            ON hc.object_id = psh.hubspot_uid
    WHERE LOWER(NULLIF(hc.properties:has_free_account::string, '')) = 'true'
      AND TRY_CAST(hc.properties:createdate::string AS BIGINT) IS NOT NULL
      AND TO_TIMESTAMP(TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000) >= '2025-08-01'
      AND TO_TIMESTAMP(TRY_CAST(hc.properties:createdate::string AS BIGINT) / 1000) <  '2026-05-01'
)
SELECT
      ss.signup_month
    , ss.score_month
    , COUNT(*)                                                                  AS scored_contacts
    , AVG(ss.lead_score)                                                        AS mean_score
FROM signup_score ss
GROUP BY 1, 2
ORDER BY 1, 2
;
