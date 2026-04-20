-- =============================================================================
-- Phase B: Enterprise Lead-Scoring Pipeline Shape
-- =============================================================================
-- Purpose: verify pipeline health, threshold validity, warehouse-to-HubSpot
--   sync completeness, and lead-type composition drift -- all prerequisites
--   for the Phase C Ryan Feb-shift diagnostic and the forthcoming lead-scoring
--   KB article.
-- Pipeline (see CLAUDE.md for the full diagram):
--   dim_hubspot_customer + pql_pre_append + dtc_upsell_pre_append
--     -> enterprise_lead_scoring_model (XGBoost, RETRAINS every dbt run)
--     -> hubspot_leads_with_scores (cast + probability bucket)
--     -> polytomic_sync_hubspot_leads_with_scores (anti-join to filter written)
--     -> Polytomic -> HUBSPOT.HUBSPOT_CONTACTS.properties:snowflake__lead_score
-- Export convention: each query result as bN.csv into this folder.
-- Author: d7admin via Claude, 2026-04-15
-- =============================================================================


-- -----------------------------------------------------------------------------
-- B1 -- dim_enterprise_leads shape + monthly composition Aug 2025 - Apr 2026
-- Purpose: confirm table health, range of lead_start_ts, and -- critically --
--   monthly MQL/PQL/DTC/unknown mix. A Feb 2026 refactor cluster altered the
--   join key and grouping logic; this query quantifies whether it shifted
--   composition.
-- Output: one row per (month, lead_type) with counts.
-- -----------------------------------------------------------------------------
WITH leads AS (
    SELECT
          DATE_TRUNC('month', del.lead_start_ts)::DATE          AS lead_month
        , del.lead_type
        , COUNT(*)                                              AS leads
        , COUNT(DISTINCT del.hubspot_uid)                       AS distinct_contacts
    FROM soundstripe_prod.core.dim_enterprise_leads del
    WHERE del.lead_start_ts >= '2025-08-01'
      AND del.lead_start_ts <  '2026-05-01'
    GROUP BY 1, 2
)
SELECT
      leads.lead_month
    , leads.lead_type
    , leads.leads
    , leads.distinct_contacts
    , ROUND(leads.leads * 100.0 / SUM(leads.leads) OVER (PARTITION BY leads.lead_month), 2) AS pct_of_month
FROM leads
ORDER BY leads.lead_month, leads.lead_type
;


-- -----------------------------------------------------------------------------
-- B2 -- enterprise_lead_scoring_model (XGBoost raw output) shape
-- Purpose: confirm row count, created_ts range, lead_score percentiles.
--   Establishes the authoritative range of the raw XGBoost probability.
-- Column-case note: the Python model appends a pandas column named 'lead_score'
--   (lowercase) -- Snowpark writes it as "lead_score" with quotes. It must be
--   referenced as m."lead_score" in SQL, not m.lead_score.
-- -----------------------------------------------------------------------------
SELECT
      COUNT(*)                                                    AS total_rows
    , COUNT(DISTINCT m.hubspot_uid)                               AS distinct_hubspot_uid
    , MIN(m.created_ts)                                           AS earliest_score_ts
    , MAX(m.created_ts)                                           AS latest_score_ts
    , MIN(TRY_CAST(m."lead_score" AS FLOAT))                      AS min_score
    , MAX(TRY_CAST(m."lead_score" AS FLOAT))                      AS max_score
    , AVG(TRY_CAST(m."lead_score" AS FLOAT))                      AS mean_score
    , STDDEV(TRY_CAST(m."lead_score" AS FLOAT))                   AS stddev_score
    , APPROX_PERCENTILE(TRY_CAST(m."lead_score" AS FLOAT), 0.10)  AS p10
    , APPROX_PERCENTILE(TRY_CAST(m."lead_score" AS FLOAT), 0.25)  AS p25
    , APPROX_PERCENTILE(TRY_CAST(m."lead_score" AS FLOAT), 0.50)  AS p50
    , APPROX_PERCENTILE(TRY_CAST(m."lead_score" AS FLOAT), 0.75)  AS p75
    , APPROX_PERCENTILE(TRY_CAST(m."lead_score" AS FLOAT), 0.90)  AS p90
FROM soundstripe_prod.transformations.enterprise_lead_scoring_model m
;


-- -----------------------------------------------------------------------------
-- B3 -- polytomic_sync_hubspot_leads_with_scores shape + monthly sync volume
-- Purpose: monthly count of scored rows synced to HubSpot Jan - Apr 2026.
--   If Polytomic suddenly started writing MORE contacts (or SCORED MORE
--   contacts with high-score values) in Feb, that could explain Ryan's
--   observation without any model change.
-- -----------------------------------------------------------------------------
-- Column-case note: B4 works on hls.hubspot_uid but B5 failed on hls.lead_score.
-- The dbt incremental+sync_all_columns path preserved the upstream quoted-lowercase
-- identifiers from the Python model. Quoting all three below.
SELECT
      DATE_TRUNC('month', psh."lead_score_ts")::DATE             AS score_month
    , COUNT(*)                                                    AS synced_rows
    , COUNT(DISTINCT psh.hubspot_uid)                             AS distinct_hubspot_uid
    , AVG(TRY_CAST(psh."lead_score" AS FLOAT))                    AS mean_score
    , APPROX_PERCENTILE(TRY_CAST(psh."lead_score" AS FLOAT), 0.50) AS p50_score
    , COUNT_IF(psh."probability_category" = 'High Probability')    AS high_prob_count
    , COUNT_IF(psh."probability_category" = 'Medium Probability')  AS medium_prob_count
    , COUNT_IF(psh."probability_category" = 'Low Probability')     AS low_prob_count
FROM soundstripe_prod._external_polytomic.polytomic_sync_hubspot_leads_with_scores psh
WHERE psh."lead_score_ts" >= '2025-08-01'
  AND psh."lead_score_ts" <  '2026-05-01'
GROUP BY 1
ORDER BY 1
;


-- -----------------------------------------------------------------------------
-- B4 -- Warehouse-to-HubSpot sync completeness
-- Purpose: answer "is Polytomic actually writing all scored leads back to
--   HubSpot?" by comparing:
--     (a) count of scored rows in the warehouse (hubspot_leads_with_scores)
--     (b) count of HubSpot contacts with properties:snowflake__lead_score populated
--   The difference quantifies sync lag / sync gap.
-- RATE: sync_completeness
-- NUMERATOR: contacts with snowflake__lead_score populated in HubSpot
-- DENOMINATOR: distinct hubspot_uid in warehouse hubspot_leads_with_scores
-- TYPE: written-back / scored
-- NOT: count of syncs executed -- we want net state, not flux.
-- -----------------------------------------------------------------------------
WITH wh_scored AS (
    SELECT COUNT(DISTINCT hls.hubspot_uid) AS warehouse_scored_contacts
    FROM soundstripe_prod._external_polytomic.hubspot_leads_with_scores hls
)
, hs_scored AS (
    SELECT COUNT(*) AS hubspot_contacts_with_score
    FROM soundstripe_prod.hubspot.hubspot_contacts hc
    WHERE TRY_CAST(hc.properties:snowflake__lead_score::string AS FLOAT) IS NOT NULL
)
SELECT
      ws.warehouse_scored_contacts
    , hs.hubspot_contacts_with_score
    , ws.warehouse_scored_contacts - hs.hubspot_contacts_with_score AS unsynced_count
    , ROUND(hs.hubspot_contacts_with_score * 100.0 / NULLIF(ws.warehouse_scored_contacts, 0), 3) AS sync_pct
FROM wh_scored ws, hs_scored hs
;


-- -----------------------------------------------------------------------------
-- B5 -- Probability-bucket threshold validity
-- Purpose: validate the cast + bucketing in hubspot_leads_with_scores.sql:
--   >=0.8 High, >=0.6 Medium, <0.6 Low (post-2025-06-12 thresholds).
--   Confirm no score falls outside its declared bucket via raw-range check.
-- -----------------------------------------------------------------------------
SELECT
      hls."probability_category"                                AS probability_category
    , COUNT(*)                                                  AS row_count
    , MIN(TRY_CAST(hls."lead_score" AS FLOAT))                  AS min_score
    , MAX(TRY_CAST(hls."lead_score" AS FLOAT))                  AS max_score
    , AVG(TRY_CAST(hls."lead_score" AS FLOAT))                  AS mean_score
FROM soundstripe_prod._external_polytomic.hubspot_leads_with_scores hls
GROUP BY 1
ORDER BY min_score
;


-- -----------------------------------------------------------------------------
-- B6 -- Lead-type mix monthly trend (dim_enterprise_leads contact_state x type)
-- Purpose: the Feb 2026 dbt commit cluster modified dim_enterprise_leads join
--   key and grouping. Query cross-tabs lead_type x contact_state by month to
--   see whether the composition of the funnel changed materially Jan -> Feb.
-- -----------------------------------------------------------------------------
SELECT
      DATE_TRUNC('month', del.lead_start_ts)::DATE              AS lead_month
    , del.lead_type
    , del.contact_state
    , COUNT(*)                                                  AS leads
FROM soundstripe_prod.core.dim_enterprise_leads del
WHERE del.lead_start_ts >= '2025-08-01'
  AND del.lead_start_ts <  '2026-05-01'
GROUP BY 1, 2, 3
ORDER BY 1, 2, 3
;


-- -----------------------------------------------------------------------------
-- B7 -- enterprise_lead_scoring_model recency / retraining-evidence probe
-- Purpose: the Python model retrains every dbt run -- no persisted weights.
--   This query approximates retraining cadence via created_ts density.
--   Each distinct created_ts value is effectively a model-run batch.
-- Note: dbt Cloud run history is the authoritative source; this is a
--   SQL-accessible proxy only.
-- -----------------------------------------------------------------------------
SELECT
      DATE_TRUNC('day', m.created_ts)::DATE                       AS run_day
    , COUNT(*)                                                    AS scored_rows
    , COUNT(DISTINCT m.hubspot_uid)                               AS distinct_hubspot_uid
    , AVG(TRY_CAST(m."lead_score" AS FLOAT))                      AS mean_score_on_run_day
    , APPROX_PERCENTILE(TRY_CAST(m."lead_score" AS FLOAT), 0.50)  AS p50_score_on_run_day
FROM soundstripe_prod.transformations.enterprise_lead_scoring_model m
WHERE m.created_ts >= '2025-08-01'
  AND m.created_ts <  '2026-05-01'
GROUP BY 1
ORDER BY 1
;
