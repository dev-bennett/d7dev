# Pricing Page Scroll-Depth Banner Change — 2026-04-23

@../CLAUDE.md

Post-change validation of the 2026-02-24 pricing-page banner shrink. Stakeholder: Meredith Knott. Goals stated in request: reduce page bounce rate, increase persona card clicks.

## Inputs

- `stakeholder-request` — Meredith's request (ship date 2026-02-24, original due 2026-03-11, reference Notion analysis)
- `product-analysis-not-from-data-team` — product team's pre-change analysis covering Jan 7 – Feb 6 2026 (funnel, segments, flagged leaks)
- Reference: `analysis/data-health/2026-04-01-direct-traffic-spike/2026-04-01-q1-conversion-correction.md` — correction pattern for Mar 5 – Mar 25 contamination window

## Status

- **Draft complete** (2026-04-23). findings.md + message-to-meredith.md drafted; console.sql Q1–Q7 run; 17 discovery queries (D1–D17) complete. Pending: stakeholder send + commit, plus optional within-cohort decomposition if Meredith requests it.
- Plan: `/Users/dev/.claude/plans/mossy-painting-pillow.md`

## Headline outcomes

- Goal 1 (reduce bounce): not met. Engagement-proxy bounce rate 34.4% → 37.0% (+2.6pp). Scroll-based bounce unmeasurable — Mixpanel autocapture scalars collapsed on 2026-02-25.
- Goal 2 (increase persona clicks): not met. Cumulative persona selection 46.1% → 42.0% (-4.1pp), concentrated at the entry step (56.3% → 51.7%).
- Aggregate subscription rate shows 3.25% → 4.07% (+25% relative) pre-vs-post, but D20 weekly series shows the rise happened during January – mid-February (pre-deploy) and plateaued at ~4% by the week of 2/2. Composition (free-account share) kept rising through April with no corresponding conversion rise after mid-Feb. Neither the 2/24 banner deploy nor the 3/16 composition step is supported as the driver. Origin of the pre-deploy drift is not diagnosed by this analysis.

## Structural issues surfaced (separate follow-ups)

- Mixpanel autocapture spatial properties (scroll, click-coords) stopped populating on 2026-02-25. Session Replay turned on 2026-03-01. Platform-wide impact potential.
- `stg_events.sql` `page_category` classifier uses exact-match on old URL paths (`pricing`, `checkout`, `signup`, `sign_in`); silently returns near-zero from mid-March onward for these categories.
- Header pricing CTA renamed and re-evented (`Clicked Pricing Link` → `Clicked Sign Up Button` with `link_text = "See Pricing"`).

## Deployment context

Site-wide deploy on 2026-02-24 — no Statsig or Fastly VCL experiment wrapper (confirmed via codebase search of `context/dbt/models/marts/_external_statsig/` and `context/lookml/views/Statsig/`). Comparison is pre/post time-series only. Causal claims limited.

## Comparison windows

- Pre-change: Jan 7 – Feb 6 2026 (matches product team baseline)
- Post-2wk: Feb 24 – Mar 10 2026 (matches original due-date intent)
- Post-8wk: Feb 24 – Apr 23 2026 (persistence check)

## Data-quality risk on post windows

- Mar 5 – Mar 25 direct-traffic artifact sessions (~200K) — apply correction filter from 2026-04-01 investigation.
- Apr 13 – present OPEN direct-traffic spike (per `project_direct_traffic_spike_2026_04_17_open.md`) — residual uncertainty, not resolved.

## Conventions

- Query files: single file per query set, labeled single-SELECT sections per `feedback_one_sql_file_per_query_set`.
- Exports: `q<N>.csv` in the same directory as the query file.
- Event names: never fabricated — discovery phase (D1–D5) must confirm in warehouse before funnel SQL is written.
