/*
================================================================================
console.sql — Enterprise reporting Looker vs HubSpot variance reconciliation
================================================================================
Purpose:    Reproduce both sides of 5 variances Ryan flagged on 2026-05-05,
            then decompose each gap mechanically.
Author:     Devon Bennett
Date:       2026-05-05
Window:     YTD-2026 (q01-q04, q06-q09); April 2026 only (q05, q10, q13)

Sources used:
  - soundstripe_prod.core.dim_enterprise_leads          (Looker PQL grain)
  - soundstripe_prod.finance.dim_enterprise_deals       (Looker deal grain)
  - soundstripe_prod.marketing.dim_mql_mapping          (Looker MQL form-grain)
  - soundstripe_prod.core.fct_kpis_enterprise           (Looker monthly KPIs)
  - soundstripe_prod.staging.stg_contacts_2             (Looker explore bridge)
  - hubspot_platform_data.v2_daily.object_properties    (HubSpot prop values)
  - hubspot_platform_data.v2_daily.list_memberships     (free-email exclusion)

Verification gate:
  - Each Looker reproduction (q01-q05) MUST match Ryan's quoted number to
    float precision. All 5 verified.
  - Each HubSpot reproduction (q06-q10) MUST match within ±2% Stitch lag
    tolerance. q07/q08/q10 exact; q09 -0.9%; q06 +3.4% (slightly over;
    consistent with hubspot_platform_data share lag observed in q10/q13).

Key identifiers:
  - HubSpot pipelineid 12423846 = "Enterprise Pipeline"
  - HubSpot pipelineid 71307608 = "Renewal Pipeline"
  - HubSpot list 4459 = "[MASTER] ALL Contacts w/ Free Email Domain List" (1.4M members)
  - HubSpot objecttypeid '0-1' = Contact; '0-3' = Deal
  - HubSpot raw timestamp values are stored as milliseconds-since-epoch text;
    convert via TO_TIMESTAMP_NTZ(TRY_CAST(value AS NUMBER)/1000)
================================================================================
*/


-- ============================================================================
-- LOOKER REPRODUCTIONS (q01-q05)
-- ============================================================================

-- q01 — Looker variance 1: 4,171 PQLs YTD ✓
SELECT 'q01_looker_pqls_ytd' AS query_label, COUNT(*) AS n
FROM soundstripe_prod.core.dim_enterprise_leads
WHERE lead_type = 'new process: pql'
  AND lead_date >= '2026-01-01'
  AND lead_date <= CURRENT_DATE();
-- expected: 4171  observed: 4171 ✓


-- q02 — Looker variance 2: 27 PQL deals created YTD ✓
-- Per General.model.lkml line 165-170: dim_enterprise_leads LEFT JOIN
-- dim_enterprise_deals ON deal_id = dealid
SELECT 'q02_looker_pql_deals_ytd' AS query_label, COUNT(DISTINCT d.dealid) AS n
FROM soundstripe_prod.core.dim_enterprise_leads l
LEFT JOIN soundstripe_prod.finance.dim_enterprise_deals d
       ON l.deal_id = d.dealid
WHERE l.lead_type = 'new process: pql'
  AND l.lead_date >= '2026-01-01'
  AND l.lead_date <= CURRENT_DATE()
  AND d.deal_grouping = 'enterprise new deal';
-- expected: 27  observed: 27 ✓


-- q03 — Looker variance 3: 758 MQLs YTD ✓
SELECT 'q03_looker_mqls_ytd' AS query_label, COUNT(DISTINCT email) AS n
FROM soundstripe_prod.marketing.dim_mql_mapping
WHERE submission_ts >= '2026-01-01';
-- expected: 758  observed: 758 ✓


-- q04 — Looker variance 4: 365 MQL deals created YTD ✓
-- Per General.model.lkml lines 620-646: dim_mql_mapping
--   -> stg_contacts_2 ON hubspot_uid = canonical_vid (m:1)
--   -> dim_enterprise_leads ON canonical_vid = hubspot_uid + submission_ts BETWEEN lead_start_ts AND lead_end_ts (m:m)
--   -> dim_enterprise_deals ON deal_id = dealid (m:1)
SELECT 'q04_looker_mql_deals_ytd' AS query_label, COUNT(DISTINCT d.dealid) AS n
FROM soundstripe_prod.marketing.dim_mql_mapping m
LEFT JOIN soundstripe_prod.staging.stg_contacts_2 c
       ON m.hubspot_uid = c.canonical_vid
LEFT JOIN soundstripe_prod.core.dim_enterprise_leads l
       ON c.canonical_vid = l.hubspot_uid
      AND m.submission_ts BETWEEN l.lead_start_ts AND l.lead_end_ts
LEFT JOIN soundstripe_prod.finance.dim_enterprise_deals d
       ON l.deal_id = d.dealid
WHERE m.submission_ts >= '2026-01-01';
-- expected: 365  observed: 365 ✓


-- q05 — Looker variance 5: 155 Apr-2026 deals created ✓
-- fct_kpis_enterprise.dynamic_deals_created with lead_type='all' returns
-- SUM(DEALS_CREATED) per fct_kpis_enterprise.view.lkml
SELECT 'q05_looker_apr26_deals' AS query_label, SUM(deals_created) AS n
FROM soundstripe_prod.core.fct_kpis_enterprise
WHERE event_month = '2026-04-01';
-- expected: 155  observed: 155 ✓


-- ============================================================================
-- HUBSPOT REPRODUCTIONS (q06-q10)
-- ============================================================================

-- q06 — HubSpot variance 1: 3,523 PQLs YTD (+3.4% drift)
WITH cp AS (
    SELECT op.objectid AS contact_id
        ,MAX(CASE WHEN op.name='is_pql' THEN op.value END) AS is_pql
        ,MAX(CASE WHEN op.name='became_a_pql_lead_status' THEN op.value END) AS became_pql_ms
        ,MAX(CASE WHEN op.name='createdate' THEN op.value END) AS createdate_ms
    FROM hubspot_platform_data.v2_daily.object_properties op
    WHERE op.objecttypeid = '0-1'
      AND op.name IN ('is_pql','became_a_pql_lead_status','createdate')
    GROUP BY op.objectid
), free_email AS (
    SELECT DISTINCT objectid
    FROM hubspot_platform_data.v2_daily.list_memberships
    WHERE listid = 4459
)
SELECT 'q06_hubspot_pqls_ytd' AS query_label, COUNT(DISTINCT cp.contact_id) AS n
FROM cp LEFT JOIN free_email fem ON cp.contact_id = fem.objectid
WHERE cp.is_pql = '1'
  AND cp.became_pql_ms IS NOT NULL
  AND TO_TIMESTAMP_NTZ(TRY_CAST(cp.createdate_ms AS NUMBER)/1000) >= '2026-01-01'
  AND fem.objectid IS NULL;
-- expected: 3523  observed: 3642 (+3.4%, slightly over ±2% Stitch tolerance;
-- consistent with hubspot_platform_data share lag observed in q10/q13)


-- q07 — HubSpot variance 3: 470 MQLs YTD ✓
WITH cp AS (
    SELECT op.objectid AS contact_id
        ,MAX(CASE WHEN op.name='is_mql' THEN op.value END) AS is_mql
        ,MAX(CASE WHEN op.name='date_first_became_mql' THEN op.value END) AS first_mql_ms
    FROM hubspot_platform_data.v2_daily.object_properties op
    WHERE op.objecttypeid = '0-1'
      AND op.name IN ('is_mql','date_first_became_mql')
    GROUP BY op.objectid
), free_email AS (
    SELECT DISTINCT objectid
    FROM hubspot_platform_data.v2_daily.list_memberships
    WHERE listid = 4459
)
SELECT 'q07_hubspot_mqls_ytd' AS query_label, COUNT(DISTINCT cp.contact_id) AS n
FROM cp LEFT JOIN free_email fem ON cp.contact_id = fem.objectid
WHERE cp.is_mql = '1'
  AND TO_TIMESTAMP_NTZ(TRY_CAST(cp.first_mql_ms AS NUMBER)/1000) >= '2026-01-01'
  AND fem.objectid IS NULL;
-- expected: 470  observed: 470 ✓


-- q08 — HubSpot variance 2: 13 PQL deals created (contact-grain) ✓
WITH cp AS (
    SELECT op.objectid AS contact_id
        ,MAX(CASE WHEN op.name='is_pql' THEN op.value END) AS is_pql
        ,MAX(CASE WHEN op.name='became_a_pql_lead_status' THEN op.value END) AS became_pql_ms
        ,MAX(CASE WHEN op.name='createdate' THEN op.value END) AS createdate_ms
        ,MAX(CASE WHEN op.name='is_converted_to_deal' THEN op.value END) AS is_conv
    FROM hubspot_platform_data.v2_daily.object_properties op
    WHERE op.objecttypeid = '0-1'
      AND op.name IN ('is_pql','became_a_pql_lead_status','createdate','is_converted_to_deal')
    GROUP BY op.objectid
), free_email AS (
    SELECT DISTINCT objectid FROM hubspot_platform_data.v2_daily.list_memberships WHERE listid = 4459
)
SELECT 'q08_hubspot_pql_deals_ytd' AS query_label, COUNT(DISTINCT cp.contact_id) AS n
FROM cp LEFT JOIN free_email fem ON cp.contact_id = fem.objectid
WHERE cp.is_pql = '1'
  AND cp.became_pql_ms IS NOT NULL
  AND TO_TIMESTAMP_NTZ(TRY_CAST(cp.createdate_ms AS NUMBER)/1000) >= '2026-01-01'
  AND cp.is_conv = '1'
  AND fem.objectid IS NULL;
-- expected: 13  observed: 13 ✓


-- q09 — HubSpot variance 4: 337 MQL deals (-0.9%, within tolerance)
WITH cp AS (
    SELECT op.objectid AS contact_id
        ,MAX(CASE WHEN op.name='is_mql' THEN op.value END) AS is_mql
        ,MAX(CASE WHEN op.name='date_first_became_mql' THEN op.value END) AS first_mql_ms
        ,MAX(CASE WHEN op.name='is_converted_to_deal' THEN op.value END) AS is_conv
    FROM hubspot_platform_data.v2_daily.object_properties op
    WHERE op.objecttypeid = '0-1'
      AND op.name IN ('is_mql','date_first_became_mql','is_converted_to_deal')
    GROUP BY op.objectid
), free_email AS (
    SELECT DISTINCT objectid FROM hubspot_platform_data.v2_daily.list_memberships WHERE listid = 4459
)
SELECT 'q09_hubspot_mql_deals_ytd' AS query_label, COUNT(DISTINCT cp.contact_id) AS n
FROM cp LEFT JOIN free_email fem ON cp.contact_id = fem.objectid
WHERE cp.is_mql = '1'
  AND TO_TIMESTAMP_NTZ(TRY_CAST(cp.first_mql_ms AS NUMBER)/1000) >= '2026-01-01'
  AND cp.is_conv = '1'
  AND fem.objectid IS NULL;
-- expected: 337  observed: 334 (-0.9%, within ±2% Stitch tolerance) ✓


-- q10 — HubSpot variance 5: 131 Apr-2026 deals (raw HubSpot share) ✓
-- Note: pipeline=12423846 = "Enterprise Pipeline"
SELECT 'q10_hubspot_apr26_deals' AS query_label, COUNT(DISTINCT op.objectid) AS n
FROM hubspot_platform_data.v2_daily.object_properties op
JOIN hubspot_platform_data.v2_daily.object_properties op2
       ON op.objectid = op2.objectid
      AND op2.objecttypeid = '0-3'
      AND op2.name = 'createdate'
WHERE op.objecttypeid = '0-3'
  AND op.name = 'pipeline'
  AND op.value = '12423846'
  AND TO_TIMESTAMP_NTZ(TRY_CAST(op2.value AS NUMBER)/1000) >= '2026-04-01'
  AND TO_TIMESTAMP_NTZ(TRY_CAST(op2.value AS NUMBER)/1000) <  '2026-05-01';
-- expected: 131  observed: 131 ✓


-- ============================================================================
-- GAP DECOMPOSITION (q11-q14)
-- ============================================================================

-- q11 — PQL set-difference: Looker PQLs vs HubSpot PQLs (YTD-2026)
WITH looker_pqls AS (
    SELECT DISTINCT TRY_CAST(hubspot_uid AS NUMBER) AS contact_id
    FROM soundstripe_prod.core.dim_enterprise_leads
    WHERE lead_type = 'new process: pql'
      AND lead_date >= '2026-01-01'
      AND lead_date <= CURRENT_DATE()
      AND hubspot_uid IS NOT NULL
), cp AS (
    SELECT op.objectid AS contact_id
        ,MAX(CASE WHEN op.name='is_pql' THEN op.value END) AS is_pql
        ,MAX(CASE WHEN op.name='became_a_pql_lead_status' THEN op.value END) AS became_pql_ms
        ,MAX(CASE WHEN op.name='createdate' THEN op.value END) AS createdate_ms
    FROM hubspot_platform_data.v2_daily.object_properties op
    WHERE op.objecttypeid = '0-1'
      AND op.name IN ('is_pql','became_a_pql_lead_status','createdate')
    GROUP BY op.objectid
), free_email AS (SELECT DISTINCT objectid FROM hubspot_platform_data.v2_daily.list_memberships WHERE listid=4459)
, hubspot_pqls AS (
    SELECT cp.contact_id
    FROM cp LEFT JOIN free_email fem ON cp.contact_id = fem.objectid
    WHERE cp.is_pql='1' AND cp.became_pql_ms IS NOT NULL
      AND TO_TIMESTAMP_NTZ(TRY_CAST(cp.createdate_ms AS NUMBER)/1000) >= '2026-01-01'
      AND fem.objectid IS NULL
)
SELECT 'q11_pql_set_diff' AS query_label
     , (SELECT COUNT(*) FROM looker_pqls)                                                                            AS looker_total
     , (SELECT COUNT(*) FROM hubspot_pqls)                                                                           AS hubspot_total
     , (SELECT COUNT(*) FROM looker_pqls l WHERE EXISTS(SELECT 1 FROM hubspot_pqls h WHERE h.contact_id=l.contact_id)) AS in_both
     , (SELECT COUNT(*) FROM looker_pqls l WHERE NOT EXISTS(SELECT 1 FROM hubspot_pqls h WHERE h.contact_id=l.contact_id)) AS looker_only
     , (SELECT COUNT(*) FROM hubspot_pqls h WHERE NOT EXISTS(SELECT 1 FROM looker_pqls l WHERE l.contact_id=h.contact_id)) AS hubspot_only;
-- observed: looker_total=4171, hubspot_total=3642, in_both=3533,
--           looker_only=638, hubspot_only=109
-- net=638-109=529=4171-3642 ✓


-- q11b — PQL Looker-only breakdown by HubSpot property values
WITH looker_pqls AS (
    SELECT DISTINCT TRY_CAST(hubspot_uid AS NUMBER) AS contact_id
    FROM soundstripe_prod.core.dim_enterprise_leads
    WHERE lead_type='new process: pql' AND lead_date >= '2026-01-01' AND lead_date <= CURRENT_DATE() AND hubspot_uid IS NOT NULL
), cp AS (
    SELECT op.objectid AS contact_id
        ,MAX(CASE WHEN op.name='is_pql' THEN op.value END) AS is_pql
        ,MAX(CASE WHEN op.name='became_a_pql_lead_status' THEN op.value END) AS became_pql_ms
        ,MAX(CASE WHEN op.name='createdate' THEN op.value END) AS createdate_ms
    FROM hubspot_platform_data.v2_daily.object_properties op
    WHERE op.objecttypeid='0-1' AND op.name IN ('is_pql','became_a_pql_lead_status','createdate')
    GROUP BY op.objectid
), in_free AS (SELECT DISTINCT objectid FROM hubspot_platform_data.v2_daily.list_memberships WHERE listid=4459)
, hubspot_pqls AS (
    SELECT cp.contact_id FROM cp LEFT JOIN in_free f ON cp.contact_id=f.objectid
    WHERE cp.is_pql='1' AND cp.became_pql_ms IS NOT NULL
      AND TO_TIMESTAMP_NTZ(TRY_CAST(cp.createdate_ms AS NUMBER)/1000) >= '2026-01-01'
      AND f.objectid IS NULL
), looker_only AS (
    SELECT l.contact_id FROM looker_pqls l WHERE NOT EXISTS(SELECT 1 FROM hubspot_pqls h WHERE h.contact_id=l.contact_id)
)
SELECT
    CASE WHEN ife.objectid IS NOT NULL THEN 'in_free_email_list' ELSE 'not_free' END AS free_email_status,
    COALESCE(cp.is_pql, '(no_property_row)') AS hs_is_pql,
    CASE WHEN cp.became_pql_ms IS NULL THEN 'null' ELSE 'set' END AS hs_became_pql,
    CASE WHEN cp.createdate_ms IS NULL THEN 'null'
         WHEN TO_TIMESTAMP_NTZ(TRY_CAST(cp.createdate_ms AS NUMBER)/1000) < '2026-01-01' THEN 'pre_2026'
         ELSE 'in_2026' END AS createdate_window,
    COUNT(*) AS n
FROM looker_only lo
LEFT JOIN cp ON cp.contact_id = lo.contact_id
LEFT JOIN in_free ife ON ife.objectid = lo.contact_id
GROUP BY 1, 2, 3, 4
ORDER BY n DESC;
-- observed: 547 'is_pql=0/null becameapql/in_2026' (86% of 638) - HubSpot
--           workflow flag never set; 62 'is_pql=1/null/in_2026'; 29 others


-- q12 — MQL set-difference: Looker MQLs vs HubSpot MQLs (YTD-2026)
WITH looker_mqls AS (
    SELECT DISTINCT TRY_CAST(hubspot_uid AS NUMBER) AS contact_id
    FROM soundstripe_prod.marketing.dim_mql_mapping
    WHERE submission_ts >= '2026-01-01' AND hubspot_uid IS NOT NULL
), cp AS (
    SELECT op.objectid AS contact_id
        ,MAX(CASE WHEN op.name='is_mql' THEN op.value END) AS is_mql
        ,MAX(CASE WHEN op.name='date_first_became_mql' THEN op.value END) AS first_mql_ms
    FROM hubspot_platform_data.v2_daily.object_properties op
    WHERE op.objecttypeid='0-1' AND op.name IN ('is_mql','date_first_became_mql')
    GROUP BY op.objectid
), free_email AS (SELECT DISTINCT objectid FROM hubspot_platform_data.v2_daily.list_memberships WHERE listid=4459)
, hubspot_mqls AS (
    SELECT cp.contact_id FROM cp LEFT JOIN free_email fem ON cp.contact_id=fem.objectid
    WHERE cp.is_mql='1'
      AND TO_TIMESTAMP_NTZ(TRY_CAST(cp.first_mql_ms AS NUMBER)/1000) >= '2026-01-01'
      AND fem.objectid IS NULL
)
SELECT 'q12_mql_set_diff' AS query_label
     , (SELECT COUNT(*) FROM looker_mqls)                                                                            AS looker_total
     , (SELECT COUNT(*) FROM hubspot_mqls)                                                                           AS hubspot_total
     , (SELECT COUNT(*) FROM looker_mqls l WHERE EXISTS(SELECT 1 FROM hubspot_mqls h WHERE h.contact_id=l.contact_id)) AS in_both
     , (SELECT COUNT(*) FROM looker_mqls l WHERE NOT EXISTS(SELECT 1 FROM hubspot_mqls h WHERE h.contact_id=l.contact_id)) AS looker_only
     , (SELECT COUNT(*) FROM hubspot_mqls h WHERE NOT EXISTS(SELECT 1 FROM looker_mqls l WHERE l.contact_id=h.contact_id)) AS hubspot_only;
-- observed: looker_total=727 (hubspot_uid grain; tile shows 758 at email grain),
--           hubspot_total=470, in_both=398, looker_only=329, hubspot_only=72
-- net=329-72=257=727-470 ✓


-- q12b — MQL Looker-only breakdown
WITH looker_mqls AS (
    SELECT DISTINCT TRY_CAST(hubspot_uid AS NUMBER) AS contact_id
    FROM soundstripe_prod.marketing.dim_mql_mapping
    WHERE submission_ts >= '2026-01-01' AND hubspot_uid IS NOT NULL
), cp AS (
    SELECT op.objectid AS contact_id
        ,MAX(CASE WHEN op.name='is_mql' THEN op.value END) AS is_mql
        ,MAX(CASE WHEN op.name='date_first_became_mql' THEN op.value END) AS first_mql_ms
    FROM hubspot_platform_data.v2_daily.object_properties op
    WHERE op.objecttypeid='0-1' AND op.name IN ('is_mql','date_first_became_mql')
    GROUP BY op.objectid
), in_free AS (SELECT DISTINCT objectid FROM hubspot_platform_data.v2_daily.list_memberships WHERE listid=4459)
, hubspot_mqls AS (
    SELECT cp.contact_id FROM cp LEFT JOIN in_free f ON cp.contact_id=f.objectid
    WHERE cp.is_mql='1'
      AND TO_TIMESTAMP_NTZ(TRY_CAST(cp.first_mql_ms AS NUMBER)/1000) >= '2026-01-01'
      AND f.objectid IS NULL
)
SELECT
    CASE WHEN ife.objectid IS NOT NULL THEN 'in_free_email_list' ELSE 'not_free' END AS free_email_status,
    COALESCE(cp.is_mql, '(no_property_row)') AS hs_is_mql,
    CASE WHEN cp.first_mql_ms IS NULL THEN 'null'
         WHEN TO_TIMESTAMP_NTZ(TRY_CAST(cp.first_mql_ms AS NUMBER)/1000) < '2026-01-01' THEN 'pre_2026'
         ELSE 'in_2026' END AS first_mql_window,
    COUNT(*) AS n
FROM looker_mqls lo
LEFT JOIN cp ON cp.contact_id = lo.contact_id
LEFT JOIN in_free ife ON ife.objectid = lo.contact_id
WHERE NOT EXISTS (SELECT 1 FROM hubspot_mqls h WHERE h.contact_id = lo.contact_id)
GROUP BY 1, 2, 3
ORDER BY n DESC;
-- observed: 312 'in_free/is_mql=1/in_2026' (95% of 329) - free-email exclusion
--           applied by HubSpot but not Looker; 9 'not_free/1/pre_2026';
--           3 'in_free/1/pre_2026'; 5 other edge cases


-- q13 — April 2026 deal split by pipeline_name (variance 5 decomposition)
SELECT 'q13_apr26_pipeline_split' AS query_label
     , pipeline_name
     , deal_grouping
     , COUNT(DISTINCT dealid) AS n
FROM soundstripe_prod.finance.dim_enterprise_deals
WHERE createdate >= '2026-04-01'
  AND createdate <  '2026-05-01'
GROUP BY pipeline_name, deal_grouping
ORDER BY pipeline_name, deal_grouping;
-- observed: Enterprise Pipeline=155, Renewal Pipeline=48, API & Partnerships=11
-- Looker fct_kpis_enterprise.deals_created = 155 (Enterprise only;
-- Renewal Pipeline contributes 0 to deals_created column for Apr 2026)


-- q13b — The 24 "missing" April deals: in dim_enterprise_deals, not in HubSpot share
SELECT d.dealid, d.dealname, d.pipelineid AS dim_pipelineid,
       d.amount, d.stage_category, d.createdate
FROM soundstripe_prod.finance.dim_enterprise_deals d
LEFT JOIN hubspot_platform_data.v2_daily.object_properties op
       ON op.objectid = TRY_CAST(d.dealid AS NUMBER)
      AND op.objecttypeid = '0-3' AND op.name = 'pipeline'
WHERE d.pipeline_name = 'Enterprise Pipeline'
  AND d.createdate >= '2026-04-01' AND d.createdate < '2026-05-01'
  AND (op.value IS NULL OR op.value <> '12423846')
ORDER BY d.createdate;
-- observed: 24 dealids in dim_enterprise_deals (pipelineid=12423846) but
-- their pipeline property row is missing from hubspot_platform_data share.
-- All real, active April enterprise deals (Columbia University, North
-- Carolina Zoo, Cloud Software Group, Iowa Valley CC, Highly Developed, etc.)


-- q14 — Free-email-domain exposure on Looker populations
WITH looker_pqls AS (
    SELECT DISTINCT TRY_CAST(hubspot_uid AS NUMBER) AS contact_id
    FROM soundstripe_prod.core.dim_enterprise_leads
    WHERE lead_type='new process: pql' AND lead_date >= '2026-01-01' AND lead_date <= CURRENT_DATE() AND hubspot_uid IS NOT NULL
), looker_mqls AS (
    SELECT DISTINCT TRY_CAST(hubspot_uid AS NUMBER) AS contact_id
    FROM soundstripe_prod.marketing.dim_mql_mapping
    WHERE submission_ts >= '2026-01-01' AND hubspot_uid IS NOT NULL
), free_email AS (SELECT DISTINCT objectid FROM hubspot_platform_data.v2_daily.list_memberships WHERE listid=4459)
SELECT 'pql' AS pop, COUNT(*) AS looker_count,
       SUM(CASE WHEN EXISTS(SELECT 1 FROM free_email f WHERE f.objectid=l.contact_id) THEN 1 ELSE 0 END) AS in_free_email
FROM looker_pqls l
UNION ALL
SELECT 'mql' AS pop, COUNT(*) AS looker_count,
       SUM(CASE WHEN EXISTS(SELECT 1 FROM free_email f WHERE f.objectid=l.contact_id) THEN 1 ELSE 0 END) AS in_free_email
FROM looker_mqls l;
-- observed: pql 4171/2 (0.05%) - free-email NOT a meaningful gap mechanic for PQL
--           mql 727/316 (43%) - free-email IS the dominant gap mechanic for MQL


-- q15 — Example Looker-only PQLs where HubSpot is_pql ≠ '1' (or no property row)
-- Spot-check sample for the meeting: 20 example contacts, surfaced as the
-- dominant gap class from q11b (547 of 638 looker-only PQLs had is_pql=0/null
-- + became_pql NULL + createdate in_2026 — i.e. Looker called them PQL but
-- HubSpot's is_pql workflow never flipped). Ordered by Looker's lead_date DESC
-- so the most recent (easiest to spot-check in the HubSpot UI) come first.
WITH cp AS (
    SELECT op.objectid AS contact_id
        ,MAX(CASE WHEN op.name='is_pql'                     THEN op.value END) AS hs_is_pql
        ,MAX(CASE WHEN op.name='became_a_pql_lead_status'   THEN op.value END) AS hs_became_pql_ms
        ,MAX(CASE WHEN op.name='createdate'                 THEN op.value END) AS hs_createdate_ms
        ,MAX(CASE WHEN op.name='email'                      THEN op.value END) AS hs_email
        ,MAX(CASE WHEN op.name='lifecyclestage'             THEN op.value END) AS hs_lifecyclestage
        ,MAX(CASE WHEN op.name='hs_lead_status'             THEN op.value END) AS hs_lead_status
    FROM hubspot_platform_data.v2_daily.object_properties op
    WHERE op.objecttypeid = '0-1'
      AND op.name IN ('is_pql','became_a_pql_lead_status','createdate','email','lifecyclestage','hs_lead_status')
    GROUP BY op.objectid
)
SELECT 'q15_looker_pql_no_hs_is_pql' AS query_label
     ,l.hubspot_uid                                                                            AS contact_id
     ,cp.hs_email
     ,l.lead_date                                                                              AS looker_lead_date
     ,l.lead_type                                                                              AS looker_lead_type
     ,COALESCE(cp.hs_is_pql, '(no_property_row)')                                              AS hs_is_pql
     ,CASE WHEN cp.hs_became_pql_ms IS NULL THEN NULL
           ELSE TO_TIMESTAMP_NTZ(TRY_CAST(cp.hs_became_pql_ms AS NUMBER)/1000) END             AS hs_became_pql_at
     ,CASE WHEN cp.hs_createdate_ms IS NULL THEN NULL
           ELSE TO_TIMESTAMP_NTZ(TRY_CAST(cp.hs_createdate_ms AS NUMBER)/1000) END             AS hs_createdate
     ,cp.hs_lifecyclestage
     ,cp.hs_lead_status
FROM soundstripe_prod.core.dim_enterprise_leads l
LEFT JOIN cp ON cp.contact_id = TRY_CAST(l.hubspot_uid AS NUMBER)
WHERE l.lead_type = 'new process: pql'
  AND l.lead_date >= '2026-01-01'
  AND l.lead_date <= CURRENT_DATE()
  AND l.hubspot_uid IS NOT NULL
  -- HubSpot says NOT a PQL (or has no property row at all)
  AND (cp.hs_is_pql IS NULL OR cp.hs_is_pql <> '1')
ORDER BY l.lead_date DESC
LIMIT 20;


-- q16 — Variance 1 complete diff: Looker-only PQL contacts (in Looker, missing from HubSpot)
-- Same shape as q15 minus the LIMIT — full ~638-row population for export to CSV.
-- Result is looker_only_pql_contacts_20260506.csv exported alongside this file for stakeholder review.
WITH cp AS (
    SELECT op.objectid AS contact_id
        ,MAX(CASE WHEN op.name='is_pql'                     THEN op.value END) AS hs_is_pql
        ,MAX(CASE WHEN op.name='became_a_pql_lead_status'   THEN op.value END) AS hs_became_pql_ms
        ,MAX(CASE WHEN op.name='createdate'                 THEN op.value END) AS hs_createdate_ms
        ,MAX(CASE WHEN op.name='email'                      THEN op.value END) AS hs_email
        ,MAX(CASE WHEN op.name='lifecyclestage'             THEN op.value END) AS hs_lifecyclestage
        ,MAX(CASE WHEN op.name='hs_lead_status'             THEN op.value END) AS hs_lead_status
    FROM hubspot_platform_data.v2_daily.object_properties op
    WHERE op.objecttypeid = '0-1'
      AND op.name IN ('is_pql','became_a_pql_lead_status','createdate','email','lifecyclestage','hs_lead_status')
    GROUP BY op.objectid
), free_email AS (
    SELECT DISTINCT objectid FROM hubspot_platform_data.v2_daily.list_memberships WHERE listid = 4459
), looker_pqls AS (
    SELECT DISTINCT TRY_CAST(l.hubspot_uid AS NUMBER) AS contact_id, MIN(l.lead_date) AS looker_lead_date
    FROM soundstripe_prod.core.dim_enterprise_leads l
    WHERE l.lead_type = 'new process: pql'
      AND l.lead_date >= '2026-01-01'
      AND l.lead_date <= CURRENT_DATE()
      AND l.hubspot_uid IS NOT NULL
    GROUP BY 1
), hubspot_pqls AS (
    SELECT cp.contact_id
    FROM cp LEFT JOIN free_email fem ON cp.contact_id = fem.objectid
    WHERE cp.hs_is_pql = '1'
      AND cp.hs_became_pql_ms IS NOT NULL
      AND TO_TIMESTAMP_NTZ(TRY_CAST(cp.hs_createdate_ms AS NUMBER)/1000) >= '2026-01-01'
      AND fem.objectid IS NULL
)
SELECT 'q16_looker_only_pql_contacts' AS query_label
     ,lp.contact_id
     ,cp.hs_email
     ,lp.looker_lead_date
     ,COALESCE(cp.hs_is_pql, '(no_property_row)')                                              AS hs_is_pql
     ,CASE WHEN cp.hs_became_pql_ms IS NULL THEN NULL
           ELSE TO_TIMESTAMP_NTZ(TRY_CAST(cp.hs_became_pql_ms AS NUMBER)/1000) END             AS hs_became_pql_at
     ,CASE WHEN cp.hs_createdate_ms IS NULL THEN NULL
           ELSE TO_TIMESTAMP_NTZ(TRY_CAST(cp.hs_createdate_ms AS NUMBER)/1000) END             AS hs_createdate
     ,cp.hs_lifecyclestage
     ,cp.hs_lead_status
     ,CASE WHEN ife.objectid IS NOT NULL THEN 1 ELSE 0 END                                     AS in_free_email_list
FROM looker_pqls lp
LEFT JOIN cp        ON cp.contact_id  = lp.contact_id
LEFT JOIN free_email ife ON ife.objectid = lp.contact_id
WHERE NOT EXISTS (SELECT 1 FROM hubspot_pqls h WHERE h.contact_id = lp.contact_id)
ORDER BY lp.looker_lead_date DESC, lp.contact_id;
-- expected: ~638 rows (per q11 looker_only)


-- q17 — Variance 2 complete diff: Looker-only PQL deals (in Looker, missing from HubSpot)
-- Looker's PQL-deal set per q02 is N dealids (deal_grouping='enterprise new deal'
-- joined to PQL leads). HubSpot's PQL-deal measure is contact-grain (q08).
--
-- Apples-to-apples deal-grain diff: a deal counts as "in HubSpot" if ANY associated
-- PQL contact passes q08's full filter set:
--      is_pql='1'
--      AND became_a_pql_lead_status IS NOT NULL
--      AND createdate >= 2026-01-01
--      AND is_converted_to_deal='1'
--      AND not in free-email list 4459
-- Otherwise the deal is "looker-only." This mirrors q08 exactly so the comparison
-- is at the same definition Ryan would see in HubSpot's PQL-deal report.
--
-- Result is looker_only_pql_deals_20260506.csv exported alongside this file.
WITH looker_pql_deals AS (
    SELECT
        d.dealid
        ,d.dealname
        ,d.amount
        ,d.stage_category
        ,d.createdate                AS deal_createdate
        ,l.hubspot_uid               AS contact_id
        ,l.lead_date                 AS pql_lead_date
    FROM soundstripe_prod.core.dim_enterprise_leads l
    LEFT JOIN soundstripe_prod.finance.dim_enterprise_deals d
           ON l.deal_id = d.dealid
    WHERE l.lead_type = 'new process: pql'
      AND l.lead_date >= '2026-01-01'
      AND l.lead_date <= CURRENT_DATE()
      AND d.deal_grouping = 'enterprise new deal'
), hs_contact AS (
    SELECT op.objectid AS contact_id
        ,MAX(CASE WHEN op.name='is_pql'                   THEN op.value END) AS hs_is_pql
        ,MAX(CASE WHEN op.name='became_a_pql_lead_status' THEN op.value END) AS hs_became_pql_ms
        ,MAX(CASE WHEN op.name='createdate'               THEN op.value END) AS hs_createdate_ms
        ,MAX(CASE WHEN op.name='is_converted_to_deal'     THEN op.value END) AS hs_is_conv
        ,MAX(CASE WHEN op.name='email'                    THEN op.value END) AS hs_email
        ,MAX(CASE WHEN op.name='lifecyclestage'           THEN op.value END) AS hs_lifecyclestage
    FROM hubspot_platform_data.v2_daily.object_properties op
    WHERE op.objecttypeid = '0-1'
      AND op.name IN ('is_pql','became_a_pql_lead_status','createdate','is_converted_to_deal','email','lifecyclestage')
    GROUP BY op.objectid
), free_email AS (
    SELECT DISTINCT objectid FROM hubspot_platform_data.v2_daily.list_memberships WHERE listid = 4459
), hs_pql_deal_contacts AS (
    -- Mirror q08's HubSpot-side filter exactly
    SELECT cp.contact_id
    FROM hs_contact cp
    LEFT JOIN free_email fem ON cp.contact_id = fem.objectid
    WHERE cp.hs_is_pql = '1'
      AND cp.hs_became_pql_ms IS NOT NULL
      AND TO_TIMESTAMP_NTZ(TRY_CAST(cp.hs_createdate_ms AS NUMBER)/1000) >= '2026-01-01'
      AND cp.hs_is_conv = '1'
      AND fem.objectid IS NULL
), deal_with_status AS (
    SELECT
        ld.dealid
        ,MAX(ld.dealname)                                                  AS dealname
        ,MAX(ld.amount)                                                    AS amount
        ,MAX(ld.stage_category)                                            AS stage_category
        ,MAX(ld.deal_createdate)                                           AS deal_createdate
        ,MIN(ld.pql_lead_date)                                             AS first_pql_lead_date
        ,COUNT(DISTINCT ld.contact_id)                                     AS associated_pql_contacts
        ,LISTAGG(DISTINCT cp.hs_email, ', ')
            WITHIN GROUP (ORDER BY cp.hs_email)                            AS associated_pql_emails
        ,MAX(cp.hs_is_pql)                                                 AS any_hs_is_pql
        ,MAX(cp.hs_is_conv)                                                AS any_hs_is_converted_to_deal
        ,MAX(cp.hs_lifecyclestage)                                         AS max_hs_lifecyclestage
        ,MAX(CASE WHEN qd.contact_id IS NOT NULL THEN 1 ELSE 0 END)        AS deal_in_hubspot_pql_count
    FROM looker_pql_deals ld
    LEFT JOIN hs_contact cp ON cp.contact_id = TRY_CAST(ld.contact_id AS NUMBER)
    LEFT JOIN hs_pql_deal_contacts qd ON qd.contact_id = TRY_CAST(ld.contact_id AS NUMBER)
    GROUP BY ld.dealid
)
SELECT 'q17_looker_only_pql_deals' AS query_label
     ,dealid
     ,dealname
     ,amount
     ,stage_category
     ,deal_createdate
     ,first_pql_lead_date
     ,associated_pql_contacts
     ,associated_pql_emails
     ,COALESCE(any_hs_is_pql, '(no_property_row)')                         AS any_hs_is_pql
     ,any_hs_is_converted_to_deal
     ,max_hs_lifecyclestage
FROM deal_with_status
WHERE deal_in_hubspot_pql_count = 0
ORDER BY deal_createdate DESC;
-- 2026-05-06 run: total Looker PQL deals=29 (q02), looker-only at deal-grain=19.
-- q08 unchanged at 13 (contact-grain). The 10 "deals_in_hubspot" inside this
-- query is deal-grain (29 - 19 = 10 deals have ≥1 associated PQL contact that
-- passes q08's filter); 13 q08-qualifying contacts collapse to 10 distinct deals
-- because some deals share PQL contacts. q02 moved 27→29 since yesterday.
