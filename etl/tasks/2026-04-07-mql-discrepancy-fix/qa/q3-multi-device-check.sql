-- Q3: Confirm bridged_distinct_ids > bridged_emails is caused by multi-device users
-- Shows emails that matched to multiple distinct_ids via dim_session_mqls

SELECT
    m.email
    ,COUNT(DISTINCT s.distinct_id) AS distinct_id_count
    ,COUNT(DISTINCT b.session_id) AS session_count
    ,LISTAGG(DISTINCT m.match_tier, ', ') AS match_tiers
    ,MIN(s.session_started_at) AS first_session
    ,MAX(s.session_started_at) AS last_session
FROM soundstripe_prod.MARKETING.dim_session_mqls b
    INNER JOIN soundstripe_prod.CORE.fct_sessions s
        ON b.session_id = s.session_id
    INNER JOIN soundstripe_prod.MARKETING.dim_mql_mapping m
        ON b.session_id = m.mixpanel_session_id
WHERE s.session_started_at >= '2026-02-23'
    AND s.session_started_at < DATE_TRUNC('week', CURRENT_DATE())
GROUP BY 1
HAVING COUNT(DISTINCT s.distinct_id) > 1
ORDER BY distinct_id_count DESC;
