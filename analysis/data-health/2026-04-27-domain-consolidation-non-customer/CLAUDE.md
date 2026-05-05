# Domain Consolidation Impact — Non-Current-Customer Cut — 2026-04-27

@../CLAUDE.md

Replication of `analysis/data-health/2026-04-24-domain-consolidation-impact/domain_consolidation_findings.md` filtered to non-current-customer traffic. Stakeholder: Sourav (CFO).

## Why this task exists

The 2026-04-24 read-out (audience: Meredith / Marketing) aggregates current-customer and non-current-customer traffic. Two populations with materially different consolidation responses (calibration pitfall #3a in `core__fct_sessions.md`: logged-in user counts held flat, anonymous distinct_ids surged +76%). Sourav asked for the cut on the non-current-customer segment.

## Segment definitions (per Devon decision 2026-04-27)

Run both, present Definition A as headline.

- **Definition A (non-current-customer at session time)** — `subscriber_category IN ('non subscriber', 'subscribing session')` (i.e., `is_existing_subscriber = false`). Source: `fct_sessions.sql:70-75` derives this column from upstream `is_existing_subscriber` aggregation. Captures: anyone who entered without an active subscription, including the session in which a new subscription was created.
- **Definition C (logged-out proxy)** — `WHERE user_id IS NULL`. Cheaper proxy; excludes logged-out current customers and includes free-signup logged-in users. Reported as robustness alternative.
- **Robustness cell A ∩ C** — `is_existing_subscriber = false AND user_id IS NULL` — anonymous + non-subscriber, the cleanest SEO-acquisition target population.

`dim_users` join NOT needed — `subscriber_category` collapses the state-as-of-session-time logic to a column read.

## Comparison frame (carryover from 2026-04-24 task)

Same windows, same DoW-aligned 2025 anchors, same hard-excluded contamination zones (2026-03-05→2026-03-25 Fastly artifact; 2026-04-14→2026-04-17 APAC spike). See parent CLAUDE.md.

## Conventions

- Diagnostic queries: `console.sql` (q1–q7 + q1.5 discovery)
- Findings: `findings_non_current_customer.md` (mirrors structure of parent's `domain_consolidation_findings.md`)
- CSVs: as needed for q4/q5/q6/q7

## Calibration prerequisites (DONE — inherited from parent task)

- `core.fct_sessions` — current (`knowledge/data-dictionary/calibration/core__fct_sessions.md`)
- `core.dim_daily_kpis` — current
- `core.fct_sessions_attribution` — current

## Cross-references

- Parent task: `analysis/data-health/2026-04-24-domain-consolidation-impact/`
- Calibration pitfall #3a (anonymous distinct_id sprawl): `knowledge/data-dictionary/calibration/core__fct_sessions.md`
- Memory: `project_domain_consolidation`, `project_wcpm_1to1_mapping_exclusion`, `project_direct_traffic_spike_2026_04_17_open`

## Status

- 2026-04-27 — workspace created.
- 2026-04-27 — q1 / q1.5 / q2 discovery executed (Devon ran via Snowflake; MCP not loaded in this session). Confirmed: (a) `subscriber_category` populates cleanly across cutover, (b) `PURCHASED_PRODUCT` IS the umbrella event covering subscription creates + transactional purchases (CREATED ⊆ PURCHASED), (c) Def A captures 82.4% of sessions; A∩C 74.5%; pure C dropped (dominated by A on both edges).
- 2026-04-27 — q3–q7 executed. Headline NC Organic Search DID = +29.5 to +49.6pp (vs parent all-traffic +11/+26). After sprawl haircut: ~+25 to +40pp.
- 2026-04-27 — `findings_non_current_customer.md` drafted.
- 2026-04-27 — q8 sprawl test executed. RESULT: avg distinct_ids per logged-in user per week = 1.001 pre / 1.000 post; ≤0.1% of users have >1 distinct_id in any week. The dbt bridge (`distinct_id_mapping`) is functioning at the cutover for users it can see (logged-in via Identify events). Pitfall #3a's sprawl mechanism is ruled out for this population. Findings doc updated to remove sprawl as a load-bearing component; headline +29.5 to +49.6pp NC Organic DID stands as real-traffic incrementality.
- 2026-04-27 — Open structural item: revise `core__fct_sessions.md` pitfall #3a to remove sprawl mechanism claim; retain observations.
- 2026-04-27 — `legit_traffic_definitions.md` drafted; q9–q12 executed and integrated. T3 "legit at-bat" share by NC channel: Organic 57%, Paid Search 60%, Direct 19%, Email 7%, Paid Social 8%. NC Organic DID survives noise removal at every tier (T0 +49.6pp / T2 +60.1pp / T3 +52.9pp); consolidation lift is concentrated in non-noise traffic. q12 surfaced previously-undocumented persistent CN Direct instant-bounce baseline (~3-11K/wk steady-state) — flag for engineering follow-up alongside the 2026-04-17 spike.
