-- =============================================================================
-- Phase A: HubSpot Contacts Object Discovery
-- =============================================================================
-- Purpose: establish the full warehouse-level shape of
--   soundstripe_prod.hubspot.hubspot_contacts to inform the forthcoming
--   knowledge-base article on the HubSpot contacts object, and to narrow the
--   candidate-score-field list for the Phase C Ryan Feb-shift diagnostic.
-- Source table: soundstripe_prod.hubspot.hubspot_contacts
--   (view over hubspot_objects_with_type filtered to object_type = 'CONTACT';
--    PROPERTIES is a flat JSON object, e.g. properties:email::string)
-- Export convention: each query result exported as aN.csv into this folder.
-- Author: d7admin via Claude, 2026-04-15
-- =============================================================================


-- -----------------------------------------------------------------------------
-- A1 -- Object-type distribution + ingest freshness
-- Purpose: confirm every row has objecttypeid='0-1'/object_type='CONTACT',
--   get row count and ingest_ts window.
-- -----------------------------------------------------------------------------
SELECT
      hc.objecttypeid
    , hc.object_type
    , COUNT(*)                                                AS row_count
    , COUNT(DISTINCT hc.object_id)                            AS distinct_object_id_count
    , MIN(hc.ingest_ts)                                       AS earliest_ingest_ts
    , MAX(hc.ingest_ts)                                       AS latest_ingest_ts
FROM soundstripe_prod.hubspot.hubspot_contacts hc
GROUP BY 1, 2
ORDER BY row_count DESC
;


-- -----------------------------------------------------------------------------
-- A2 -- SOUNDSTRIPE_INTERNAL_ACCOUNT distribution
-- Purpose: the 50-row sample was all FALSE. Confirm true/false/null split at
--   warehouse scope. Internal_account=TRUE means hs_internal_user_id is populated.
-- RATE: internal_account_rate
-- NUMERATOR: contacts with soundstripe_internal_account = TRUE
-- DENOMINATOR: all contacts
-- TYPE: internal-flagged / all-contacts
-- NOT: contacts with soundstripe_user_id populated -- that's a DIFFERENT column
--   (soundstripe_user_id flags having an external user account; hs_internal_user_id
--    flags employee-side accounts).
-- -----------------------------------------------------------------------------
SELECT
      hc.soundstripe_internal_account
    , COUNT(*)                                                AS row_count
    , ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)      AS pct_of_total
FROM soundstripe_prod.hubspot.hubspot_contacts hc
GROUP BY 1
ORDER BY row_count DESC
;


-- -----------------------------------------------------------------------------
-- A3 -- PROPERTIES key inventory with population rates
-- Purpose: enumerate every distinct key that appears in PROPERTIES across a
--   stratified sample. Output: one row per key with populated_rows, sample_n,
--   populated_pct. This is the authoritative property list for the KB article.
-- Sampling: BERNOULLI(1) -- 1% of rows. For a table with millions of rows this
--   should still produce 10K-100K sample rows, adequate for key-presence.
-- RATE: key_population_rate
-- NUMERATOR: sample rows where the flattened key has a non-null/non-empty value
-- DENOMINATOR: sampled rows
-- TYPE: rows-with-key / sampled-rows
-- NOT: distinct values of the key -- we want presence, not value diversity.
-- -----------------------------------------------------------------------------
WITH sampled AS (
    SELECT
          hc.object_id
        , hc.properties
    FROM soundstripe_prod.hubspot.hubspot_contacts hc SAMPLE BERNOULLI (1)
)
, sample_size AS (
    SELECT COUNT(*) AS n FROM sampled
)
, flat AS (
    SELECT
          s.object_id
        , f.key                                               AS property_key
        , f.value                                             AS property_value
    FROM sampled s
       , LATERAL FLATTEN (INPUT => s.properties) f
    WHERE f.value IS NOT NULL
      AND TO_VARCHAR(f.value) NOT IN ('', 'null')
)
SELECT
      flat.property_key
    , COUNT(DISTINCT flat.object_id)                          AS populated_rows
    , (SELECT n FROM sample_size)                             AS sample_n
    , ROUND(COUNT(DISTINCT flat.object_id) * 100.0 / (SELECT n FROM sample_size), 3)
                                                              AS populated_pct
FROM flat
GROUP BY 1
ORDER BY populated_rows DESC
;


-- -----------------------------------------------------------------------------
-- A4 -- lifecyclestage full distinct-value distribution
-- Purpose: 50-row sample showed 3 values (lead, subscriber, customer).
--   Enumerate the full set from the warehouse.
-- -----------------------------------------------------------------------------
SELECT
      hc.properties:lifecyclestage::string                    AS lifecyclestage
    , COUNT(*)                                                AS row_count
    , ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)      AS pct_of_total
FROM soundstripe_prod.hubspot.hubspot_contacts hc
GROUP BY 1
ORDER BY row_count DESC
;


-- -----------------------------------------------------------------------------
-- A5a -- hs_predictivescoringtier distribution
-- -----------------------------------------------------------------------------
SELECT
      hc.properties:hs_predictivescoringtier::string          AS predictive_scoring_tier
    , COUNT(*)                                                AS row_count
    , ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)      AS pct_of_total
FROM soundstripe_prod.hubspot.hubspot_contacts hc
GROUP BY 1
ORDER BY row_count DESC
;


-- -----------------------------------------------------------------------------
-- A5b -- hs_analytics_source distribution
-- -----------------------------------------------------------------------------
SELECT
      hc.properties:hs_analytics_source::string               AS analytics_source
    , COUNT(*)                                                AS row_count
    , ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)      AS pct_of_total
FROM soundstripe_prod.hubspot.hubspot_contacts hc
GROUP BY 1
ORDER BY row_count DESC
;


-- -----------------------------------------------------------------------------
-- A5c -- hs_latest_source distribution
-- -----------------------------------------------------------------------------
SELECT
      hc.properties:hs_latest_source::string                  AS latest_source
    , COUNT(*)                                                AS row_count
    , ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)      AS pct_of_total
FROM soundstripe_prod.hubspot.hubspot_contacts hc
GROUP BY 1
ORDER BY row_count DESC
;


-- -----------------------------------------------------------------------------
-- A5d -- hs_object_source_label distribution
-- -----------------------------------------------------------------------------
SELECT
      hc.properties:hs_object_source_label::string            AS object_source_label
    , COUNT(*)                                                AS row_count
    , ROUND(COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (), 2)      AS pct_of_total
FROM soundstripe_prod.hubspot.hubspot_contacts hc
GROUP BY 1
ORDER BY row_count DESC
;


-- -----------------------------------------------------------------------------
-- A6 -- snowflake__lead_score presence and value distribution
-- Purpose: snowflake__lead_score is the Polytomic write-back field from the
--   enterprise XGBoost pipeline. The 50-row sample did NOT contain it, confirming
--   it only populates for enterprise-scored leads. Quantify coverage + range
--   across the full table.
-- RATE: snowflake_lead_score_coverage
-- NUMERATOR: contacts with non-null snowflake__lead_score
-- DENOMINATOR: all contacts
-- TYPE: scored-contacts / all-contacts
-- NOT: contacts with ANY score populated -- we want this specific field's coverage.
-- -----------------------------------------------------------------------------
WITH typed AS (
    SELECT
          TRY_CAST(hc.properties:snowflake__lead_score::string AS FLOAT) AS snowflake_lead_score
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
)
SELECT
      COUNT(*)                                                AS total_contacts
    , COUNT(typed.snowflake_lead_score)                       AS contacts_with_score
    , ROUND(COUNT(typed.snowflake_lead_score) * 100.0 / COUNT(*), 3)
                                                              AS pct_with_score
    , MIN(typed.snowflake_lead_score)                         AS min_score
    , MAX(typed.snowflake_lead_score)                         AS max_score
    , AVG(typed.snowflake_lead_score)                         AS mean_score
    , STDDEV(typed.snowflake_lead_score)                      AS stddev_score
    , APPROX_PERCENTILE(typed.snowflake_lead_score, 0.10)     AS p10
    , APPROX_PERCENTILE(typed.snowflake_lead_score, 0.25)     AS p25
    , APPROX_PERCENTILE(typed.snowflake_lead_score, 0.50)     AS p50
    , APPROX_PERCENTILE(typed.snowflake_lead_score, 0.75)     AS p75
    , APPROX_PERCENTILE(typed.snowflake_lead_score, 0.90)     AS p90
FROM typed
;


-- -----------------------------------------------------------------------------
-- A7a -- hs_predictivecontactscore_v2 overall distribution
-- Purpose: HubSpot native predictive score. 50-row sample showed 0.17-2.95 range.
--   Verify at warehouse scope -- this is a top candidate for Ryan's reported
--   0.5-to-0.65 monthly-mean shift.
-- -----------------------------------------------------------------------------
WITH typed AS (
    SELECT
          TRY_CAST(hc.properties:hs_predictivecontactscore_v2::string AS FLOAT) AS score
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
)
SELECT
      COUNT(*)                                                AS total_contacts
    , COUNT(typed.score)                                      AS contacts_with_score
    , ROUND(COUNT(typed.score) * 100.0 / COUNT(*), 3)         AS pct_with_score
    , MIN(typed.score)                                        AS min_score
    , MAX(typed.score)                                        AS max_score
    , AVG(typed.score)                                        AS mean_score
    , STDDEV(typed.score)                                     AS stddev_score
    , APPROX_PERCENTILE(typed.score, 0.10)                    AS p10
    , APPROX_PERCENTILE(typed.score, 0.25)                    AS p25
    , APPROX_PERCENTILE(typed.score, 0.50)                    AS p50
    , APPROX_PERCENTILE(typed.score, 0.75)                    AS p75
    , APPROX_PERCENTILE(typed.score, 0.90)                    AS p90
FROM typed
;


-- -----------------------------------------------------------------------------
-- A7b -- hs_predictivecontactscore_v2 by lifecyclestage
-- Purpose: surface whether score range varies with stage. If Ryan's 0.5-to-0.65
--   shift tracks subscriber-stage contacts specifically, that narrows causality.
-- -----------------------------------------------------------------------------
WITH typed AS (
    SELECT
          hc.properties:lifecyclestage::string                AS lifecyclestage
        , TRY_CAST(hc.properties:hs_predictivecontactscore_v2::string AS FLOAT) AS score
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
)
SELECT
      typed.lifecyclestage
    , COUNT(*)                                                AS contacts
    , COUNT(typed.score)                                      AS with_score
    , ROUND(COUNT(typed.score) * 100.0 / COUNT(*), 3)         AS pct_with_score
    , AVG(typed.score)                                        AS mean_score
    , APPROX_PERCENTILE(typed.score, 0.25)                    AS p25
    , APPROX_PERCENTILE(typed.score, 0.50)                    AS p50
    , APPROX_PERCENTILE(typed.score, 0.75)                    AS p75
    , APPROX_PERCENTILE(typed.score, 0.90)                    AS p90
FROM typed
GROUP BY 1
ORDER BY contacts DESC
;


-- -----------------------------------------------------------------------------
-- A8 -- Remaining scoring-field distributions (UNION ALL for single export)
-- Purpose: get min/max/mean/percentiles + population for each non-A6/A7 score
--   field in one result so a8.csv is a single scan-friendly table. Fields:
--   hubspotscore, lead_score_2_0, customer_health_score, new_member_health_score,
--   ryan___lead_score_value.
-- -----------------------------------------------------------------------------
WITH hubspotscore AS (
    SELECT
          'hubspotscore'::string                              AS field_name
        , COUNT(*)                                            AS total
        , COUNT(TRY_CAST(hc.properties:hubspotscore::string AS FLOAT)) AS populated
        , MIN(TRY_CAST(hc.properties:hubspotscore::string AS FLOAT))   AS min_v
        , MAX(TRY_CAST(hc.properties:hubspotscore::string AS FLOAT))   AS max_v
        , AVG(TRY_CAST(hc.properties:hubspotscore::string AS FLOAT))   AS mean_v
        , APPROX_PERCENTILE(TRY_CAST(hc.properties:hubspotscore::string AS FLOAT), 0.10) AS p10
        , APPROX_PERCENTILE(TRY_CAST(hc.properties:hubspotscore::string AS FLOAT), 0.50) AS p50
        , APPROX_PERCENTILE(TRY_CAST(hc.properties:hubspotscore::string AS FLOAT), 0.90) AS p90
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
)
, lead_score_2_0 AS (
    SELECT
          'lead_score_2_0'::string                            AS field_name
        , COUNT(*)                                            AS total
        , COUNT(TRY_CAST(hc.properties:lead_score_2_0::string AS FLOAT)) AS populated
        , MIN(TRY_CAST(hc.properties:lead_score_2_0::string AS FLOAT))   AS min_v
        , MAX(TRY_CAST(hc.properties:lead_score_2_0::string AS FLOAT))   AS max_v
        , AVG(TRY_CAST(hc.properties:lead_score_2_0::string AS FLOAT))   AS mean_v
        , APPROX_PERCENTILE(TRY_CAST(hc.properties:lead_score_2_0::string AS FLOAT), 0.10) AS p10
        , APPROX_PERCENTILE(TRY_CAST(hc.properties:lead_score_2_0::string AS FLOAT), 0.50) AS p50
        , APPROX_PERCENTILE(TRY_CAST(hc.properties:lead_score_2_0::string AS FLOAT), 0.90) AS p90
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
)
, customer_health AS (
    SELECT
          'customer_health_score'::string                     AS field_name
        , COUNT(*)                                            AS total
        , COUNT(TRY_CAST(hc.properties:customer_health_score::string AS FLOAT)) AS populated
        , MIN(TRY_CAST(hc.properties:customer_health_score::string AS FLOAT))   AS min_v
        , MAX(TRY_CAST(hc.properties:customer_health_score::string AS FLOAT))   AS max_v
        , AVG(TRY_CAST(hc.properties:customer_health_score::string AS FLOAT))   AS mean_v
        , APPROX_PERCENTILE(TRY_CAST(hc.properties:customer_health_score::string AS FLOAT), 0.10) AS p10
        , APPROX_PERCENTILE(TRY_CAST(hc.properties:customer_health_score::string AS FLOAT), 0.50) AS p50
        , APPROX_PERCENTILE(TRY_CAST(hc.properties:customer_health_score::string AS FLOAT), 0.90) AS p90
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
)
, new_member_health AS (
    SELECT
          'new_member_health_score'::string                   AS field_name
        , COUNT(*)                                            AS total
        , COUNT(TRY_CAST(hc.properties:new_member_health_score::string AS FLOAT)) AS populated
        , MIN(TRY_CAST(hc.properties:new_member_health_score::string AS FLOAT))   AS min_v
        , MAX(TRY_CAST(hc.properties:new_member_health_score::string AS FLOAT))   AS max_v
        , AVG(TRY_CAST(hc.properties:new_member_health_score::string AS FLOAT))   AS mean_v
        , APPROX_PERCENTILE(TRY_CAST(hc.properties:new_member_health_score::string AS FLOAT), 0.10) AS p10
        , APPROX_PERCENTILE(TRY_CAST(hc.properties:new_member_health_score::string AS FLOAT), 0.50) AS p50
        , APPROX_PERCENTILE(TRY_CAST(hc.properties:new_member_health_score::string AS FLOAT), 0.90) AS p90
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
)
, ryan_score AS (
    SELECT
          'ryan___lead_score_value'::string                   AS field_name
        , COUNT(*)                                            AS total
        , COUNT(TRY_CAST(hc.properties:ryan___lead_score_value::string AS FLOAT)) AS populated
        , MIN(TRY_CAST(hc.properties:ryan___lead_score_value::string AS FLOAT))   AS min_v
        , MAX(TRY_CAST(hc.properties:ryan___lead_score_value::string AS FLOAT))   AS max_v
        , AVG(TRY_CAST(hc.properties:ryan___lead_score_value::string AS FLOAT))   AS mean_v
        , APPROX_PERCENTILE(TRY_CAST(hc.properties:ryan___lead_score_value::string AS FLOAT), 0.10) AS p10
        , APPROX_PERCENTILE(TRY_CAST(hc.properties:ryan___lead_score_value::string AS FLOAT), 0.50) AS p50
        , APPROX_PERCENTILE(TRY_CAST(hc.properties:ryan___lead_score_value::string AS FLOAT), 0.90) AS p90
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
)
SELECT * FROM hubspotscore
UNION ALL SELECT * FROM lead_score_2_0
UNION ALL SELECT * FROM customer_health
UNION ALL SELECT * FROM new_member_health
UNION ALL SELECT * FROM ryan_score
ORDER BY field_name
;


-- -----------------------------------------------------------------------------
-- A9 -- became_* field enumeration with observed date windows
-- Purpose: enumerate every PROPERTIES key starting with 'became_', with
--   population count and min/max date interpreting value as unix millis.
-- Sampling: BERNOULLI(5) to keep flatten tractable.
-- -----------------------------------------------------------------------------
WITH sampled AS (
    SELECT
          hc.object_id
        , hc.properties
    FROM soundstripe_prod.hubspot.hubspot_contacts hc SAMPLE BERNOULLI (5)
)
, flat AS (
    SELECT
          s.object_id
        , f.key                                               AS property_key
        , TRY_CAST(TO_VARCHAR(f.value) AS BIGINT)             AS value_millis
    FROM sampled s
       , LATERAL FLATTEN (INPUT => s.properties) f
    WHERE f.key LIKE 'became_%'
      AND f.value IS NOT NULL
      AND TO_VARCHAR(f.value) NOT IN ('', 'null')
)
SELECT
      flat.property_key
    , COUNT(DISTINCT flat.object_id)                          AS populated_rows
    , MIN(TO_TIMESTAMP(flat.value_millis / 1000))             AS earliest_date
    , MAX(TO_TIMESTAMP(flat.value_millis / 1000))             AS latest_date
FROM flat
GROUP BY 1
ORDER BY populated_rows DESC
;


-- -----------------------------------------------------------------------------
-- A10 -- scoring-field *_last_changed timestamp presence
-- Purpose: the 50-row sample lacked per-field last-changed timestamps. Confirm
--   at warehouse scope whether ANY score-related last-changed fields exist.
--   If they do, Phase C can bucket score-change events temporally.
-- Sampling: BERNOULLI(1) -- 1% sample is fine for presence testing.
-- -----------------------------------------------------------------------------
WITH sampled AS (
    SELECT hc.properties
    FROM soundstripe_prod.hubspot.hubspot_contacts hc SAMPLE BERNOULLI (1)
)
, flat AS (
    SELECT
          f.key                                               AS property_key
        , f.value                                             AS property_value
    FROM sampled s
       , LATERAL FLATTEN (INPUT => s.properties) f
    WHERE ( f.key ILIKE '%score%last%changed%'
         OR f.key ILIKE '%lead_score%last%'
         OR f.key ILIKE '%predictive%last%'
         OR f.key ILIKE '%_last_changed%'
         OR f.key ILIKE '%_last_change_%' )
      AND f.value IS NOT NULL
      AND TO_VARCHAR(f.value) NOT IN ('', 'null')
)
SELECT
      flat.property_key
    , COUNT(*)                                                AS populated_rows
FROM flat
GROUP BY 1
ORDER BY populated_rows DESC
;


-- -----------------------------------------------------------------------------
-- A11 -- Identity-key co-occurrence
-- Purpose: quantify the "free-only" population (email without billing IDs) and
--   the full identity-key matrix. Drives Phase C cohort definition (a).
-- RATE: identity_combination_rate
-- NUMERATOR: contacts matching the specific identity combination
-- DENOMINATOR: all contacts
-- TYPE: combination-matching-contacts / all-contacts
-- NOT: contacts with any of the three populated -- we want specific combinations.
-- -----------------------------------------------------------------------------
WITH keys AS (
    SELECT
          hc.object_id
        , NULLIF(hc.properties:email::string, '')                     AS email
        , NULLIF(hc.properties:soundstripe_user_id::string, '')       AS soundstripe_user_id
        , NULLIF(hc.properties:chargebee_customer_id::string, '')     AS chargebee_customer_id
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
)
SELECT
      COUNT(*)                                                AS total_contacts
    , COUNT(keys.email)                                       AS has_email
    , COUNT(keys.soundstripe_user_id)                         AS has_soundstripe_user_id
    , COUNT(keys.chargebee_customer_id)                       AS has_chargebee_customer_id
    , COUNT_IF(keys.email IS NOT NULL
             AND keys.soundstripe_user_id IS NULL
             AND keys.chargebee_customer_id IS NULL)          AS email_only
    , COUNT_IF(keys.email IS NOT NULL
             AND keys.soundstripe_user_id IS NOT NULL
             AND keys.chargebee_customer_id IS NULL)          AS email_and_ss_only
    , COUNT_IF(keys.email IS NOT NULL
             AND keys.soundstripe_user_id IS NULL
             AND keys.chargebee_customer_id IS NOT NULL)      AS email_and_cb_only
    , COUNT_IF(keys.email IS NOT NULL
             AND keys.soundstripe_user_id IS NOT NULL
             AND keys.chargebee_customer_id IS NOT NULL)      AS all_three
    , COUNT_IF(keys.email IS NULL)                            AS email_missing
FROM keys
;


-- -----------------------------------------------------------------------------
-- A12 -- Per-lifecyclestage ingest_ts vs. lastmodifieddate freshness lag
-- Purpose: understand data freshness. If lastmodifieddate trails ingest_ts for
--   any stage, that signals sync delay for that cohort -- relevant context for
--   whether Feb 2026 score means reflect Feb activity or later ingestion.
-- -----------------------------------------------------------------------------
WITH typed AS (
    SELECT
          hc.properties:lifecyclestage::string                AS lifecyclestage
        , hc.ingest_ts
        , TRY_CAST(hc.properties:lastmodifieddate::string AS BIGINT) AS lastmod_millis
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
)
SELECT
      typed.lifecyclestage
    , COUNT(*)                                                AS contacts
    , MAX(typed.ingest_ts)                                    AS max_ingest_ts
    , MAX(TO_TIMESTAMP(typed.lastmod_millis / 1000))          AS max_lastmod
    , DATEDIFF('minute'
        , MAX(TO_TIMESTAMP(typed.lastmod_millis / 1000))
        , MAX(typed.ingest_ts))                               AS ingest_minus_lastmod_min
FROM typed
GROUP BY 1
ORDER BY contacts DESC
;
