-- Q4: Tier 3 exposure analysis — what do we miss by excluding tier 3 from reporting?
-- Shows weekly HubSpot MQL count vs matched MQLs with and without tier 3,
-- plus the count of submissions where tier 3 is the ONLY match (true exposure).

WITH mapping_by_tier AS (
    SELECT
        DATE_TRUNC('week', m.SUBMISSION_TS) AS wk
        ,m.email
        ,m.FORM_OBJECT_ID
        ,m.match_tier
        ,m.mixpanel_session_id
    FROM soundstripe_prod.MARKETING.dim_mql_mapping m
    WHERE m.SUBMISSION_TS >= '2026-02-23'
        AND m.SUBMISSION_TS < DATE_TRUNC('week', CURRENT_DATE())
),

-- Emails that have ANY non-tier3 match (tier1 or tier2)
emails_with_good_match AS (
    SELECT DISTINCT email
    FROM mapping_by_tier
    WHERE match_tier IN ('tier1_form', 'tier2_page')
),

weekly AS (
    SELECT
        m.wk
        ,COUNT(DISTINCT m.email) AS total_emails
        ,COUNT(DISTINCT CASE WHEN m.match_tier IN ('tier1_form', 'tier2_page') THEN m.email END) AS matched_t1_t2
        ,COUNT(DISTINCT CASE WHEN m.match_tier = 'tier3_session' THEN m.email END) AS matched_t3
        -- Emails whose ONLY match path is tier 3 (no tier 1 or tier 2 match exists for them at all)
        ,COUNT(DISTINCT CASE WHEN m.match_tier = 'tier3_session'
            AND g.email IS NULL
            THEN m.email END) AS tier3_only_emails
    FROM mapping_by_tier m
        LEFT JOIN emails_with_good_match g
            ON m.email = g.email
    GROUP BY 1
)

SELECT
    w.wk AS week
    ,w.total_emails
    ,w.matched_t1_t2
    ,w.tier3_only_emails AS missed_if_exclude_t3
    ,w.total_emails - w.matched_t1_t2 - w.tier3_only_emails AS unmatched
    ,ROUND(w.tier3_only_emails / NULLIF(w.total_emails, 0) * 100, 1) AS pct_missed
FROM weekly w
ORDER BY 1;
