# Pricing-page persona-card funnel — pre vs post (aggregate)

Source: `q3.csv` for steps 1–4 counts; `q9.csv` for corrected plan-click → subscribe attribution. See `funnel-tables-by-cohort.md` for the same funnel split by `anon` / `free` / `paid`.

Windows: pre = Jan 7 – Feb 6 2026 (31d); post = Feb 24 – Apr 23 2026 with 3/5 – 3/25 contamination window excluded (40d).

**Step-2 definition note.** The product team's original table labeled this step "Click View Pricing". The 2/24 deploy added a second persona-flow entry CTA (`Choose a Plan`). To keep the funnel comparable across the deploy boundary, step 2 is defined as `Clicked Element where element IN ('View Pricing', 'Choose a Plan')` on a pricing URL. Pre-window this equals View Pricing alone (Choose a Plan did not exist pre). Post-window it is the union. Labels below read "Enter Persona Flow" to reflect this.

**Step-5 definition note — Q9 correction applied.** An earlier version of this document reported step 5 as Q3's `subscribers / plan_clickers` ratio, which was methodologically wrong: the `subscribers` numerator counted any pricing-visitor who subscribed within 7 days of the view, regardless of whether they clicked a plan, while the denominator was plan-clickers. The resulting rate (27.5% pre → 35.5% post) compared two non-nested populations. Q9 recomputed step 5 with proper attribution: users who clicked a plan AND subscribed within 7 days of that plan click. All step-5 numbers below are the corrected Q9 values.

Cumulative conversion below retains the product-team-equivalent definition (any subscriber / any visitor within 7 days of view) — that is a valid aggregate metric and is comparable to the product team's 2.7%, but it does NOT equal the product of the step rates because step 5 uses plan-click-attributed subscribers while cumulative uses all post-view subscribers.

**Avg Time column** — not computed in this pass. The product team's original avg-time values came from their Mixpanel funnel export. A follow-on query on event-timestamp deltas per user per step would reproduce them; flag if you want it.

## Pre-change (Jan 7 – Feb 6 2026)

| Step | Step Conv. | Cumulative Conv. | Avg Time |
|---|---:|---:|---:|
| Pricing Page → Enter Persona Flow | 56.3% | 56.3% | — |
| Enter Persona Flow → Select Persona | 81.8% | 46.1% | — |
| Select Persona → Click Plan | 25.7% | 11.8% | — |
| Click Plan → Subscribe (Q9, plan-click attributed) | 20.1% | 2.38% (plan-click cum) | — |
| **Overall: Pricing → Subscribed (all-sub cum)** | — | **3.25%** | — |

Raw counts: 15,334 visitors → 8,633 entered flow → 7,065 persona → 1,816 plan → 364 plan-click→subs (Q9). All-subscriber cum uses 499 total pricing-view-attributed subs (Q3).

## Post-change (Feb 24 – Apr 23 2026, contamination-excluded)

| Step | Step Conv. | Cumulative Conv. | Avg Time |
|---|---:|---:|---:|
| Pricing Page → Enter Persona Flow | 51.7% | 51.7% | — |
| Enter Persona Flow → Select Persona | 81.3% | 42.0% | — |
| Select Persona → Click Plan | 27.3% | 11.5% | — |
| Click Plan → Subscribe (Q9, plan-click attributed) | 26.2% | 3.00% (plan-click cum) | — |
| **Overall: Pricing → Subscribed (all-sub cum)** | — | **4.07%** | — |

Raw counts: 18,046 visitors → 9,325 entered flow → 7,585 persona → 2,066 plan → 542 plan-click→subs (Q9). All-subscriber cum uses 735 total pricing-view-attributed subs (Q3).

## Pre vs Post delta summary (aggregate)

| Metric | Pre | Post | Δ (pp) | Δ (rel) |
|---|---:|---:|---:|---:|
| Step 2 — Enter Persona Flow | 56.3% | 51.7% | −4.6 | −8.2% |
| Step 3 — Enter Flow → Persona | 81.8% | 81.3% | −0.5 | −0.6% |
| Step 4 — Persona → Plan | 25.7% | 27.3% | +1.6 | +6.1% |
| Step 5 — Plan → Subscribe (Q9, corrected) | 20.1% | 26.2% | **+6.2** | **+30.7%** |
| Plan-click cumulative (Q9) | 2.38% | 3.00% | +0.62 | +26.2% |
| All-subscriber cumulative (Q3) | 3.25% | 4.07% | +0.82 | +25.3% |
| Cumulative persona selection | 46.1% | 42.0% | −4.1 | −8.9% |
| Cumulative plan click | 11.8% | 11.5% | −0.3 | −2.8% |

Aggregate step 5 and cumulative are both directionally up, but the per-cohort review below exposes that the aggregate story hides a direction mismatch across cohorts.

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

### Step 5 (Plan → Subscribe) rate by cohort — corrected via Q9

| Cohort | Pre | Post-8wk-clean | Δpp |
|---|---:|---:|---:|
| anonymous | 6.3% | 8.4% | +2.1 |
| free-account | 40.3% | 49.4% | +9.1 |
| paid-subscriber | 9.8% | 27.0% | +17.2 (tiny N, 4→10 subs — unreliable) |
| aggregate | 20.0% | 26.2% | +6.2 |

The earlier Q8-based step-5 rates (anon 7.9→11.2, free 53.4→64.7, aggregate 27.5→35.5) were computed with the same broken attribution as Q3 step 5 (numerator: any subscriber who viewed pricing within 7d; denominator: plan-clickers). Q9 corrects this by requiring the subscribe to occur within 7d of the plan click itself.

### Composition vs behavior decomposition of aggregate Plan → Subscribe step (Q9)

Plan-clicker composition:
- Pre: 57.4% anon / 40.3% free / 2.3% paid
- Post-8wk-clean: 55.5% anon / 42.7% free / 1.8% paid

Counterfactual (pre within-cohort step-5 rates × post plan-clicker composition):
- = 0.555 × 6.3% + 0.427 × 40.3% + 0.018 × 9.8% = **20.9%**
- Observed post = **26.2%**
- Composition contribution: +0.9pp (out of +6.2pp = ~15%)
- Behavior (within-cohort) contribution: +5.3pp (out of +6.2pp = ~85%)

**The aggregate step-5 lift is ~85% within-cohort behavior change.** This is distinct from the cumulative-conversion lift, where timing (D20) ruled out both the banner deploy and the 3/16 composition step as drivers. Step-5 timing within the post window is untested in this pass — a weekly plan-click→subscribe series per cohort would settle whether the within-cohort step-5 lift aligns to 2/24, 3/16, or elsewhere.

### Cumulative conversion (all-subscriber) decomposition — unchanged from prior

The earlier "~96% composition / ~4% behavior" decomposition for the all-subscriber cumulative rate (3.25% → 4.07%) used a window-level counterfactual that does not test timing. D20's weekly rate shows the cumulative rate reached ~4% before either the 2/24 deploy or the 3/16 composition step. The cumulative lift is not attributable to either.

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

## Findings from the per-cohort review (cross-reference `funnel-tables-by-cohort.md`)

After breaking the funnel out by cohort in the sibling document, the aggregate picture above resolves into cohort-specific patterns that reshape the interpretation:

1. **The absolute subscriber-count lift is arithmetically a free-cohort "volume" story, but the mechanism is ambiguous.** The +178 plan-click-attributed sub delta (or +239 all-subscriber delta) decomposes to almost 100% free-cohort measured-visitor growth. Free-account visitors at pricing grew +2,257 (+62%) pre-vs-post; at their pre-rate of 8.14% that volume alone predicts +184 additional plan-click subs — 103% of the aggregate lift. Within-cohort rate movements net to approximately zero. **Mechanism caveat (undiagnosed):** the measured free-share growth could reflect (A) actual additional free-account traffic routed to pricing post-consolidation, OR (B) improved cross-subdomain identity reconciliation under domain consolidation — the same underlying population finally being classified correctly as free instead of as anonymous. Both are consistent with the data and both sit within the domain-consolidation timeframe. Distinguishing requires engineering input on Mixpanel identity-SDK behavior cross-subdomain.

2. **The free-account cohort's cumulative conversion went DOWN, 10.80% → 9.73%.** The highest-converting cohort got worse pre-vs-post. Their Plan → Subscribe step rate lifted +9.1pp (40.3% → 49.4%), but their Enter Persona Flow rate fell −9.3pp (56.5% → 47.2%) and their Persona → Plan step rate fell −4.1pp. Top-of-funnel dilution dominated the step-5 gain. The aggregate "conversion rate up 25%" framing masks this decline entirely.

3. **The anonymous cohort's cumulative conversion rose, 0.72% → 1.08% (+50% relative).** Absolute contribution is ~+47 subs out of +239 aggregate (~20%). Meaningful but dwarfed by free-volume growth.

4. **The paid cohort is not signal.** 4 subscribers pre, 10 post. Large-looking percentages (step-5 9.8% → 27.0%) are noise. Drop paid from any directional framing.

5. **Within-cohort plan-click → subscribe step rate is largely flat once volume is properly accounted for.** The +6.2pp aggregate step-5 lift initially looked like +85% behavior, +15% composition, but the volume decomposition shows the aggregate SUB count is +105% volume, near-zero net rate. The two views are not in conflict — rates can rise within cohorts while aggregate sub-count lift still comes almost entirely from volume — but the framing "pricing-page behavior got materially better" is not supported. Free users click and subscribe at marginally different rates; most of the absolute subscriber count gain is from there being many more of them.

6. **Direction mismatch inside the aggregate.** The aggregate cumulative rose (+0.82pp) and the aggregate step-5 rose (+6.2pp), but the free cohort's cumulative fell (−1.07pp). Any stakeholder framing of "pricing-page conversion is up" should carry the caveat that free-cohort conversion went down.

7. **Attribution to the 2/24 banner deploy remains unsupported** for both step 5 (timing untested at cohort level) and cumulative (D20 ruled out 2/24 at the aggregate). D19's free-share step change aligns with the 3/16 domain-consolidation stabilization. Strong-form attribution claims require the weekly per-cohort step-5 series and a plausible mechanism from product/engineering.
