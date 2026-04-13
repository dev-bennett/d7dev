-- Q2: Aligned MQL comparison — all columns use the same population definition
-- Fixes Q1 denominator mismatches:
--   1. HubSpot CTE now matches dim_mql_mapping scope (all 6 enterprise form names, no became_mql filter)
--   2. Bridge CTE counts distinct emails (not distinct_ids) for apples-to-apples comparison
--   3. Added became_mql breakout so you can see the MQL-qualified subset separately

WITH hubspot_all_forms AS (
    SELECT
        DATE_TRUNC('week', a.SUBMISSION_TS) AS wk
        ,COUNT(DISTINCT a.email) AS hs_all_forms
        ,COUNT(DISTINCT CASE WHEN b.became_mql IS NOT NULL THEN a.email END) AS hs_became_mql
        ,COUNT(DISTINCT CASE WHEN a.FORM_NAME = 'Enterprise v2 - Updated' THEN a.email END) AS hs_v2_only
    FROM soundstripe_prod.hubspot.hubspot_forms a
        LEFT JOIN soundstripe_prod.staging.stg_contacts_2 b
            ON a.email = b.email
    WHERE a.FORM_NAME IN (
            'Enterprise (API Page)', 'Enterprise Multi-step Form', 'Enterprise Request Form'
            ,'Enterprise Request Form (Hubspot)', 'Enterprise v2 - Updated'
            ,'Meetings Link: ned-pruitt/enterprise-calendar-schedule-form'
        )
        AND a.SUBMISSION_TS >= '2026-02-23'
        AND a.SUBMISSION_TS < DATE_TRUNC('week', CURRENT_DATE())
    GROUP BY 1
),

mapping AS (
    SELECT
        DATE_TRUNC('week', m.SUBMISSION_TS) AS wk
        ,COUNT(DISTINCT m.email) AS mapping_total
        ,COUNT(DISTINCT CASE WHEN m.match_tier != 'unmatched' THEN m.email END) AS mapping_matched
    FROM soundstripe_prod.MARKETING.dim_mql_mapping m
    WHERE m.SUBMISSION_TS >= '2026-02-23'
        AND m.SUBMISSION_TS < DATE_TRUNC('week', CURRENT_DATE())
    GROUP BY 1
),

bridge AS (
    SELECT
        DATE_TRUNC('week', s.session_started_at) AS wk
        -- Count distinct emails via mapping, not distinct_ids
        ,COUNT(DISTINCT m.email) AS bridged_emails
        ,COUNT(DISTINCT s.distinct_id) AS bridged_distinct_ids
    FROM soundstripe_prod.MARKETING.dim_session_mqls b
        INNER JOIN soundstripe_prod.CORE.fct_sessions s
            ON b.session_id = s.session_id
        INNER JOIN soundstripe_prod.MARKETING.dim_mql_mapping m
            ON b.session_id = m.mixpanel_session_id
    WHERE s.session_started_at >= '2026-02-23'
        AND s.session_started_at < DATE_TRUNC('week', CURRENT_DATE())
    GROUP BY 1
)

SELECT
    COALESCE(h.wk, m.wk, br.wk) AS week
    ,h.hs_all_forms
    ,h.hs_became_mql
    ,h.hs_v2_only
    ,m.mapping_total
    ,m.mapping_matched
    ,br.bridged_emails
    ,br.bridged_distinct_ids
FROM hubspot_all_forms h
    FULL OUTER JOIN mapping m ON h.wk = m.wk
    FULL OUTER JOIN bridge br ON h.wk = br.wk
ORDER BY 1;
