# M2.1 — Bot-Strip Variant of M2 Channel Decomposition

@../CLAUDE.md

Tests M2's mechanism D1 ("Pre-cutover Direct artifact already creeping in") by re-running the decomposition with a baseline-bot-traffic predicate stripped from the denominator. Reports both **aggregate** (treating total sessions × blended CVR as one pair) and **per-channel** decompositions, distinct.

## Bot-strip predicate

A session is classified as bot/strippable if **all** of:
- `session_duration_seconds < 5` (very short)
- `created_subscription = 0` (didn't subscribe)
- `single_song_purchase_count = sfx_purchase_count = market_purchase_count = 0` (no license purchases)
- `signed_up = 0` (didn't sign up)
- `enterprise_form_submissions = enterprise_landing_form_submissions = enterprise_schedule_demo = 0` (no MQL form)

**The "case-in" rule:** any session that converted/signed-up/submitted-form is preserved regardless of duration. Edge cases like instant-redirect checkout sessions don't get falsely stripped.

## Files

- `queries.sql` — m2_1_q01: per-month per-channel sessions/subs with bot-strip flag
- `M2_1_channel_monthly_bot_strip.csv` — 168 rows (24m × 7 channels) with both total and bot-stripped session counts
- `M2_1_decomposition_2024_05_to_2026_02.csv` — aggregate decomposition with and without bot strip
- `findings.md` — verdict and roll-up

## Threshold sensitivity

`duration < 5` is conservative. Tighter (`< 1`) or looser (`< 10`) thresholds would shift the bot-stripped session count meaningfully. The current threshold strips ~47-52% of sessions; this is consistent with B2C SaaS landing-page experience but the magnitude is worth noting.
