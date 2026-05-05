# Methodology — WCPM Pricing-Test Significance Read-out

This document is authored BEFORE any SQL or stats execution per `.claude/rules/sql-snowflake.md` (§1) and `.claude/rules/analysis-methodology.md` (§12). It declares rate metrics, cohort definitions, statistical methodology, and verification gates. Once queries execute, the TYPE AUDIT and Step Nesting Audit (where applicable) sections are filled in inline; nothing is added without an explicit audit.

---

## §1 — Rate Declarations

### RATE: wcpm_addon_attach_rate

```
RATE: wcpm_addon_attach_rate (per arm)
NUMERATOR: distinct stable_ids in the warehouse-recovered cohort whose user_id (resolved via fct_events) appears as a `Purchased Add-on` purchaser (filter: properties.add_on_id ∈ {warner-chappell-production-music-monthly-usd, warner-chappell-production-music-yearly-usd}) within the window 2026-03-13 → 2026-04-27, AND whose first_exposure_ts to wcpm_pricing_test in the cohort precedes the purchase event_ts
DENOMINATOR: distinct stable_ids in the warehouse-recovered cohort assigned to the arm (one stable_id contributes once, to the arm of its earliest exposure)
TYPE: addon_purchasers / first_exposure_units
NOT: distinct user_ids — Pulse already does that and drops ~13.5% via Enforced 1:1 mapping. NOT raw `_external_statsig.exposures` rowcount — that includes re-exposures and over-counts. NOT distinct distinct_ids — Mixpanel-side identity, not exposure-side identity.
```

### RATE: wcpm_addon_attach_rate_existing_sub

```
RATE: wcpm_addon_attach_rate_existing_sub (per arm)
NUMERATOR: distinct stable_ids in cohort + Purchased Add-on event with `current_addons` matching WCPM AND `current_plan_id` non-null at event time (i.e., user already had a paid subscription pre-purchase)
DENOMINATOR: distinct stable_ids in the warehouse-recovered cohort assigned to the arm
TYPE: existing_sub_addon_purchasers / first_exposure_units
NOT: total purchasers — must split by sub-state at time of add-on event, matching Statsig's `ADD_ON_PURCHASE_EXISTING_SUB` value column
```

### RATE: wcpm_addon_attach_rate_new_sub

```
RATE: wcpm_addon_attach_rate_new_sub (per arm)
NUMERATOR: distinct stable_ids in cohort + Purchased Add-on event where the user did NOT have a paid plan immediately prior to the add-on purchase (matches Statsig's `ADD_ON_PURCHASE_NEW_SUB`)
DENOMINATOR: distinct stable_ids in the warehouse-recovered cohort assigned to the arm
TYPE: new_sub_addon_purchasers / first_exposure_units
NOT: total purchasers — must split by sub-state at time of add-on event
```

### Type Audits (executed 2026-04-27)

```
TYPE AUDIT — q09 (per-arm attach, WCPM headline):
  Declared denominator: warehouse-recovered cohort, per-arm distinct stable_ids
  JOIN chain: cohort (CTE) LEFT JOIN mp_wcpm_purchasers (CTE) ON c.stable_id = p.mp_stable_id
  Column used as denominator in calculation: COUNT(DISTINCT c.stable_id) — c is the cohort CTE
  Does JOIN type enforce declared denominator? YES. The LEFT JOIN preserves every cohort stable_id regardless of whether a matching purchase exists; numerator is gated on `p.mp_stable_id IS NOT NULL AND c.first_exposure_ts <= p.first_purchase_ts`, so unmatched cohort rows count toward the denominator but not the numerator. The intent ("of the cohort exposed to arm X, what fraction attached the WCPM add-on?") is preserved.
  RESULT: PASS

TYPE AUDIT — q10 (Existing-Sub vs New-Sub split):
  Declared denominator: warehouse-recovered cohort, per-arm distinct stable_ids (same denominator as q09 — Existing/New is a numerator-only split, sourced from Statsig clickstream model's two value columns)
  JOIN chain: cohort (CTE) LEFT JOIN statsig_addon_rows (CTE) ON c.stable_id = sa.statsig_stable_id
  Column used as denominator in calculation: COUNT(DISTINCT c.stable_id)
  Does JOIN type enforce declared denominator? YES. LEFT JOIN preserves cohort; numerator gated on Statsig-flag CASE expressions.
  CAVEAT: The numerator is sourced from `_external_statsig.statsig_clickstream_events_etl_output`, which is subject to Finding 4 (late-arrival drop). q12 isolates the magnitude (1 event dropped in window). q09's Mixpanel-direct numerator is Finding-4-clean; q10's split is not. Sum of q10 numerators (5 + 7 + 13 = 25) is 1 less than q09's combined attach (5 + 8 + 13 = 26). The 1-event delta lands in the Deep Reduction arm (q09 deep_n=8 vs q10 existing+new sum = 0+7 = 7).
  RESULT: PASS (with Finding-4 caveat documented)
```

Step Nesting Audit: not applicable. q09/q10 are not funnel step-rates.

### Verification spot-checks executed 2026-04-27

- q05 (raw exposures) per-arm vs q07 (warehouse-recovered cohort) per-arm: identical (10,788 / 10,786 / 10,601). Confirms `ROW_NUMBER() OVER (PARTITION BY stable_id)` rn=1 dedup matches `COUNT(DISTINCT stable_id)` because no stable_id is multi-arm at the stable_id grain. q11 confirms 0 multi-arm stable_ids.
- q05 (warehouse-recovered, stable_id grain, 32,175 total) vs q06 (Pulse cohort, user_id grain, 20,124 total): the ratio (62.5%) reflects identity-grain difference, not Finding-6 13.5% drop alone. Finding-6 magnitude isolated via q13b: 3,152 of 22,136 logged-in user_ids carry multi-arm exposures = 14.24% (drift from 13.5% at audit; trending up modestly).
- q01/q02 stakeholder-benchmark cross-check vs 2026-04-18 audit: Mixpanel WCPM purchasers grew 27 → 30 (+3 net new in 9 days). All counts grew monotonically. PASS.
- q04 Statsig clickstream model count: 12 → 29 (+17). PASS (monotonic).
- Per-arm sanity (q09): purchased_n / exposed_n × 100 = attach_rate_pct to 4 decimals (5/10788 = 0.0463%, 13/10601 = 0.1226%, 8/10786 = 0.0742%). MATCHES.
- q10 vs q09 reconciliation: q09 total attached = 26; q10 total attached = 25; delta = 1 = Finding 4 magnitude. q12 confirms exactly 1 finding4_orphan in window. RECONCILED.

---

## §12 — Definition–Use Case Alignment (Warehouse-Recovered Cohort)

```
ALIGNMENT CHECK — warehouse-recovered cohort:
  INTERVENTION: differential pricing variant served at Chargebee checkout for users exposed to wcpm_pricing_test
  TEMPORAL MECHANIC OF INTERVENTION: event-driven (fires once when checkout flow renders the variant-specific price; the user either acts on it or not within their session/visit)
  TEMPORAL MECHANIC OF DEFINITION: event-based (first-exposure timestamp at stable_id grain — one row per (stable_id, first_arm, first_exposure_ts))
  MATCH: YES — both event-driven; first-exposure captures the population that *could* have observed the variant pricing
  SIZING SANITY: at 2026-04-18 the audit found ~6,115 / ~5,972 / ~6,137 stable_ids per arm via raw exposures (q9d), and Pulse's first_exposures table reported the same totals (q11c). Refresh expectation: arm sizes grow monotonically as the test continues. Pulse-cohort N (by user_id) will be ~13.5% smaller than the warehouse-recovered N (by stable_id) per Finding 6 — both numbers should be reported and compared.
```

### Tie-break rule for multi-arm stable_ids

A small number of `stable_id`s appear in multiple arms within the raw `_external_statsig.exposures` table. This happens when a single browser/cookie identity is reassigned across SDK init events (uncommon at the stable_id grain — sprawl mostly manifests at user_id ↔ stable_id, not within a single stable_id). For these:

- Tie-break: **earliest exposure timestamp wins** (the arm a user was first exposed to determines their cohort assignment, regardless of any later exposures to other arms).
- Rationale: matches the intervention's event-driven temporal mechanic — the first-rendered price is the price that could have driven action. Subsequent exposures to other arms are post-hoc contamination; they should not retroactively reassign the cohort.
- Sensitivity check: q11 quantifies the multi-arm-stable_id population. If ≥1% of any arm is multi-arm, document the rate; if a single arm is materially over-represented in multi-arm IDs, flag as a potential cohort imbalance.

### Why not use Pulse's 1:1-filtered cohort instead

Pulse drops `user_id`s that resolve to multiple `stable_id`s when those `stable_id`s span multiple arms. Per `project_wcpm_1to1_mapping_exclusion.md`, this affects ~13.5% of logged-in exposed users (2,709 of 20,072 at 2026-04-18). Domain consolidation (March 2026, www+app → soundstripe.com via Fastly) is the documented upstream cause of the `stable_id` sprawl. The warehouse-recovered cohort sidesteps this filter by using `stable_id` as the unit of analysis — each `stable_id` is one cookie/SDK identity and naturally first-exposed to one arm.

Trade-offs of the warehouse-recovered choice (disclosed for stakeholders):
- (+) Recovers ~13.5% of exposed units that Pulse drops
- (+) Numbers reflect the full exposed population, not a 1:1-filtered subset
- (−) A single human user with multiple `stable_id`s contributes once per `stable_id`, potentially in different arms — overcounts the unique-human exposure
- (−) Diverges from Statsig Pulse by design; downstream readouts cannot be cross-checked 1:1 against Pulse
- Mitigation: report q06 (Pulse-cohort N) alongside q05 (warehouse-recovered N) so the gap is visible

---

## Statistical Methodology

### Question

For the WCPM add-on attach metric, do the Mid Reduction or Deep Reduction arms produce a detectably different attach rate than the Control arm at α=0.05 (per-comparison, before correction)?

### Hypotheses

For each arm comparison (Mid vs Control, Deep vs Control), the null and alternative:

- H₀: π_arm = π_control (equal attach rates)
- H₁: π_arm ≠ π_control (two-sided)

Two-sided is the right choice — a price reduction could plausibly DEcrease attach (e.g., signaling lower-quality content) or increase it. We do not pre-commit to a direction.

### Per-arm point estimate + interval

- Point estimate: p̂_arm = purchased_n / exposed_n
- Interval: **Wilson score 95% CI** via `statsmodels.stats.proportion.proportion_confint(method='wilson')`. Wilson is preferred over normal-approximation (Wald) for small p̂ — exactly the regime here, where p̂ ≈ 0.0007.

### Pairwise tests

Two pairwise tests, one per non-control arm:

1. **Mid Reduction vs Control:** two-proportion z-test (`statsmodels.stats.proportion.proportions_ztest`, alternative='two-sided'). Returns z statistic + raw p-value.
2. **Deep Reduction vs Control:** same.

For each pairwise test, also compute the **Newcombe hybrid score 95% CI** on the rate difference (`statsmodels.stats.proportion.confint_proportions_2indep(method='newcomb')`). Newcombe handles small samples and skewed proportions better than the Wald rate-difference CI.

### Multiple-comparison correction

Bonferroni adjustment for 2 pairwise comparisons: report Bonferroni-adjusted p (p_raw × 2, capped at 1.0) and use α' = 0.025 as the per-comparison threshold for declaring significance. Holm-Bonferroni would be slightly more powerful but adds interpretability cost; given only 2 comparisons, the gain is minimal.

### Omnibus test (3-way)

**Fisher's exact test** on the 3×2 contingency table (3 arms × {purchased, not_purchased}). Use `scipy.stats.fisher_exact` for 2×2 pairwise + a Monte-Carlo simulation for the 3×2 omnibus (`scipy.stats.contingency.crosstab` does not provide omnibus directly; use `scipy.stats.chi2_contingency(..., lambda_='log-likelihood')` G-test as the parametric alternative IF expected cell counts ≥ 5; otherwise fall back to a simulated permutation null via `numpy.random` shuffle of the arm assignment).

Decision rule: at current N, expected cell counts for "purchased" are ~12 / 3 ≈ 4 per arm — **below the chi-square validity threshold of 5**. Default to **simulated Fisher's exact** (resample arm assignment 10,000 times under the null; report the proportion of resamples with a more extreme test statistic).

### Minimum Detectable Effect (MDE)

At α=0.025 (Bonferroni-adjusted) and power=0.80, compute the smallest absolute difference in attach rate (Δp) detectable at the current per-arm N, treating Control as the baseline. Use `statsmodels.stats.power.NormalIndPower.solve_power` with `effect_size = (p1 - p2) / sqrt(p_avg × (1 - p_avg))` (Cohen's h approximation for proportions, computed iteratively).

Headline phrasing: "At current N (≈ 6K per arm) and a Control attach rate of X%, the smallest pairwise effect detectable at 80% power is Δ_MDE = Y pp. Detecting a 50% relative lift (e.g., 0.1% → 0.15% attach) requires N ≈ Z per arm."

### Sequential-testing peek

The test is still running (started 2026-03-13, no end date). This refresh is an interim peek. Naive p-values from interim looks inflate type-I error if the analyst pre-commits to "stop on significance." Two disclosures:

1. **The numerical caveat:** if the test was previewed at 2026-04-18 and again at 2026-04-27 with no formal alpha-spending plan, the cumulative type-I error rate at α=0.025 per peek is bounded above by 0.05 over 2 peeks (worst case, both independent — true rate is lower because the two peeks are correlated). For a strict interpretation, an O'Brien-Fleming bound would shrink the per-peek α to ~0.005 — much harder to clear.
2. **The pragmatic caveat:** the headline "no detectable signal" framing does NOT depend on the peek correction. Failing to clear α=0.025 at this N implies failing to clear any reasonable sequential-test threshold as well. The peek warning matters only if a future readout claims significance from a marginal p — at which point a formal sequential design is needed retrospectively.

### CUPED / variance reduction (applied 2026-04-27)

CUPED applied to the sum-metric formulation (events per exposed stable_id) with a pre-period engagement covariate.

**Covariate choice — engagement, NOT same-metric.** Statsig's stock CUPED specification is "same metric, 7-day pre-period." For a near-zero-baseline conversion metric like WCPM add-on attach, that specification is degenerate by construction: pre-period attachers and post-period attachers are disjoint populations (a user who attached pre-period stays attached and won't fire a NEW attach event post-period), which forces Cov(X, Y) ≈ 0 and gives ρ² ≈ 0 regardless of N. Confirmed empirically on this data: with WCPM purchases as the covariate, ρ² = 4.06 × 10⁻⁸.

The right covariate class for a rare-event conversion metric is a pre-period **engagement signal** that correlates with purchase propensity:
- X = total `core.fct_events` count per cohort stable_id in [first_exposure - 7 days, first_exposure)
- Coverage: 99.3% of cohort stable_ids have non-zero pre-period activity
- Mean X across cohort: 75-77 events/unit; sufficient variance to make Cov(X, Y) measurable
- Computed by `q15` in `console.sql`; sufficient statistics piped to `stats/input_cuped_per_arm.csv`

**Math (CUPED with sufficient statistics):**

For each arm a:
- mean_y_a = sum_y_a / n_a
- mean_x_a = sum_x_a / n_a
- var_y_a = (sum_y2_a − n_a × mean_y_a²) / (n_a − 1)
- var_x_a = (sum_x2_a − n_a × mean_x_a²) / (n_a − 1)
- cov_xy_a = (sum_xy_a − n_a × mean_x_a × mean_y_a) / (n_a − 1)

Pooled across arms:
- θ = Cov(X, Y)_pooled / Var(X)_pooled
- ρ² = Cov(X, Y)_pooled² / (Var(X)_pooled × Var(Y)_pooled)
- variance_reduction_factor = 1 − ρ²

Per-arm CUPED-adjusted moments:
- mean_y_cuped_a = mean_y_a − θ × (mean_x_a − mean_x_pooled)
- var_y_cuped_a = var_y_a − 2θ × cov_xy_a + θ² × var_x_a

Pairwise tests on adjusted means: Welch's t-test using SE = sqrt(var_y_cuped_a / n_a + var_y_cuped_b / n_b); Welch-Satterthwaite df.

**Result on this data:** ρ² = 7.12 × 10⁻⁵, variance reduction 0.0071%. Mid-vs-Control Bonferroni p moves from 0.1299 (unadjusted) to 0.1269 (CUPED). Both still fail to clear α'=0.025. The covariate is sensible; the bottleneck is Y's binomial-floor variance at this baseline rate.

Reported in detail in `stats/results.md` "CUPED — variance reduction with engagement covariate" section and in `findings.md` "CUPED variance-reduction read".

---

## Cohort vs. Population Caveats

### Finding 4 — late-arrival drop (symmetric, small)

The dbt model `_external_statsig.statsig_clickstream_events_etl_output` drops `fct_events` rows that arrive after the model's incremental watermark advances past their `event_ts::date`. Documented in `project_statsig_model_late_arrival_open.md`.

- This refresh queries `core.fct_events` directly for purchase events (q08), bypassing the Statsig clickstream model — so the **outcome side is NOT subject to Finding 4**.
- The exposure side is from `_external_statsig.exposures` (raw, not the clickstream model) — also not subject to Finding 4.
- q12 sizes the historical impact of Finding 4 on the audit window (one event in the original 2026-04-18 audit). Refresh expectation: same order of magnitude (single events, not a population-level bias).

### Finding 6 — 1:1 mapping (sidestepped by cohort choice)

Sidestepped in this analysis by using `stable_id` as the cohort grain. q13 quantifies the global multi-stable_id rate as a sanity check on the magnitude documented in `project_wcpm_1to1_mapping_exclusion.md` (was 2,709 / 20,072 = 13.5% at 2026-04-18).

### Trigger-coverage gap (Finding 3 from original audit, design issue)

Carried forward as a caveat. The original audit found 8 of 23 in-window WCPM purchasers never fired the exposure trigger. This is a TEST DESIGN issue (the trigger does not cover all paths to WCPM purchase), not a data issue. The refreshed analysis cannot fix this; it can only re-quantify the gap (q14 reconciliation table).

---

## Verification Gates

Before declaring queries complete:

- [ ] `q05` (raw exposures arm sizes) and `q06` (first_exposures Pulse-cohort arm sizes) both refreshed; `q06 ≈ 0.865 × q05` per Finding 6 (verify within ±2pp drift)
- [ ] `q01` (Mixpanel total) > 27 (test has been running, more purchases expected); if not, investigate
- [ ] `q04` (Statsig clickstream model count) > 12; if not, Finding 4 has accumulated
- [ ] `q14` reconciliation table arithmetic balances (Mixpanel total = Statsig model + late-arrival drops + pre-window weekly-bucket overflow + ...)
- [ ] q09 Type Audit PASS
- [ ] q10 Type Audit PASS
- [ ] Spot-check: pick one purchaser stable_id from q09 export; manually trace `_external_statsig.exposures` first-exposure → `core.fct_events` purchase → Mixpanel raw event; confirm the attribution math (`first_exposure_ts ≤ event_ts`)

Before declaring stats script complete:

- [ ] Per-arm sanity: `purchased_n / exposed_n == attach_rate` to 6 decimals
- [ ] Wilson 95% CI bounds in [0, 1]
- [ ] Newcombe rate-difference CI brackets the point estimate of `p_arm - p_control`
- [ ] Bonferroni-adjusted p capped at 1.0
- [ ] MDE > attach-rate-difference observed (consistent with "underpowered" framing)
- [ ] Chart renders with legend OUTSIDE plot area, axis labels readable, no clipping (per `feedback_chart_standards`)
