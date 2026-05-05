# WCPM Pricing Test — Refresh + Significance Read-out

**Status:** complete (refresh + significance read), 2026-04-27
**Stakeholder:** Meredith Knott
**Origin task:** refresh + statistical significance follow-up to 2026-04-18 audit
**Test:** `wcpm_pricing_test` in Statsig, 3 arms (Control / Mid Reduction / Deep Reduction), started 2026-03-13, still running as of 2026-04-27

## Scope

1. **Refresh** the 2026-04-18 WCPM audit numbers through 2026-04-27 (9 additional days of data).
2. **Statistical significance** read-out on the headline metric (WCPM add-on attach) across the three variants — point estimates, Wilson CIs, pairwise tests, MDE/power, sequential-peek caveats.

## Headline finding

Mid Reduction shows a directional +165% relative lift on WCPM add-on attach rate (0.123% vs Control's 0.046%). The Bonferroni-adjusted pairwise p-value is **0.1088** — does not clear α=0.025. Three-arm omnibus chi-square: p=0.1393. Deep Reduction sits between Mid and Control (0.074%, +60% relative, p_bonf=0.81); the Mid-vs-Deep ordering is not separately substantiated.

Per-arm point estimates with Wilson 95% CIs:

- Control (24.99/mo): 5 / 10,788 = 0.0463% [0.0198%, 0.1085%]
- Mid Reduction (17.99/mo): 13 / 10,601 = 0.1226% [0.0717%, 0.2097%]
- Deep Reduction (15.99/mo): 8 / 10,786 = 0.0742% [0.0376%, 0.1463%]

Sample-size context. At Control's baseline rate (~0.046%), detecting a +200% lift at 80% power needs ~19K per arm; current N is ~10.7K (56% of required). Detecting +100% needs ~60K per arm (current N is 18%). Mid Reduction's observed lift would clear significance at roughly 30K per arm, reachable in ~30 days of continued accrual. Per §11 Intervention Classification: **STRUCTURAL** on test sizing (future tests at this baseline rate must size for ≥10× current allocation if a +50% lift is the MDE target), **OPERATIONAL** on the immediate decision (continue accruing).

**CUPED applied (engagement covariate: pre-exposure 7-day fct_events count, sum metric):** ρ² = 7.12 × 10⁻⁵, variance reduction = 0.0071%. CUPED moves the Mid-vs-Control Bonferroni p from 0.1299 → 0.1269 — detectable but not significant. The covariate is sensible (99.3% population coverage, high variance) but the gain is bounded by Y's near-zero baseline rate: ~26 attaches per arm gives Var(Y) a binomial floor that no smoothly-varying covariate can meaningfully reduce. Pulse-reported CIs on this experiment are likely similarly rate-limited.

See `findings.md` for full write-up; `stakeholder-readout.md` for Meredith-facing message; `stats/results.md` for statistical detail (including the CUPED section); `stats/per_arm_attach.png` for the per-arm chart.

## Open structural caveats (carried forward)

- Finding 4 — `statsig_clickstream_events_etl_output` late-arrival drop (`project_statsig_model_late_arrival_open.md`). Refresh: still 1 orphan; magnitude unchanged.
- Finding 6 — Statsig 1:1 mapping (`project_wcpm_1to1_mapping_exclusion.md`). Refresh: drift from 13.5% → 14.24% over 9 days; sprawl is still accumulating. Sidestepped by warehouse-recovered cohort by design.

## Links

- Original audit: `../2026-04-18-wcpm-test-audit/`
- Asana: pending — no specific ticket linked to the refresh ask. If stakeholder requests ticketing, mirror the 04-18 audit's `asana-ticket.md` format.
- Mixpanel report and Statsig console: not re-exported in this refresh; the warehouse-direct queries in `console.sql` are the canonical numbers for this read.
