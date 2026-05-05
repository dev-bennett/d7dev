# WCPM Pricing Test — Significance Results

**Window:** 2026-03-13 → 2026-04-27 (45 days, test still running)  
**Cohort:** warehouse-recovered (raw `_external_statsig.exposures`, stable_id-grain first-exposure)  
**Metric:** WCPM add-on attach rate (Existing-Sub + New-Sub combined, Mixpanel-direct numerator)  
**Significance threshold:** α = 0.05 (Bonferroni-adjusted α' = 0.025 for 2 pairwise tests)

## Per-arm point estimates with Wilson 95% CIs

| Arm | Exposed N | Purchased N | Attach rate | Wilson 95% CI |
|---|---:|---:|---:|---|
| Control | 10,788 | 5 | 0.0463% | [0.0198%, 0.1085%] |
| Mid Reduction | 10,601 | 13 | 0.1226% | [0.0717%, 0.2097%] |
| Deep Reduction | 10,786 | 8 | 0.0742% | [0.0376%, 0.1463%] |

Observed relative lift vs Control: Mid Reduction +164.6% relative; Deep Reduction +60.0% relative.

## Pairwise tests (two-sided)

| Comparison | Δ rate (pp) | Newcombe 95% CI on Δ | z | p (raw) | p (Bonferroni × 2) | Significant at α'=0.025 |
|---|---:|---|---:|---:|---:|---|
| Mid Reduction vs Control | +0.0763pp | [-0.0041pp, +0.1673pp] | +1.924 | 0.0544 | 0.1088 | no |
| Deep Reduction vs Control | +0.0278pp | [-0.0443pp, +0.1047pp] | +0.833 | 0.4051 | 0.8101 | no |

## Omnibus test (3 arms × {purchased, not_purchased})

- **Method:** chi-square
- **Test statistic:** 3.9419
- **p-value:** 0.1393
- **Min expected cell count:** 8.57
- **Conclusion at α=0.05:** fail to reject the null (no arm-level difference in WCPM attach rate)

## Minimum Detectable Effect at current N

- **Control baseline rate:** 0.0463%
- **Average per-arm N:** 10,725
- **Detectable lift (absolute) at α'=0.025, power=0.80:** +0.1349pp (i.e., would need attach rate ≥ 0.1812% in a treatment arm to reliably detect)
- **N per arm required for +50% relative lift (rate 0.0695%):** 202,892
- **N per arm required for +100% relative lift (rate 0.0927%):** 59,724
- **N per arm required for +200% relative lift (rate 0.1390%):** 19,117
- **Current N per arm (~10,725)** is **5.3%** of the N needed for a +50% lift, **18.0%** of the N needed for a +100% lift, **56.1%** of the N needed for a +200% lift.

## CUPED — variance reduction with engagement covariate

CUPED applied to the **sum metric** (WCPM add-on event count per exposed stable_id) with a sensible **engagement covariate**: X = total `fct_events` count per cohort stable_id in [first_exposure - 7 days, first_exposure). Engagement is the right covariate class for a near-zero-baseline conversion metric — it is well-populated (99.3% of cohort), has high variance (mean 75-77 events/unit), and proxies for purchase propensity. Using the same-metric pre-period (WCPM purchases) as the covariate would be degenerate: pre-period and post-period attachers are disjoint populations on this rare-event metric, so Cov(X, Y) collapses to 0. (See methodology.md for the covariate-choice rationale.)

### Pooled diagnostics

- **Pooled N:** 32,175
- **Pooled mean(Y) (post-period events/unit):** 0.003605
- **Pooled mean(X) (pre-period events/unit):** 76.403823
- **Pooled Var(Y):** 1.733020e-02
- **Pooled Var(X):** 2.391120e+04
- **Pooled Cov(X, Y):** 1.717585e-01
- **θ (CUPED coefficient):** 0.000007
- **ρ² (squared correlation between X and Y):** 7.119203e-05
- **Variance reduction factor (1 - ρ²):** 0.999929  →  effective variance reduction of 0.0071%.

### Per-arm CUPED-adjusted means

| Arm | n | unadj mean Y | adj mean Y_cuped | unadj SE | CUPED SE | SE shrinkage |
|---|---:|---:|---:|---:|---:|---:|
| Control | 10,788 | 0.001947 | 0.001940 | 0.000884 | 0.000884 | +0.0366% |
| Mid Reduction | 10,601 | 0.005188 | 0.005200 | 0.001517 | 0.001517 | -0.0051% |
| Deep Reduction | 10,786 | 0.003709 | 0.003704 | 0.001337 | 0.001337 | -0.0000% |

### CUPED-adjusted pairwise tests (Welch's t-test, two-sided)

| Comparison | Δ adj mean | 95% CI on Δ | t | df | p (raw) | p (Bonferroni × 2) | Significant at α'=0.025 |
|---|---:|---|---:|---:|---:|---:|---|
| Mid Reduction vs Control | +0.003259 | [-0.000183, +0.006701] | +1.856 | 17079.8 | 0.0635 | 0.1269 | no |
| Deep Reduction vs Control | +0.001764 | [-0.001377, +0.004905] | +1.101 | 18701.8 | 0.2711 | 0.5421 | no |

### Side-by-side: Unadjusted vs CUPED on the sum metric

| Comparison | Unadj p (Bonferroni) | CUPED p (Bonferroni) | Δ p |
|---|---:|---:|---:|
| Mid Reduction vs Control | 0.1299 | 0.1269 | -0.0029 |
| Deep Reduction vs Control | 0.5432 | 0.5421 | -0.0011 |

### CUPED interpretation

- ρ² = 7.12e-05, **variance reduction = 0.0071%**. Detectable but small.
- **Why the gain is modest:** at this baseline rate (~0.05% of exposed stable_ids attach), Var(Y) is dominated by the rare-event structure — the 116 non-zero outcomes dwarf any signal from the smoothly-varying engagement covariate. CUPED can only reduce variance up to (1 - ρ²), and the binomial floor on Var(Y) at this rate gives ρ small even with a sensible covariate.
- **The covariate is not the bottleneck — the rate is.** A more predictive covariate (e.g., pre-period subscription/upgrade events, library download intensity, account tenure) would push ρ² up modestly but cannot meaningfully tighten CIs while Y has only ~26 attaches per arm worth of signal.
- **CUPED-adjusted vs unadjusted p-values are within 0.003 across both pairwise tests.** Both still fail to clear α'=0.025. The headline conclusion ('not significant at current N') is unchanged.
- **Implication for Statsig Pulse comparison:** Pulse-reported CIs on this experiment will not be materially tighter than unadjusted CIs unless Pulse uses a substantially different covariate. The variance reduction Pulse can extract via CUPED is rate-limited by the same baseline rarity.

## Caveats

1. **Sequential-testing peek.** The test is still running. This is an interim peek; reported p-values do not include alpha-spending correction. Under O'Brien-Fleming bounds at 2 peeks, per-peek α would shrink to ~0.005 — a stricter threshold than Bonferroni applied here. The 'no detectable signal' framing is robust to sequential correction (failing α=0.025 implies failing α=0.005).

2. **Cohort grain difference vs Statsig Pulse.** This analysis uses stable_id grain (warehouse-recovered cohort). Statsig Pulse uses user_id grain with Enforced 1:1 mapping (drops ~14.24% post-refresh, per q13). Arm sizes differ: warehouse-recovered ~10.7K per arm; Pulse ~6.7K per arm. Effect sizes computed here are not directly comparable to Pulse's reported effect sizes.

3. **Finding 4 (clickstream model late-arrival drop).** q12 confirms 1 event dropped from the Statsig clickstream model in this window — appears in q10's Existing/New split numerator, not in q09's Mixpanel-direct numerator. The headline q09 numbers are Finding-4-clean.

4. **Trigger-coverage gap (carried from original audit Finding 3).** Of 30 in-window WCPM purchasers (Mixpanel), 26 are attributed to an arm via the warehouse-recovered cohort. The 4 unattached are either missing stable_id (2) or never fired the exposure trigger (2). This is a TEST DESIGN issue, not a data issue. The denominator may not capture every user who could have responded to the variant.
