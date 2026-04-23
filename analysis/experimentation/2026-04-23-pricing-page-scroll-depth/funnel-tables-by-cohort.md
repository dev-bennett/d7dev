# Pricing-page persona-card funnel — by plan_bucket cohort

Sibling to `funnel-tables.md`. Splits the 5-step funnel by visitor cohort — `anon` (`current_plan_id` null), `free` (`current_plan_id = 'free'`), `paid` (specific plan slug). Cohort is assigned at the user's first Viewed Pricing Page event in window.

Sources: Q3, Q8 (steps 1–4 counts), Q9 (step-5 correctly attributed as plan-click → subscribe within 7d of the click).

**Step 5 definitions used below:**
- `step_rate`: plan-click → subscribe within 7d of the plan click (Q9, properly attributed)
- `plan_click_cum`: (users who clicked plan AND subscribed within 7d of click) / visitors
- `all_sub_cum`: (users who viewed pricing AND subscribed within 7d of that view, regardless of plan click) / visitors — matches the product team's cumulative conversion methodology but is NOT the product of step rates

Windows: pre = Jan 7 – Feb 6 2026 (31d); post-8wk-clean = Feb 24 – Apr 23 2026 with 3/5 – 3/25 excluded (40d).

---

## Anonymous cohort (`current_plan_id = null`)

### Pre

| Step | N | Step Conv. | Cumulative Conv. |
|---|---:|---:|---:|
| Pricing Page → Enter Persona Flow | 6,433 | 56.7% | 56.7% |
| Enter Persona Flow → Select Persona | 5,125 | 79.7% | 45.2% |
| Select Persona → Click Plan | 1,040 | 20.3% | 9.2% |
| Click Plan → Subscribe (Q9, plan-click attributed) | 66 | 6.3% | 0.58% |
| All-subscriber cumulative (Q8, any sub within 7d of view) | 82 | — | 0.72% |

### Post-8wk-clean

| Step | N | Step Conv. | Cumulative Conv. |
|---|---:|---:|---:|
| Pricing Page → Enter Persona Flow | 6,420 | 53.9% | 53.9% |
| Enter Persona Flow → Select Persona | 5,020 | 78.2% | 42.2% |
| Select Persona → Click Plan | 1,147 | 22.8% | 9.6% |
| Click Plan → Subscribe | 96 | 8.4% | 0.81% |
| All-subscriber cumulative | 128 | — | 1.08% |

### Deltas

| Metric | Pre | Post | Δpp |
|---|---:|---:|---:|
| Enter Persona Flow rate | 56.7% | 53.9% | −2.8 |
| Flow → Persona step | 79.7% | 78.2% | −1.5 |
| Persona → Plan step | 20.3% | 22.8% | +2.5 |
| Plan → Subscribe step (Q9) | 6.3% | 8.4% | +2.1 |
| Plan-click cumulative | 0.58% | 0.81% | +0.23 |
| All-subscriber cumulative | 0.72% | 1.08% | +0.36 |

Anonymous cohort: small gains at lower funnel steps, small cumulative rise. Step-5 rate lifted modestly; top-of-funnel engagement weakened slightly.

---

## Free-account cohort (`current_plan_id = 'free'`)

### Pre

| Step | N | Step Conv. | Cumulative Conv. |
|---|---:|---:|---:|
| Pricing Page → Enter Persona Flow | 2,039 | 56.5% | 56.5% |
| Enter Persona Flow → Select Persona | 1,831 | 89.8% | 50.7% |
| Select Persona → Click Plan | 730 | 39.9% | 20.2% |
| Click Plan → Subscribe (Q9) | 294 | 40.3% | 8.14% |
| All-subscriber cumulative | 390 | — | 10.80% |

### Post-8wk-clean

| Step | N | Step Conv. | Cumulative Conv. |
|---|---:|---:|---:|
| Pricing Page → Enter Persona Flow | 2,768 | 47.2% | 47.2% |
| Enter Persona Flow → Select Persona | 2,466 | 89.1% | 42.0% |
| Select Persona → Click Plan | 882 | 35.8% | 15.0% |
| Click Plan → Subscribe | 436 | 49.4% | 7.43% |
| All-subscriber cumulative | 571 | — | 9.73% |

### Deltas

| Metric | Pre | Post | Δpp |
|---|---:|---:|---:|
| Enter Persona Flow rate | 56.5% | 47.2% | **−9.3** |
| Flow → Persona step | 89.8% | 89.1% | −0.7 |
| Persona → Plan step | 39.9% | 35.8% | −4.1 |
| Plan → Subscribe step (Q9) | 40.3% | 49.4% | **+9.1** |
| Plan-click cumulative | 8.14% | 7.43% | **−0.71** |
| All-subscriber cumulative | 10.80% | 9.73% | **−1.07** |

Free cohort: largest top-of-funnel drop (Enter Flow −9.3pp) and modest Persona→Plan decline (−4.1pp). Plan→Subscribe step rate lifted materially (+9.1pp), but the top-of-funnel dilution dominates, so both cumulative measures fell. Free users appear more abundant at pricing but less likely to complete the full click→subscribe path per visitor.

---

## Paid-subscriber cohort (`current_plan_id` = specific paid plan slug)

**N-caveat:** tiny sample (377 visitors pre, 273 post; 4 and 10 subscribers). Per-step rates are highly unstable. Directional only.

### Pre

| Step | N | Step Conv. | Cumulative Conv. |
|---|---:|---:|---:|
| Pricing Page → Enter Persona Flow | 143 | 37.9% | 37.9% |
| Enter Persona Flow → Select Persona | 93 | 65.0% | 24.7% |
| Select Persona → Click Plan | 41 | 44.1% | 10.9% |
| Click Plan → Subscribe (Q9) | 4 | 9.8% | 1.06% |
| All-subscriber cumulative | 3 | — | 0.80% |

### Post-8wk-clean

| Step | N | Step Conv. | Cumulative Conv. |
|---|---:|---:|---:|
| Pricing Page → Enter Persona Flow | 116 | 42.5% | 42.5% |
| Enter Persona Flow → Select Persona | 81 | 69.8% | 29.7% |
| Select Persona → Click Plan | 37 | 45.7% | 13.6% |
| Click Plan → Subscribe | 10 | 27.0% | 3.66% |
| All-subscriber cumulative | 15 | — | 5.49% |

### Deltas (noise-dominated)

| Metric | Pre | Post | Δpp |
|---|---:|---:|---:|
| Enter Persona Flow rate | 37.9% | 42.5% | +4.6 |
| Flow → Persona step | 65.0% | 69.8% | +4.8 |
| Persona → Plan step | 44.1% | 45.7% | +1.6 |
| Plan → Subscribe step (Q9) | 9.8% | 27.0% | +17.2 (4→10 subs) |
| All-subscriber cumulative | 0.80% | 5.49% | +4.69 (3→15 subs) |

Paid cohort: all movements are on double-digit subscriber counts. Do not frame as signal.

---

## Volume vs rate decomposition of the aggregate subscriber-count lift

Rates alone do not show where the absolute subscriber growth came from. Decomposing the +178 plan-click-attributed subscriber delta (Q9 totals 364 → 542) into volume and rate contributions per cohort:

| Cohort | Δ visitors | Pre plan-click cum rate | Volume effect (Δvisitors × pre-rate) | Post visitors | Δ plan-click cum rate | Rate effect (post-visitors × Δrate) | Net Δ subs |
|---|---:|---:|---:|---:|---:|---:|---:|
| anon | +559 | 0.58% | +3 | 11,905 | +0.23pp | +27 | **+30** |
| free | **+2,257** | 8.14% | **+184** | 5,868 | −0.71pp | −42 | **+142** |
| paid | −104 | 1.06% | −1 | 273 | +2.60pp | +7 | **+6** (noise) |
| **total** | +2,712 | — | **+186 (≈105%)** | — | — | **−8 (≈−5%)** | **+178** |

**Arithmetically the aggregate subscriber-count growth is a free-cohort "volume" story:** +2,257 more free visitors at their pre-rate of 8.14% predicts +184 additional plan-click subs, which is 103% of the +178 aggregate lift. Within-cohort rate movements net to approximately zero (free rate drag offsets anon rate gain). The same pattern holds when using the all-subscriber cumulative numerator (Q8): +239 aggregate sub delta → +244 free volume, −63 free rate, +43 anon rate, +4 anon volume, +12 paid. Free volume alone accounts for ~102% of that lift.

**Mechanism caveat — undiagnosed (matches finding #7 in `findings.md`).** The "+2,257 free-cohort visitor growth" is a measured count. It could reflect:
- (A) Actual additional free-account traffic routed to pricing (e.g., dashboard CTAs, redirects from the old app subdomain that preserve auth state on the new `library/pricing` URL, marketing campaigns to free users).
- (B) Improved identity reconciliation under domain consolidation. Pre-consolidation, a logged-in free user hitting pricing from `www` (or any cross-subdomain route) may have had `current_plan_id` unset at that event and been counted as anonymous. Post-consolidation, authenticated state travels cleanly to `library/pricing`, and the same underlying population is now classified as free. Under (B), the pre-baseline was biased by under-identification and the pre-vs-post visitor-mix shift is partly a measurement correction rather than traffic growth.
- (C) Some combination.

D19 timing shows the free-share step change in the week of 3/16, aligned with domain-consolidation rollout stabilizing — consistent with either mechanism. Under (A), this is a routing story. Under (B), this is an identity-reconciliation story. Both lead to the same arithmetic decomposition above; they imply very different interpretations of whether pricing-page behavior changed. Distinguishing them requires engineering input on how the Mixpanel identity SDK was configured cross-subdomain pre vs post.

---

## Cross-cohort observations

1. **The corrected step-5 rate (Q9) still separates sharply by cohort.** Free users convert on plan-click at ~40–50%; anonymous at ~6–8%; paid are noise. The high free rate is plausible — they are already authenticated, evaluating upgrades with payment friction largely removed.

2. **Within-cohort step-5 rates all rose post-window** (free +9.1pp, anon +2.1pp, paid +17.2pp on tiny N). This is real behavior-level movement at the click-to-subscribe step, not composition. What caused it is not diagnosed here; candidates include checkout-page changes, Chargebee setup changes, or a reduction in post-click friction bundled in the 2/24 or domain-consolidation deploys. Timing within the post window (does step-5 lift at 2/24, 3/16, or elsewhere?) is not tested; requires weekly per-cohort step-5 query.

3. **Free cohort all-subscriber cumulative conversion fell 10.80% → 9.73%.** The highest-converting cohort's own conversion got worse over the pre-vs-post window comparison despite the step-5 improvement. Free-cohort top-of-funnel (Enter Persona Flow rate) dropped 9.3pp, which dominates the step-5 gain.

4. **Anon cohort cumulative rose from 0.72% to 1.08%** — meaningful in relative terms (+50%) but still small absolute.

5. **Aggregate reporting masks cohort-level direction mismatch.** The +0.82pp aggregate cumulative lift combines an anon lift with a free decline and a paid noise term. Any framing that presents the aggregate as "conversion went up" should carry the caveat that free-cohort conversion actually went down.

6. **D20 timing caveat still applies to the aggregate.** The aggregate conversion rate reached ~4% by mid-February (pre-deploy) and plateaued — so even the mix of per-cohort movements here does not cleanly tie to the 2/24 deploy. Per-cohort weekly series would settle whether within-cohort step-5 lift aligns to any specific date.
