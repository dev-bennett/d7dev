# Inquiry — WCPM Pricing Test Refresh + Significance

## Original ask (2026-04-18, Meredith)

> Hey devon - When you have a free minute, can you review the StatSig WCPM Pricing Test? The data that I'm seeing in Mixpanel is different from StatSig on number of add-ons purchased. Just want to make sure everything is set up and reporting properly.
>
> Mixpanel: https://mixpanel.com/s/b30sb
> Statsig Test: https://console.statsig.com/5BaYGGuAWgthoz9gc1kXt3/6HtIxq5IfdlXn6veyFmMn3

That ask produced the 2026-04-18 audit (`../2026-04-18-wcpm-test-audit/`). Reconciliation complete; two OPEN structural findings logged (Finding 4 — Statsig clickstream model late-arrival drop; Finding 6 — Statsig 1:1 identifier-mapping exclusion).

## Refresh ask (2026-04-27, Devon)

Re-run the audit with the window extended to 2026-04-27 (9 additional days of data) AND produce a new deliverable that statistically tests the variants and reports confidence / significance values as of now.

## Scope decisions (locked via AskUserQuestion 2026-04-27)

- **Primary metric:** WCPM add-on attach (Existing-Sub + New-Sub combined). Matches what Statsig Pulse measures. The underpowered finding will be the expected headline at current N.
- **Cohort definition:** Warehouse-recovered only — raw `_external_statsig.exposures` with `stable_id`-level first-exposure dedup. Multi-arm `stable_id`s tie-broken by earliest exposure timestamp. Recovers users that Pulse's 1:1 mapping drops; numbers will diverge from Statsig Pulse by design.

## What this deliverable answers

1. Refreshed Mixpanel-side and Statsig-side counts through 2026-04-27, with the original audit's reconciliation chain re-evaluated.
2. Per-arm exposed N and per-arm WCPM add-on attach count, computed against the warehouse-recovered cohort.
3. Per-arm attach rate with Wilson 95% confidence intervals.
4. Pairwise two-proportion z-tests (Mid vs Control, Deep vs Control) with Bonferroni-adjusted p-values; Newcombe rate-difference CIs; omnibus Fisher's exact (3×2).
5. Minimum detectable effect at current N (α=0.025, power=0.80) and a sequential-testing-peek caveat.
6. Drift check on Finding 4 (late-arrival drop) and Finding 6 (1:1 mapping ~13.5%) magnitudes given the 9 days of new data.

## What this deliverable does NOT answer

- Bayesian posteriors / credible intervals on the variant effects (out of scope per user choice; frequentist only).
- ARPU / revenue-per-exposed-user contrasts (out of scope per user choice; attach-rate only).
- Subscription-conversion-rate contrasts (out of scope per user choice).
- Whether the test design's exposure trigger covers the actual decision surface (carried forward as design caveat from original Finding 3).
- Closure on Findings 4 or 6 (drift check only; not a fix).
