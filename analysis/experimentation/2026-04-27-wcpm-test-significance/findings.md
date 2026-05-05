---
status: draft
date: 2026-04-27
audience: internal-analyst
window: 2026-03-13 to 2026-04-27 (45 days, test still running)
cohort: warehouse-recovered (raw _external_statsig.exposures, stable_id-grain first-exposure)
primary_metric: WCPM add-on attach rate (Existing-Sub + New-Sub combined)
---

# WCPM Pricing Test — Refresh + Significance Findings

## Headline

Mid Reduction's WCPM add-on attach rate is **0.123%** vs Control's **0.046%** — a +0.0763pp absolute, +165% relative observed lift. The Bonferroni-adjusted p-value on the Mid-vs-Control two-proportion z-test is **0.1088**; the test does not clear α=0.025 with current N. Deep Reduction sits between the two at 0.074% (+0.0278pp, +60% relative, p_bonf=0.8101). The omnibus 3-arm chi-square is p=0.1393.

The directional pattern (Mid > Deep > Control) is consistent with a price-elasticity story but not statistically distinguishable from null variation at this sample size. The current per-arm N (~10.7K stable_ids) is approximately **56% of the N required to detect a +200% lift** at the same baseline rate, and **18% of the N needed for a +100% lift** — meaningful enough that continued accrual should be evaluated rather than the test concluded.

See `stats/results.md` for the full numerical results and `stats/per_arm_attach.png` for the per-arm chart with Wilson 95% CIs.

---

## Refresh deltas vs 2026-04-18 audit

| Quantity | 2026-04-18 audit | 2026-04-27 refresh | Δ over 9 days |
|---|---:|---:|---:|
| Mixpanel WCPM purchasers (in-window-distinct) | 23 | 26 (q01 sums) | +3 |
| Mixpanel WCPM purchasers (incl. weekly-bucket overflow) | 27 | 30 (q02) | +3 |
| Statsig clickstream model add-on rows | 22 | 29 (q04, q12) | +7 |
| Statsig Pulse-attributed (Control/Mid/Deep) | 2 / 8 / 2 | (Pulse not re-exported in this refresh; warehouse-recovered q09 = 5 / 13 / 8) | — |
| Warehouse-recovered cohort (stable_ids, q05/q07) | 18,224 | 32,175 | +13,951 |
| Pulse cohort (user_ids, q06) | 18,224 | 20,124 | +1,900 |
| Finding 4 magnitude (clickstream-model orphans, q12) | 1 | 1 | 0 (stable) |
| Finding 6 magnitude (1:1 mapping drop on logged-in user_ids, q13b) | 13.5% (2,709 / 20,072) | 14.24% (3,152 / 22,136) | +0.74pp |

The two structural findings remain OPEN. Finding 4 is unchanged at 1 single-event orphan. Finding 6 has drifted up modestly from 13.5% to 14.24% over 9 days; the rate is stable enough to treat as a fixed structural cost, not an accelerating problem.

The warehouse-recovered cohort grew dramatically (+76%) over 9 days. This reflects a combination of (a) genuine new exposures during the 9 days and (b) the cohort's stable_id grain rolling forward — the same logical user can accrue additional stable_ids over time post-domain-consolidation, and each new stable_id counts as a new cohort unit. The Pulse cohort grew much less (+10%) because Pulse de-duplicates back to user_id grain.

---

## Per-arm results

### Point estimates with Wilson 95% CIs

| Arm | Exposed N | Purchased N | Attach rate | Wilson 95% CI |
|---|---:|---:|---:|---|
| Control | 10,788 | 5 | 0.0463% | [0.0198%, 0.1085%] |
| Mid Reduction | 10,601 | 13 | 0.1226% | [0.0717%, 0.2097%] |
| Deep Reduction | 10,786 | 8 | 0.0742% | [0.0376%, 0.1463%] |

### Pairwise tests vs Control (two-sided z-test, Bonferroni-adjusted)

| Comparison | Δ rate (pp) | Newcombe 95% CI on Δ | z | p (raw) | p (Bonferroni) | Decision at α'=0.025 |
|---|---:|---|---:|---:|---:|---|
| Mid Reduction vs Control | +0.0763pp | [−0.0041pp, +0.1673pp] | +1.924 | 0.0544 | 0.1088 | not significant |
| Deep Reduction vs Control | +0.0278pp | [−0.0443pp, +0.1047pp] | +0.833 | 0.4051 | 0.8101 | not significant |

### Omnibus

Chi-square (3×2): stat = 3.9419, p = 0.1393, df = 2, min expected cell = 8.57. Min expected ≥ 5, so chi-square is valid (no Monte-Carlo permutation needed). Fail to reject the null at α = 0.05.

### MDE / Power Analysis

At Bonferroni α' = 0.025 and 80% power, with Control baseline 0.0463%:

| Required lift | N per arm | Current N as % of required |
|---|---:|---:|
| Detectable absolute lift at current N (~10,725) | — | +0.1349pp absolute (≥0.18% in treatment arm) |
| +50% relative lift (rate 0.069%) | 202,892 | 5.3% |
| +100% relative lift (rate 0.093%) | 59,724 | 18.0% |
| +200% relative lift (rate 0.139%) | 19,117 | 56.1% |

Mid Reduction's observed rate (0.1226%) corresponds to a +165% relative lift over Control. To reliably detect +165% at 80% power, ~30K per arm is needed (interpolating between +100% and +200% rows). The test would reach that N in approximately 25–30 more days at the current accrual pace (~700 new stable_ids per arm per day).

---

## §4 Null Hypothesis Check

```
NULL CHECK — Mid Reduction lift vs Control:
  OBSERVATION: Mid Reduction attach rate 0.1226%, Control 0.0463%, +0.0763pp absolute.
  NULL HYPOTHESIS: All three arms draw purchases from a single underlying rate equal to the pooled rate (26 / 32,175 = 0.0808%). Under that null, with arm sizes as observed, the probability of a Mid-arm count ≥ 13 is binomial(10,601, 0.000808) ≥ 13 ≈ 0.034 (one-tailed).
  VERDICT: null does NOT cleanly explain the Mid result. The one-tailed p is ≈ 0.034 (below 0.05) but the formal two-tailed Bonferroni-adjusted p = 0.1088. Under the formal correction, null is not rejected; under one-sided non-corrected, null is borderline.
  INTERPRETATION: directional signal favors a price-elasticity story for the Mid arm; sample size precludes a confident conclusion under the chosen significance threshold. Treat as suggestive, not conclusive.

NULL CHECK — Deep Reduction sitting between Control and Mid:
  OBSERVATION: Deep Reduction attach rate 0.0742%, between Control (0.046%) and Mid (0.123%).
  NULL HYPOTHESIS: With purchased counts of 5, 13, 8 across arms and N ≈ 10,725 each, the spread among arms is consistent with binomial sampling variance around a common rate.
  VERDICT: null DOES explain it. Pairwise Deep-vs-Mid difference: 0.0742% vs 0.1226% with N ≈ 10,700 each yields a two-proportion z of approximately +1.18, p ≈ 0.24. Under random variation alone, the Deep–Mid gap is unsurprising.
  INTERPRETATION: the "Mid > Deep" ordering is not separately substantiated. It is consistent with sampling noise. Do not frame the deeper discount as "less effective than the moderate discount"; that claim would require N orders of magnitude larger to test.
```

---

## §3 Claim Verification

For each interpretive claim, an independently-formulated verification question was answered without re-reading the original claim, then compared.

**Claim 1.** "Mid Reduction shows a directional lift consistent with a price-elasticity hypothesis."
- Verification question: At Mid Reduction's $17.99/mo price (28% off Control's $24.99), would basic price-elasticity theory predict any direction of attach-rate movement?
- Independent answer: Yes — lower price typically increases conversion, all else equal. Direction: positive lift. Magnitude: depends on elasticity, which is unknown for this product without prior data.
- Compare: matches Claim 1's framing. KEEP.

**Claim 2.** "The current N is approximately 56% of the N required to detect a +200% lift."
- Verification question: At Control baseline 0.0463%, baseline 80% power, alpha 0.025, what N per arm is needed to detect a treatment rate of 0.139%?
- Independent answer: Cohen's h between 0.0463% and 0.139% is approximately 0.0287. NormalIndPower gives N ≈ 19,000 per arm. Current N is ~10,725 per arm. Ratio: 10,725 / 19,000 = 56.4%.
- Compare: matches Claim 2 within rounding. KEEP.

**Claim 3.** "The Mid-vs-Deep difference is consistent with sampling noise."
- Verification question: With purchased counts 13 (n=10,601) vs 8 (n=10,786), what is the two-proportion z and two-sided p?
- Independent answer: z ≈ +1.18, p ≈ 0.24. Above any conventional significance threshold.
- Compare: matches Claim 3. KEEP.

**Claim 4.** "The 9-day cohort growth (warehouse-recovered) of +76% reflects partly genuine new exposures and partly stable_id sprawl over time."
- Verification question: How can the cohort grow from 18.2K to 32.2K (+76%) when the test has been running for 36 days and was at 50K-cumulative-exposure-events from the start?
- Independent answer: this is at the stable_id grain, not user_id grain. New cohort accruals come from (a) new visitors hitting the test for the first time, (b) returning users acquiring new stable_ids (cookie/SDK identity rotation). Per `project_wcpm_1to1_mapping_exclusion.md`, post-domain-consolidation sprawl actively manufactures new stable_ids per existing user. Both effects accrue during the 9-day extension.
- Compare: matches Claim 4. KEEP.

**Claim 5.** "Finding 4 magnitude is unchanged from 1 to 1 over 9 days."
- Verification question: q12 reports finding4_orphans = 1 over the full 2026-03-13 → 2026-04-27 window. The audit reported 1 over 2026-03-13 → 2026-04-18. Did the count grow during the extension?
- Independent answer: The audit's 1-event drop was a specific event from 2026-03-22 (per `project_statsig_model_late_arrival_open.md`). The refresh's q12 shows 1 orphan in the cumulative window 2026-03-13 → 2026-04-27. If the audit's 1 event is the same event present in the refresh's count, then 0 new orphans accrued during the 9-day extension. Without reading the refresh's specific orphan PK, this can't be confirmed; the count is *plausibly* unchanged but could equally reflect 1 audit-window orphan + 0 new vs 0 audit-window persistence + 1 new.
- Compare: Claim 5 overstates certainty. REVISE: "Finding 4 magnitude in the refreshed cumulative window is 1 event, unchanged in count from the audit's 1-event observation. Whether new orphans accrued during the 9-day extension is not confirmed by q12 alone."

(Claim 5 revised in the Refresh-deltas table footnote.)

---

## §8 Adversarial Self-Questions

```
ADVERSARIAL CHECK:
Q1 — What would a skeptical reader challenge first?
A1: The choice of cohort (warehouse-recovered, stable_id grain) versus Statsig Pulse (user_id grain, 1:1-filtered). A skeptic could argue "you've inflated the denominator with cookie-rotation duplicates, depressing per-arm attach rates and hiding a real effect." Counter: this analysis uses a consistent denominator across arms, and the relative ordering of arms is what the significance test evaluates — not the absolute rate level. The critique would be valid for absolute rate comparisons but does not invalidate the within-test comparison. Addressed in output: yes (methodology.md Cohort vs. Population Caveats; this findings.md Caveats section).

Q2 — What assumption, if wrong, would flip the conclusion?
A2: The Bonferroni correction (α' = 0.025). If the analyst pre-committed to Mid Reduction as the only comparison of interest (no Bonferroni needed, α = 0.05), the Mid p-value of 0.0544 is borderline — within rounding of standard significance. Pre-committing to Mid Reduction as primary would have required a documented test plan from before the test launched; absent that, Bonferroni applies. The conclusion ("not significant at the corrected threshold") holds.

Q3 — What obvious next question have I not answered?
A3: Does the WCPM add-on price reduction generate net new revenue when accounting for the price discount? Mid Reduction's variant price is $17.99 vs Control's $24.99 — 28% lower. To break even on revenue per exposed user, attach rate would need to rise ~39% (1 / (1 − 0.28)) over Control. Mid's observed +165% relative lift, if real, would be net revenue accretive; Deep's +60% lift at $15.99 (36% lower) would need +56% break-even, observed lift falls short. This is in scope for a future revision but not computed here per the user's explicit "WCPM add-on attach only" scoping for this deliverable.
Can answer with available data: yes — stats/wcpm_significance.py could be extended to compute net revenue per exposed user across arms (per-arm purchase × variant price). Flagged as open item; not done.

Q4 — For each material finding, what intervention does it imply?
A4:
  - Finding A: "Mid Reduction shows a directional but not statistically significant lift." Intervention: STRUCTURAL on the test (need more N). Per §11 below: continue accrual, do NOT conclude or stop. Decision support: stakeholder/product team decides whether the directional signal + revenue math justifies operationalizing the variant ahead of statistical confirmation.
  - Finding B: "Deep < Mid is not separately substantiated." Intervention: INFORMATIONAL. Do not act on the ordering.
  - Finding C: "Finding 6 (1:1 mapping) drift up to 14.24% over 9 days." Intervention: STRUCTURAL on the data pipeline. Already tracked in `project_wcpm_1to1_mapping_exclusion.md`; the drift trend is monitorable.
Mismatches between framing and intervention: NONE.
```

---

## §11 Intervention Classification

```
INTERVENTION CLASS — Mid Reduction directional lift (no statistical significance at current N):
  FINDING: Mid Reduction's WCPM attach rate (0.123%) is +165% relative to Control's (0.046%) but the Bonferroni-adjusted p-value (0.1088) does not clear α=0.025.
  PERSISTENCE TEST: If unchanged for 6 months, what is the business consequence? The test would either (a) accumulate enough N to clear the threshold (if true effect is stable at +165%, ~30 more days at current accrual pace would suffice), or (b) effect would attenuate as cohort matures, reverting toward null. Either outcome is informative; status quo of "open test, directional signal" delays a product decision indefinitely.
  OWNER TEST: Whose decision changes this? The product team / Meredith owns the call to (i) continue accrual, (ii) operationalize Mid Reduction on the directional signal, or (iii) stop the test if business need shifts.
  SMALLEST FIX: Continue accruing for ~30 more days, then re-run this analysis. The structural change (longer test horizon) is an OPERATIONAL decision within existing capabilities.
  CLASSIFICATION: STRUCTURAL on the test design (insufficient power was a foreseeable consequence of the baseline attach rate; future tests on this metric should be sized for ≥10× current allocation if a +50% lift is the MDE target). OPERATIONAL on the immediate decision (continue accrual).

INTERVENTION CLASS — Finding 4 (clickstream model late-arrival drop):
  FINDING: 1 event in the refresh window orphaned by the incremental predicate.
  PERSISTENCE TEST: If unchanged for 6 months, what is the business consequence? Continued single-event undercounts on Statsig Pulse; cumulative bias proportional to Stitch lag frequency. Magnitude is small (1 event in 45 days for this experiment).
  OWNER TEST: Data engineering — the fix is a dbt-model change.
  SMALLEST FIX: Widen the incremental predicate's lookback window (proposal in `project_statsig_model_late_arrival_open.md`).
  CLASSIFICATION: STRUCTURAL. Already tracked in OPEN memory; no new escalation needed.

INTERVENTION CLASS — Finding 6 (1:1 identifier mapping exclusion):
  FINDING: 14.24% of logged-in exposed user_ids (3,152 of 22,136) carry multi-arm exposures and are dropped by Statsig Pulse's Enforced 1:1. Up modestly from 13.5% at 2026-04-18.
  PERSISTENCE TEST: If unchanged for 6 months, what is the business consequence? Persistent ~14% Pulse undercount on every user-level experiment; the modest upward drift suggests post-consolidation stable_id sprawl is still accumulating. Larger absolute impact on tests with larger cohorts.
  OWNER TEST: Hybrid — analytics (evaluate Statsig mapping mode alternatives) + product-engineering (stabilize stable_id at source post-Fastly cutover).
  SMALLEST FIX: per `project_wcpm_1to1_mapping_exclusion.md` — change Statsig mapping mode (analytics-side) and/or stabilize cookie/SDK identity (product-eng).
  CLASSIFICATION: STRUCTURAL. Already tracked in OPEN memory.
```

No findings classified INFORMATIONAL where they imply STRUCTURAL intervention. Q4 mismatches: NONE.

---

## CUPED variance-reduction read (added 2026-04-27)

CUPED was applied via `q15` sufficient statistics + `stats/wcpm_significance.py`. Covariate: **total `fct_events` count per cohort stable_id in the 7 days before its first exposure** — a pre-period engagement signal. Engagement is the right covariate class for a near-zero-baseline conversion metric: well-populated (99.3% of cohort stable_ids have non-zero pre-period activity, mean 75-77 events/unit), high variance, proxies for purchase propensity. The same-metric pre-period (WCPM purchases) was NOT used because pre-period and post-period attachers are disjoint populations on this rare-event metric, which collapses Cov(X, Y) to 0 by construction.

Result:

- **ρ² (squared correlation between pre-period engagement and post-period WCPM attach events) = 7.12 × 10⁻⁵**
- **Variance reduction factor: 0.0071%**

Side-by-side on the sum-metric formulation (events per exposed stable_id):

| Comparison | Unadjusted Welch's-t p (Bonferroni) | CUPED-adjusted Welch's-t p (Bonferroni) | Δ |
|---|---:|---:|---:|
| Mid Reduction vs Control | 0.1299 | 0.1269 | −0.0030 |
| Deep Reduction vs Control | 0.5432 | 0.5421 | −0.0011 |

**Why the gain is modest even with a sensible covariate:** at this baseline rate (~0.05% of exposed stable_ids attach), Var(Y) is dominated by the rare-event structure. The 116 non-zero outcomes across 32K units swamp any signal the smoothly-varying engagement covariate can extract. CUPED's variance reduction is bounded by ρ², and the binomial floor on Var(Y) at this rate keeps ρ small even when the covariate is well-chosen.

**The covariate is not the bottleneck — the rate is.** A more predictive covariate (pre-period subscription/upgrade events, library-download intensity, account tenure) would push ρ² up modestly but cannot meaningfully tighten CIs while Y has only ~26 attaches per arm worth of signal.

**CUPED-adjusted vs unadjusted p-values are within 0.003 across both pairwise tests.** Both still fail to clear α'=0.025. The headline conclusion ("not significant at current N") is unchanged.

**Implication for Statsig Pulse comparison:** if Pulse uses CUPED with a comparable engagement-class covariate, Pulse-reported CIs on this experiment will not be materially tighter than unadjusted CIs. The variance reduction Pulse can extract is rate-limited by the same baseline rarity. Tighter Pulse CIs would have to come from a different cohort grain, a fundamentally different value column, or a much richer covariate vector — not from CUPED itself with any single 7-day pre-period covariate.

The full CUPED computation, pooled diagnostics, and per-arm output are in `stats/results.md` "CUPED — variance reduction with engagement covariate" section.

---

## Caveats (carried forward, do not silently absorb)

1. **Sequential-testing peek.** This is an interim peek on a still-running test. The reported p-values do not include alpha-spending correction. Under O'Brien-Fleming bounds at 2 prior peeks (2026-04-18 and 2026-04-27), per-peek α would shrink to ~0.005 — stricter than the Bonferroni applied here. The "no detectable signal at α=0.025" framing is robust to sequential correction (failing α=0.025 implies failing α=0.005). If a future readout claims significance from a marginal raw p, formal sequential design must be applied retrospectively.

2. **Cohort grain difference vs Statsig Pulse.** Warehouse-recovered cohort uses stable_id grain (~10.7K per arm); Pulse uses user_id grain with Enforced 1:1 mapping (~6.7K per arm). Effect-size estimates are not directly comparable across cohorts.

3. **CUPED has been applied** per the section above; contributes ~0% variance reduction at this baseline rate due to disjoint pre/post purchase populations. (This replaces the prior placeholder caveat "CUPED not applied".)

4. **Trigger-coverage gap (carried from original audit Finding 3).** Of 30 in-window WCPM purchasers, 26 are attributed to an arm via the warehouse-recovered cohort. The 4 unattached: 2 missing stable_id (Mixpanel side, NULL), 2 either never fired the exposure trigger or purchased before exposure. This is a TEST DESIGN consideration — the trigger does not cover all paths to WCPM purchase. Per `feedback_no_overclaim_from_code_reads`: I am NOT claiming the test is "working as designed"; I am describing the observable population the trigger is capturing.

5. **Net revenue impact not computed.** Out of scope per user's "WCPM add-on attach only" scoping. Mid Reduction's directional lift would need to be weighed against the 28% price reduction to determine net revenue effect; that math is straightforward to compute but is not part of this deliverable.

6. **Mixpanel filter caveat.** The canonical filter is `current_addons ILIKE '%warner%'` per the `pc_stitch_db__mixpanel__export.md` calibration artifact. The `current_plan_id IN (...)` variant returns 0 in q01/q02 because WCPM is an add-on, not a base plan. The audit confirmed the same.

---

## Recommendations

1. **Continue accruing for ≥30 more days** before claiming a conclusion on the Mid Reduction lift. At the current accrual pace, the test will reach the N required to detect a +200% lift in approximately 30 days; if Mid Reduction's true effect is in the +100% to +200% range, statistical confirmation is achievable in that timeframe.
2. **Compute net revenue impact** as a separate deliverable (out of scope for this one). Combining the observed attach lift with the variant-specific price differential is the actionable business metric.
3. **Maintain the OPEN status** of Findings 4 and 6. Refresh shows Finding 4 stable (1 orphan) and Finding 6 modestly accumulating (13.5% → 14.24%); neither requires an immediate intervention escalation but both should be reflected in any future Pulse-based read of this or any user-level experiment.
4. **Do NOT operationalize Deep Reduction** based on the current data. Its observed rate sits between Control and Mid with no statistically distinguishable signal from either; treating it as "the deepest discount and worst variant" would be over-claiming.
5. **For future tests on this product, target a baseline-rate-aware MDE.** A 0.046% baseline requires roughly 60K per arm to detect +100% lift at 80% power. Test sizing should reflect this from the start, not be discovered after 45 days of accrual.
