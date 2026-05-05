# M1 — Tile 12 Expansion-Rate Root-Cause

@../CLAUDE.md

Tests the four mechanisms enumerated in the parent doc (`../../findings.md` → tile 12 deep-dive):
- M1.1: Pricing/plan-structure change reduced upgrade incentives
- M1.2: Expansion-flow UX regression
- M1.3: Cohort composition shifted toward less-likely-to-upgrade customers
- M1.4: LookML measure quirk — relies on chargebee_subscription_changes within 30 days of period start; if change-event volume dropped, the measure mechanically returns lower expansion counts

## Files

- `queries.sql` — m1_q01 (chargebee event volume), m1_q02 (qualifying subs by prior_plan tier). Note q02 has a known LTV-join fanout limitation; the qualifying-subs counts are reliable, the expansion counts are not.
- `M1_chargebee_event_volume.csv` — 25 months × 5 cols
- `M1_qualifying_subs_by_prior_plan.csv` — per (month, prior_plan_tier)
- `findings.md` — verdict and roll-up

## Status

- M1.4 — TESTED (partial mechanism)
- M1.3 — TESTED (supports, with step-change in May 2025)
- M1.1 — NOT TESTED (needs Pricing PRD review with Meredith)
- M1.2 — NOT TESTED (needs Mixpanel expansion-funnel events; deferred)
- New finding surfaced: chargebee event-volume step decline in 2026-Q1 (cratered to 81 in Apr) — possible data-quality concern flagged
