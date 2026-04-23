# Pricing-page persona-card funnel — pre vs post

Source: `q3.csv` (d7dev Q3 rerun with corrected step-2 definition after D15).
Windows: pre = Jan 7 – Feb 6 2026 (31d); post = Feb 24 – Apr 23 2026 with 3/5 – 3/25 contamination window excluded (40d).

**Step-2 definition note.** The product team's original table labeled this step "Click View Pricing". The 2/24 deploy added a second persona-flow entry CTA (`Choose a Plan`). To keep the funnel comparable across the deploy boundary, step 2 is defined as `Clicked Element where element IN ('View Pricing', 'Choose a Plan')` on a pricing URL. Pre-window this equals View Pricing alone (Choose a Plan did not exist pre). Post-window it is the union. Labels below read "Enter Persona Flow" to reflect this.

**Avg Time column** — not computed in this pass. The product team's original avg-time values came from their Mixpanel funnel export. A follow-on query on event-timestamp deltas per user per step would reproduce them; flag if you want it.

## Pre-change (Jan 7 – Feb 6 2026)

| Step | Step Conv. | Cumulative Conv. | Avg Time |
|---|---:|---:|---:|
| Pricing Page → Enter Persona Flow | 56.3% | 56.3% | — |
| Enter Persona Flow → Select Persona | 81.8% | 46.1% | — |
| Select Persona → Click Plan | 25.7% | 11.8% | — |
| Click Plan → Subscribe | 27.5% | 3.25% | — |
| **Overall: Pricing → Subscribed** | — | **3.25%** | — |

Raw counts: 15,334 visitors → 8,633 entered flow → 7,065 persona → 1,816 plan → 499 subscribed.

## Post-change (Feb 24 – Apr 23 2026, contamination-excluded)

| Step | Step Conv. | Cumulative Conv. | Avg Time |
|---|---:|---:|---:|
| Pricing Page → Enter Persona Flow | 51.7% | 51.7% | — |
| Enter Persona Flow → Select Persona | 81.3% | 42.0% | — |
| Select Persona → Click Plan | 27.3% | 11.5% | — |
| Click Plan → Subscribe | 35.5% | 4.07% | — |
| **Overall: Pricing → Subscribed** | — | **4.07%** | — |

Raw counts: 18,046 visitors → 9,325 entered flow → 7,585 persona → 2,070 plan → 735 subscribed.

## Pre vs Post delta summary

| Metric | Pre | Post | Δ (pp) | Δ (rel) |
|---|---:|---:|---:|---:|
| Step 2 — Enter Persona Flow | 56.3% | 51.7% | −4.6 | −8.2% |
| Step 3 — Enter Flow → Persona | 81.8% | 81.3% | −0.5 | −0.6% |
| Step 4 — Persona → Plan | 25.7% | 27.3% | +1.6 | +6.1% |
| Step 5 — Plan → Subscribe | 27.5% | 35.5% | **+8.0** | **+29.3%** |
| **Cumulative conversion** | 3.25% | 4.07% | **+0.82** | **+25.3%** |
| Cumulative persona selection | 46.1% | 42.0% | −4.1 | −8.9% |
| Cumulative plan click | 11.8% | 11.5% | −0.3 | −2.8% |

The cumulative conversion lift is driven by step 5 (Plan → Subscribe) at the aggregate level, but the Q8 within-cohort decomposition below shows the aggregate is dominated by visitor-mix drift rather than on-pricing behavior change.

## Within-cohort decomposition (Q8)

Visitors bucketed by `current_plan_id` on their first Viewed Pricing Page event: `anon` = null, `free` = `'free'`, `paid` = any specific plan slug. D18 confirmed these are the only three populations.

### Cohort share of pricing visitors

| Cohort | Pre | Post-8wk-clean | Δpp |
|---|---:|---:|---:|
| anonymous | 74.0% | 65.9% | −8.1 |
| free-account | 23.5% | 32.6% | **+9.1** |
| paid-subscriber | 2.5% | 1.5% | −1.0 |

### Cumulative conversion by cohort

| Cohort | Pre | Post-8wk-clean | Δpp |
|---|---:|---:|---:|
| anonymous | 0.72% | 1.08% | +0.36 |
| free-account | 10.80% | **9.73%** | **−1.07** |
| paid-subscriber | 0.80% | 5.49% | +4.69 (3 → 15 subs, tiny N — unreliable) |
| aggregate | 3.25% | 4.07% | +0.82 |

### Step 5 (Plan → Subscribe) rate by cohort

| Cohort | Pre | Post-8wk-clean | Δpp |
|---|---:|---:|---:|
| anonymous | 7.9% | 11.2% | +3.3 |
| free-account | 53.4% | 64.7% | +11.3 |
| paid-subscriber | 7.3% | 40.5% | +33.2 (tiny N — unreliable) |
| aggregate | 27.5% | 35.5% | +8.0 |

### Composition vs behavior decomposition (integrative, window-level — does not test timing)

- **Counterfactual (pre within-cohort rates × post visitor mix):** 0.668 × 0.72% + 0.329 × 10.80% + 0.015 × 0.80% = **4.04%**
- **Observed post aggregate:** **4.07%**
- **Composition contribution:** +0.79pp of the +0.82pp lift (holding behavior at pre values)
- **Behavior contribution:** +0.03pp of the +0.82pp lift (residual after composition)

**Caveat (D20): this decomposition does not test whether composition's timing aligns with conversion's timing.** See "Weekly timing check" below. The composition-attribution interpretation is unsupported once the weekly series is reviewed.

## Weekly timing check (D19 + D20)

| Week | Aggregate conv rate | Free share | Note |
|---|---:|---:|---|
| 1/5 | 3.28% | 24.9% | pre baseline |
| 1/12 | 3.10% | 21.3% | |
| 1/19 | 3.15% | 24.3% | |
| 1/26 | 3.33% | 25.2% | end of pre window (partial) |
| 2/2 | 4.02% | 25.3% | **conv already at 4% — pre-deploy** |
| 2/9 | 3.57% | 25.5% | |
| 2/16 | 4.05% | 27.3% | pre-deploy |
| 2/23 | 4.38% | 27.9% | contains 2/24 deploy |
| 3/2 | 3.73% | 28.5% | |
| 3/9 | 3.32% | 28.9% | |
| 3/16 | 4.51% | **32.9%** | free-share step change |
| 3/23 | 4.31% | 31.2% | |
| 3/30 | 4.89% | 32.9% | |
| 4/6 | 3.91% | 34.6% | conv drops despite free share holding |
| 4/13 | 3.51% | 34.6% | |

3-week rolling conversion rate: 3.18% (early Jan) → 3.64% → **4.05% (mid-Feb)** → 4.05% (mid-March) → 4.10% (late March – April).

**The conversion rate reached ~4% three weeks BEFORE the 2/24 deploy and six weeks before the 3/16 composition step, and plateaued.** Free share kept rising through April with no corresponding conversion rise after mid-February.

**Neither the banner deploy nor the composition step is supported as the driver.** The +25% pre-vs-post window difference reflects a gradual pre-existing drift that plateaued in mid-February, before any candidate cause tested here. The origin of the January – mid-February drift is not diagnosed by this analysis.
