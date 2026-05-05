-- M2 — Subscriber acquisition -74% channel decomposition
-- Author: Devon (analyst)  Date: 2026-04-28
-- Source: soundstripe_prod.core.fct_sessions
-- Calibration: core.fct_sessions current 2026-04-24-r2; session-cached this analysis (q01)
--
-- The 24-month decline in subscribing_sessions (May 2024: 2,070 → Apr 2026: 539 = -74%) drives
-- the absolute conversion-count decline embedded in tiles 1, 2, 4. q01.csv has channel splits at
-- the SESSION level but not at the CONVERSION level. This query produces conversions per channel
-- per month so we can do a §5 shift-share decomposition: how much of the -74% is channel-mix
-- shift vs. per-channel CVR collapse?

------------------------------------------------------------------------
-- m2_q01 — per-channel session + conversion counts, 24m monthly
------------------------------------------------------------------------

SELECT
    DATE_TRUNC('month', session_started_at)::DATE                                AS month_start,
    CASE WHEN last_channel_non_direct IN
            ('Direct','Organic Search','Paid Search','Paid Social','Referral','Email')
         THEN last_channel_non_direct
         ELSE 'Other' END                                                        AS channel,
    COUNT(DISTINCT session_id)                                                   AS sessions,
    COUNT(DISTINCT CASE WHEN created_subscription > 0 THEN session_id END)       AS subscribing_sessions,
    COUNT(DISTINCT CASE WHEN NVL(single_song_purchase_count, 0) > 0
                          OR NVL(sfx_purchase_count,         0) > 0
                          OR NVL(market_purchase_count,      0) > 0
                          THEN session_id END)                                   AS license_sessions,
    COUNT(DISTINCT CASE WHEN signed_up > 0 THEN distinct_id END)                 AS signed_up_visitors
FROM soundstripe_prod.core.fct_sessions
WHERE session_started_at >= '2024-05-01'
  AND session_started_at <  '2026-05-01'
GROUP BY 1, 2
ORDER BY 1, 2;

-- TYPE AUDIT — m2_q01:
--   Declared denominator: sessions (per-channel, per-month).
--   JOIN chain: NONE (single-table aggregation).
--   RESULT: PASS.
--
-- Note: this query is NOT artifact-corrected. The Direct channel in 2026-03 and 2026-04 includes
-- the artifact sessions (W1: 165,660 in Mar; W2: 66,274 in Apr). The decomposition below uses the
-- 2024-05 → 2026-02 window (clean) for the headline -74% attribution to avoid muddying the channel
-- mix shift with the artifact.
