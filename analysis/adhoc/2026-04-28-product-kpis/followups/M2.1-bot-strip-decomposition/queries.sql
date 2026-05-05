-- M2.1 — Bot-strip variant of M2 channel decomposition
-- Author: Devon  Date: 2026-04-28
--
-- Predicate: a session is "bot-stripped" if duration<5 AND no conversion/signup/form
-- (the "case-in" rule preserves any converting session regardless of duration).

SELECT
    DATE_TRUNC('month', session_started_at)::DATE AS month_start,
    CASE WHEN last_channel_non_direct IN
            ('Direct','Organic Search','Paid Search','Paid Social','Referral','Email')
         THEN last_channel_non_direct
         ELSE 'Other' END AS channel,
    COUNT(DISTINCT session_id) AS sessions_total,
    COUNT(DISTINCT CASE WHEN NOT (
              NVL(session_duration_seconds, 0) < 5
              AND NVL(created_subscription, 0) = 0
              AND NVL(single_song_purchase_count, 0) = 0
              AND NVL(sfx_purchase_count, 0) = 0
              AND NVL(market_purchase_count, 0) = 0
              AND NVL(signed_up, 0) = 0
              AND NVL(enterprise_form_submissions, 0) = 0
              AND NVL(enterprise_landing_form_submissions, 0) = 0
              AND NVL(enterprise_schedule_demo, 0) = 0
         ) THEN session_id END) AS sessions_botstripped,
    COUNT(DISTINCT CASE WHEN created_subscription > 0 THEN session_id END) AS subscribing_sessions,
    COUNT(DISTINCT CASE WHEN NVL(single_song_purchase_count, 0) > 0
                          OR NVL(sfx_purchase_count, 0) > 0
                          OR NVL(market_purchase_count, 0) > 0
                          THEN session_id END) AS license_sessions,
    COUNT(DISTINCT CASE WHEN NVL(session_duration_seconds, 0) < 5
                          AND NVL(created_subscription, 0) = 0
                          AND NVL(single_song_purchase_count, 0) = 0
                          AND NVL(sfx_purchase_count, 0) = 0
                          AND NVL(market_purchase_count, 0) = 0
                          AND NVL(signed_up, 0) = 0
                          AND NVL(enterprise_form_submissions, 0) = 0
                          AND NVL(enterprise_landing_form_submissions, 0) = 0
                          AND NVL(enterprise_schedule_demo, 0) = 0
                        THEN session_id END) AS bot_sessions_stripped
FROM soundstripe_prod.core.fct_sessions
WHERE session_started_at >= '2024-05-01'
  AND session_started_at <  '2026-05-01'
GROUP BY 1, 2
ORDER BY 1, 2;

-- TYPE AUDIT — m2_1_q01:
--   No rates declared at query level; rates derived downstream in Python.
--   JOIN chain: NONE — single-table aggregation.
--   Bot-strip predicate is symmetric in numerator/denominator: the predicate explicitly
--   excludes all conversion/signup/form sessions, so subscribing_sessions ⊆ sessions_botstripped
--   by construction. No converting session is lost to the strip.
--   RESULT: PASS.
