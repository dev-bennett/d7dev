# Recover remaining tier-3-only MQLs (pricing CTA via dim_mql_mapping, /api CTA, tier-2 window)

Follow-up to [#718](https://github.com/SoundstripeEngineering/dbt-transformations/pull/718) (merged 2026-04-22), which shipped the v2 tiered MQL attribution model. As of merge, ~31% of the tracked MQL population remained in tier 3 (false-positive-prone). This PR closes the gap to ~9% genuinely untrackable.

## Summary

- **fct_sessions_build:**
  - Add `backfill_from` var to the incremental block to avoid manual watermark resets on future scope changes.
  - `enterprise_schedule_demo`: **unchanged**. An earlier proposal to add `Clicked Contact Sales` / `Enterprise Intent` here was deployed and reverted on 2026-05-07. That signal fires 49× more often than the existing one (1,997 events / 1,567 distinct_ids YTD-2026 vs. 36/32) and the Looker measure consuming it (`mqls_schedule_demo`) has no HubSpot anchoring, so the new signal inflated Mixpanel-side MQL counts past HubSpot. The signal is correctly captured below in `dim_mql_mapping`, where the join to HubSpot form submissions filters it to real MQLs.
- **dim_mql_mapping:**
  - Add `Clicked Contact Sales` / `Enterprise Intent` and `CTA Form Submitted` on `/api` to the `form_events_mixpanel` event filter (tier 1 capture, HubSpot-anchored).
  - Normalize `/library/` out of Mixpanel-side `base_url` so HubSpot's `/pricing` matches Mixpanel's `/library/pricing`.
  - Widen tier 2 page-activity window from 120s to 300s (covers slow-fill cases on `/music-licensing-for-enterprise`).
  - Add `/library/pricing` and `/api` to `enterprise_url_patterns` for tier 3 coverage.

## Context

Q6b in the task QA workspace confirmed that pricing-page MQLs fire `Clicked Contact Sales` within seconds of HubSpot submission — pure tier 1 candidates blocked only by event-filter and base-URL mismatch. Q4/Q8 enumerated the remaining tier-3-only and unmatched populations. Coverage detail in `etl/tasks/2026-04-07-mql-discrepancy-fix/qa/coverage-summary.md`.

The 2026-05-07 incident also confirmed: signal-routing matters as much as signal-correctness. `dim_mql_mapping` is HubSpot-anchored (its outputs are gated by joins to real form submissions); `fct_sessions_build` is event-volume-driven and feeds Looker measures with no HubSpot anchoring. The pricing-CTA signal is right; the original proposal landed it in the wrong place.

## Pre-merge

`fct_sessions_build` rows from 2026-02-23 forward must be deleted from `soundstripe_prod.TRANSFORMATIONS` (TRANSFORMER role) so the incremental rebuild picks up the corrected definition (i.e., the original `enterprise_schedule_demo` filter, undoing the 2026-05-07 deployed-and-reverted version). `dim_mql_mapping` is `materialized='table'` (full refresh on every run), so no prep needed there.

## Test plan

- [ ] `fct_sessions_build.enterprise_schedule_demo`: distinct sessions YTD-2026 with the field > 0 should be ~30 (matching the original `Clicked Element` / `Enterprise Contact Form` volume), not the inflated ~1,599 from the reverted version.
- [ ] Looker `mqls_schedule_demo` should match its pre-incident level (small slice of the source-distribution chart, not the dominant bucket).
- [ ] `dim_mql_mapping`: `match_tier` distribution shifts toward tier 1 for `form_page_type = 'enterprise_landing'` cases that previously fell to tier 3.
- [ ] Re-run `etl/tasks/2026-04-07-mql-discrepancy-fix/qa/q4-tier3-exposure.sql` against `soundstripe_prod` — expect tier-3-only exposure to drop from ~31% to ~9%.
- [ ] Re-run `etl/tasks/2026-04-07-mql-discrepancy-fix/qa/q2-aligned-comparison.sql` — expect `bridged_distinct_ids` ≈ `bridged_emails`.
