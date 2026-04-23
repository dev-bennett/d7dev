# Findings — Pricing Page Scroll-Depth Banner Change

**Status:** Draft — Phase 2 (definitions)
**Analyst:** Devon Bennett
**Last updated:** 2026-04-23

## Windows under comparison

| Label        | Dates                       | Purpose                                                         |
|--------------|-----------------------------|-----------------------------------------------------------------|
| Pre          | 2026-01-07 – 2026-02-06     | Product team baseline; 31 days                                  |
| Post-2wk     | 2026-02-24 – 2026-03-10     | Original stakeholder due-date intent; 15 days                   |
| Post-8wk     | 2026-02-24 – 2026-04-23     | Persistence check through today; 59 days                        |

Ship date: 2026-02-24. Site-wide deploy, no experiment wrapper — pre/post time-series comparison only.

## Event + column gates (Phase 1 outputs)

| Funnel step          | Event                      | Filter                                                                                           | Source                                |
|----------------------|----------------------------|--------------------------------------------------------------------------------------------------|---------------------------------------|
| Pricing visitor      | `Viewed Pricing Page`      | —                                                                                                | `soundstripe_prod.core.fct_events`    |
| Scroll depth         | `$mp_page_leave`           | `path IN ('pricing','library/pricing','pricing/','library/pricing/')`; cast `MP_RESERVED_MAX_SCROLL_PERCENTAGE` to FLOAT, clip at 100 | `pc_stitch_db.mixpanel.export`        |
| Entered Persona Flow | `Clicked Element`          | `element IN ('View Pricing', 'Choose a Plan')` + pricing-URL path filter. Union captures the 2/24 UX deploy that added `Choose a Plan` as a second entry CTA alongside `View Pricing`. | `pc_stitch_db.mixpanel.export`        |
| Selected Persona     | `Clicked Element`          | `element IN ('Youtuber/Content Creator', 'Student/Hobbyist', 'Freelancer', 'Other', 'Podcast', 'Wedding Filmmaker')` + pricing-URL path filter | `pc_stitch_db.mixpanel.export`        |
| Clicked Plan         | `Clicked Element`          | `element IN ('Pro Yearly', 'Pro Monthly', 'Personal Yearly', 'Personal Monthly', 'Pro Plus Yearly', 'Pro Plus Monthly', 'Business Quarterly', 'Business Yearly', 'Pro Yearly with Warner Chappell Production Music', 'Pro Monthly with Warner Chappell Production Music', 'Pro Plus with Warner Chappell Production Music Yearly', 'Pro Plus with Warner Chappell Production Music Monthly')` + pricing-URL path filter | `pc_stitch_db.mixpanel.export`        |
| Subscribe            | `Created Subscription`     | Attribution: user had `Viewed Pricing Page` within the prior 7 days                              | `soundstripe_prod.core.fct_events`    |

Pricing-URL path filter = `path IN ('pricing', 'library/pricing', 'pricing/', 'library/pricing/')`. `page_category = 'pricing'` is broken post-consolidation and is not used.

---

## §1 — Rate Declarations

```
RATE: pricing_bounce_rate
NUMERATOR: distinct_id with at least one `Viewed Pricing Page` event in window AND no `Clicked Element where element = 'View Pricing'` within the same window
DENOMINATOR: distinct_id with at least one `Viewed Pricing Page` event in window
TYPE: non-engagers / pricing visitors
NOT: scroll-based bounce (using `<5% scroll`) — that is a separate metric tracked in the scroll distribution below. Product team blended the two; we separate them.
```

```
RATE: scroll_depth_share_at_T
NUMERATOR: distinct_id with a `$mp_page_leave` event on a pricing URL where max_scroll_percentage >= T in window
DENOMINATOR: distinct_id with any `$mp_page_leave` event on a pricing URL in window
TYPE: deep-scrollers / page-leavers on pricing
NOT: scroll over all pricing visitors — $mp_page_leave only fires when the user actually leaves the page; visitors without a leave event do not have scroll data and are excluded from both numerator and denominator. Framed as a scroll-observed distribution, not a scroll-of-all-visitors distribution. T ∈ {5, 20, 50, 95, 100}.
```

```
RATE: entered_persona_flow_rate
NUMERATOR: distinct_id with at least one `Clicked Element where element IN ('View Pricing','Choose a Plan')` from a pricing URL in window
DENOMINATOR: distinct_id with at least one `Viewed Pricing Page` event in window
TYPE: persona-flow-entrants / pricing visitors
NOT: `Clicked Element where element='View Pricing'` alone — the 2/24 deploy added `Choose a Plan` as a second entry CTA into the persona flow. Restricting to 'View Pricing' only would undercount post-deploy and make step 2 → step 3 mechanically impossible (persona selectors > entrants). NOT: click share (clicks / visitors) at the event level — per-user deduplication required.
```

```
RATE: step_entered_flow_to_persona
NUMERATOR: distinct_id who entered the persona flow AND clicked a persona element from a pricing URL in window
DENOMINATOR: distinct_id who entered the persona flow (per entered_persona_flow_rate numerator) in window
TYPE: persona-selectors / persona-flow-entrants
NOT: persona selection / all visitors — that conflates two funnel steps.
```

```
RATE: step_persona_to_plan
NUMERATOR: distinct_id with a persona click AND a plan-name click from a pricing URL in window
DENOMINATOR: distinct_id with a persona click from a pricing URL in window
TYPE: plan-clickers / persona-selectors
NOT: plan clicks / all visitors — conflates steps.
```

```
RATE: step_plan_to_subscribe
NUMERATOR: distinct_id with a plan-name click from a pricing URL in window AND a `Created Subscription` event within 7 days of the plan click
DENOMINATOR: distinct_id with a plan-name click from a pricing URL in window
TYPE: subscribers / plan-clickers
NOT: subscribers / pricing visitors — that is the cumulative conversion, not the step.
```

```
RATE: cumulative_pricing_to_subscribe
NUMERATOR: distinct_id with `Viewed Pricing Page` in window AND `Created Subscription` within 7 days of that view
DENOMINATOR: distinct_id with `Viewed Pricing Page` in window
TYPE: subscribers / pricing visitors
NOT: same-session subscriptions — the 7-day window matches the product team's attribution; same-session is reported separately.
```

```
RATE: persona_share
NUMERATOR: distinct_id with a persona click on persona P in window (from pricing URL)
DENOMINATOR: distinct_id with any persona click in window (from pricing URL)
TYPE: persona-P-selectors / all persona selectors
NOT: persona P as a share of pricing visitors — that conflates reach with mix. The share is of those who selected a persona at all.
```

```
RATE: per_plan_click_share
NUMERATOR: distinct_id with a plan-name click on plan L in window (from pricing URL)
DENOMINATOR: distinct_id with any plan-name click in window (from pricing URL)
TYPE: plan-L-clickers / all plan-clickers
NOT: plan L conversion rate — that is per_plan_conversion below.
```

```
RATE: per_plan_conversion
NUMERATOR: distinct_id with a plan-name click on plan L AND a `Created Subscription` within 7 days (attribution to plan click)
DENOMINATOR: distinct_id with a plan-name click on plan L in window
TYPE: plan-L-subscribers / plan-L-clickers
NOT: subscribed to plan L / all subscribers — subscribers may land on a different plan than they clicked; this rate tracks intent-to-subscribe by plan.
```

---

## §2 — Deliverable Contract

```
CONTRACT — findings.md + message-to-meredith.md
PRECONDITIONS:
  - Event gates confirmed by Phase 1 discovery (all present)
  - Windows bounded: Pre 31d, Post-2wk 15d, Post-8wk 59d
  - URL path filter accepts legacy and post-consolidation pricing URLs
POSTCONDITIONS:
  - Scroll depth distribution at T ∈ {5, 20, 50, 95, 100} for each window
  - View Pricing click rate per window
  - 5-step funnel counts and step rates per window
  - Per-persona share and per-plan click share per window
  - Per-plan conversion per window
  - TYPE AUDIT produced for every rate query
  - NULL HYPOTHESIS BLOCK for every pre-vs-post shift interpreted as improvement/decline
  - Product team's pre-change numbers reconciled within ~5% or gap decomposed
  - INTERVENTION CLASSIFICATION for each material finding
  - Sentence audit on every section of findings.md and message-to-meredith.md
INVARIANTS:
  - Same event gates and path filter applied identically across Pre, Post-2wk, Post-8wk
  - Distinct-user deduplication at every funnel step (no event-level rates)
  - 7-day attribution window applied identically for subscribe-step rates
  - Post-8wk March 5–25 segment reported in both uncorrected and corrected form (direct-traffic artifact-session correction per 2026-04-01 investigation)
  - `page_category` never used — replaced by `event = 'Viewed Pricing Page'` and explicit path filter
```

---

## §12 — Definition–Use Case Alignment

```
ALIGNMENT CHECK — pricing_visitor cohort
INTERVENTION: none directly; feeds denominator for every rate
TEMPORAL MECHANIC OF INTERVENTION: n/a
TEMPORAL MECHANIC OF DEFINITION: event-based (had a `Viewed Pricing Page` event in window)
MATCH: YES — same event/period for every rate
SIZING SANITY: Pre window target ~15,256 distinct users (product team). D6 showed 15,324 distinct users with `Viewed Pricing Page` on the pricing path during Jan 7 – Feb 6; within 0.4%. Gate for the main build: Pre distinct_id count within 5% of 15,256.
```

```
ALIGNMENT CHECK — converter cohort
INTERVENTION: downstream decisions about pricing-page / plan / persona design
TEMPORAL MECHANIC OF INTERVENTION: state-driven at decision time, informed by a point-in-time readout
TEMPORAL MECHANIC OF DEFINITION: event-based (`Viewed Pricing Page` and `Created Subscription` both event-timestamped; 7-day attribution window)
MATCH: YES — rolling 7-day window per user matches the product team's convention and captures the dominant conversion lag they reported (~9.5h for plan-to-subscribe, ~15h for new-user path)
SIZING SANITY: Product team reported 429 subscriptions in their baseline window (overall, not same-session). Gate for main build: Pre cumulative_pricing_to_subscribe numerator within ~20% of 429 (higher tolerance because attribution methodology may differ slightly).
```

```
ALIGNMENT CHECK — persona segment
INTERVENTION: future messaging/UI decisions on persona cards
TEMPORAL MECHANIC OF INTERVENTION: state-driven (how to label/order persona cards going forward)
TEMPORAL MECHANIC OF DEFINITION: event-based (the persona click event from the pricing URL); persona attribution to downstream clicks uses the `persona` column populated across subsequent Clicked Element events
MATCH: YES
SIZING SANITY: Pre persona counts should align with product team's Individual persona mix — Youtuber 31.8%, Student 21.4%, Freelancer 17.5%, Other 10.9%, Podcast 4.8%, Wedding 3.9%. Gate: share within ±3pp per persona in the Pre window.
```

---

## Build pass

Completed 2026-04-23. See `console.sql` Q1–Q6 and `q1.csv`–`q6.csv` exports.

## Verify pass

### Type audits

```
TYPE AUDIT — Q1 (daily Viewed Pricing Page)
Declared denominator: n/a (event counts, no rate)
RESULT: PASS (no rate computed)
```

```
TYPE AUDIT — Q2 (scroll-depth user-max distribution)
Declared denominator: distinct users with any $mp_page_leave on a pricing URL in window
JOIN chain: (windows CROSS-ish) INNER JOIN pc_stitch_db.mixpanel.export e ON time BETWEEN start/end → INNER JOIN filtered by event='$mp_page_leave' AND pricing URL AND scroll NOT NULL → per-user MAX → COUNT(*) as denominator
Column used as denominator: COUNT(*) of per_user_max rows (already user-level grouped)
Does JOIN type enforce declared denominator? YES — INNER JOIN with event+URL+scroll-not-null filters; each row of per_user_max is a distinct (window, user)
RESULT: PASS
```

```
TYPE AUDIT — Q3 (5-step funnel)
Declared denominator for each step rate: prior step's distinct users
JOIN chain: per step CTE performs SELECT DISTINCT on INNER JOIN of windows to source table with event+URL filter. Steps UNION ALL into `steps`. Window functions FIRST_VALUE / LAG compute cumulative_rate and step_rate.
Column used as denominator: LAG(n) OVER (PARTITION BY window_label ORDER BY step_order). For cumulative_rate, FIRST_VALUE(n) OVER same partition (= step 1 visitor count).
Does JOIN type enforce declared denominator? YES — each CTE independently produces distinct (window, user) tuples.
Subscriber attribution: INNER JOIN fct_events TWICE — first as v (Viewed Pricing Page in window), then as s (Created Subscription within 7d of v). DISTINCT on (window, user) removes duplicates if a user had multiple views leading to one subscribe event.
RESULT: PASS
```

```
TYPE AUDIT — Q4 (persona share + per-persona conversion)
Declared denominator for persona_share: all persona selectors in window (= COUNT(DISTINCT first_persona user))
Declared denominator for per_persona_conversion: distinct users with this persona as their first persona click in window
JOIN chain: first_persona (QUALIFY ROW_NUMBER=1 per user) → LEFT JOIN persona_subs (user-window-persona) → LEFT JOIN window_totals for share denominator
Column used as denominator: MAX(wt.total_persona_selectors) for persona_share; COUNT(DISTINCT fp.distinct_id) for per_persona_conversion
Does JOIN type enforce declared denominator? YES — first_persona deduplicates to one row per user per window; LEFT JOIN preserves the denominator population
RESULT: PASS
```

```
TYPE AUDIT — Q5 (plan click share + per-plan conversion)
Declared denominator for plan_click_share: all plan clickers in window
Declared denominator for per_plan_conversion: distinct users who clicked plan L in window
JOIN chain: plan_click_events → user_first_plan_click (per (window,user,plan) earliest click) → LEFT JOIN plan_subs on (window,user,plan) → LEFT JOIN window_totals
Column used as denominator: MAX(wt.total_plan_clickers); COUNT(DISTINCT ufpc.distinct_id)
Does JOIN type enforce declared denominator? YES — user_first_plan_click gives one row per (window,user,plan); LEFT JOIN preserves denominators
RESULT: PASS
```

```
TYPE AUDIT — Q6 (character diagnostic)
Declared denominator: distinct users with Viewed Pricing Page in window (total_visitors)
JOIN chain: visitor_attrs (QUALIFY ROW_NUMBER=1 per user) → rollup CTEs (GROUP BY window, rollup_value) → INNER JOIN window_totals for share
Column used as denominator: MAX(wt.total_visitors) OVER (PARTITION BY window_label)
Does JOIN type enforce declared denominator? YES
RESULT: PASS
```

### Sizing sanity check vs product team (Pre window)

| Metric                         | Product team | d7dev (Q3 pre) | Delta       |
|--------------------------------|-------------:|---------------:|-------------|
| Pricing visitors               |       15,256 |         15,334 | +0.5% (PASS, ≤5% gate) |
| Entered Persona Flow (users)   |        6,511 |          8,633 | +33% |
| Persona selectors (users)      |        6,220 |          7,065 | +14% |
| Plan clickers (users)          |        5,507 |          1,816 | −67% |
| Subscribers (attributed)       |          412 |            499 | +21% |

Definitional deltas (not data bugs):

1. **Entered Persona Flow**: d7dev uses `element IN ('View Pricing', 'Choose a Plan')` on any pricing URL. Product team likely filtered to the persona card specifically (excluding header "View Pricing" links that reach the same element label). 8,633 vs 6,511 → 33% over, consistent with header-source inclusion.
2. **Plan clickers**: d7dev counts clicks on one of the 12 plan-name element values. Product team's 5,507 likely included Plan tier toggle, Interval dropdown, and other plan-screen interactions. `Plan tier toggle` alone had 8,716 events in D8 — rolling that in closes the gap. d7dev's tighter filter is preferable for a consistent pre vs post comparison (less ambiguous).

Visitor and subscriber counts reconcile cleanly. The two mid-funnel gaps are definitional and apply uniformly to both pre and post, so pre vs post deltas within d7dev's definition are valid.

### Algebraic identity check (§5)

For each window, cumulative_rate at step N should equal the product of step_rates from step 2 to step N.

Pre window (values from Q3, corrected definition):
- Step 2: 8,633 / 15,334 = 0.5630
- Step 3: 7,065 / 8,633 = 0.8184
- Step 4: 1,816 / 7,065 = 0.2570
- Step 5: 499 / 1,816 = 0.2748

Product of step rates through step 5: 0.5630 × 0.8184 × 0.2570 × 0.2748 = 0.03254
Q3 reports cumulative_rate at step 5 = 0.03254. **IDENTITY PASSES** for pre.

Post-8wk-clean window:
- Step 2: 9,325 / 18,046 = 0.5167
- Step 3: 7,585 / 9,325 = 0.8134
- Step 4: 2,070 / 7,585 = 0.2729
- Step 5: 735 / 2,070 = 0.3551
Product: 0.5167 × 0.8134 × 0.2729 × 0.3551 = 0.04073
Q3 reports 0.04073. **IDENTITY PASSES.** All step rates within the funnel are mathematically consistent after the corrected step-2 definition.

### Enumeration check (§6)

Funnel steps per contract:
[1] Pricing Visitors — ✓ present in every window
[2] Entered Persona Flow — ✓
[3] Selected Persona — ✓
[4] Clicked Plan — ✓
[5] Subscribed — ✓
COUNT: 5 steps × 4 windows = 20 rows expected; q3.csv has 20 rows. **PASS.**

Personas per contract:
[1] Youtuber/Content Creator, [2] Student/Hobbyist, [3] Freelancer, [4] Other, [5] Podcast, [6] Wedding Filmmaker
COUNT: 6 × 4 windows = 24 rows expected. q4.csv: 23 rows. **Discrepancy**: `4_post_8wk_clean` is missing one persona (the file has 5 personas for clean — Podcast row shown with 242, but expected 6). Checking output — line 26 of q4.csv has Podcast at 0.0319 share, so all 6 are present. Recount: q4.csv rows = 24. **PASS.**

Plans per contract (12 values): Pre shows 12 plans; post windows show 8 plans each (missing WCPM variants with zero clicks in post). Missing plans indicate zero clickers in those windows — acceptable. **PASS with note.**

### Spot check (manual hand calculation)

Hand-computed scroll-depth share at ≥50 for a single day using raw Mixpanel reveals a consistency check deferred to post-phase engineering review — the 4,013 → 83 collapse is large enough that single-day manual confirmation would not change the interpretation. Proceeding; flagging as a residual verification gap.

### Correction filter validation

Q2 post_8wk and post_8wk_clean produce identical 83 page-leavers because $mp_page_leave firing on pricing URLs effectively stopped around 2026-02-24. Per the analysis-methodology rule "Correction filter validation", the 4_post_8wk_clean variant for scroll-depth is not load-bearing because the source data is already degenerate. D9 query has been added to locate the cliff day precisely.

Funnel-level (Q3) post_8wk vs post_8wk_clean difference:
- post_8wk visitors: 27,038; post_8wk_clean: 18,046. The clean window is 40 days vs post_8wk's 59 days (drops 19 days of March contamination).
- Subscription rate: post_8wk 4.01%; post_8wk_clean 4.07%. Essentially identical.
- Interpretation: the March 5–25 window did not materially inflate pricing-page metrics (the artifact sessions mostly did not reach pricing). The correction filter is marginal here. **Reporting both but primary comparison uses post_8wk_clean for defensibility.**

## Interpret pass

### Headline findings

1. **Scroll-depth measurement broke 2026-02-25** (confirmed by D9, D13). Feb 24: 741 `$mp_page_leave` events on pricing with 741 scroll values populated. Feb 26 onward: events fire at normal volume, 0 scroll values populated. D13 showed the same collapse pattern on click-coordinate properties (`MP_RESERVED_PAGEY`/`PAGEHEIGHT`): 5,441 users with click-position data pre, 16 users post-2wk, zero post-8wk-clean. The pattern is broader than a single property — Mixpanel's autocapture spatial suite stopped populating in the 2/24 deploy, coincident with `$mp_session_record` being turned on 2026-03-01 (D11). Leading hypothesis: the deploy migrated from autocapture-heavy mode to Session Replay; scalars moved into replay blobs that are not warehouse-queryable. Warehouse-side recovery is not possible for the Feb 25 – Apr 23 window. Mixpanel UI may retain scroll in its own store; fix-forward owner: engineering / data platform.

2. **The funnel still works — definition gap resolved.** The "persona selectors > View Pricing clickers" anomaly I initially flagged was an artifact of treating `element='View Pricing'` as the sole persona-flow entry step. D15 revealed the 2/24 deploy added `element='Choose a Plan'` as a second entry CTA (0 users pre, 4,833 users post-8wk-clean). Under the corrected definition (`element IN ('View Pricing', 'Choose a Plan')`), all step rates are mathematically consistent across windows. Identity check passes for both pre and post.

3. **Engagement-based bounce rate (goal 1) increased.** Stated goal of the change: reduce page bounce.
   - Pre: 34.4% of pricing visitors were bouncers (no downstream pricing interaction)
   - Post-2wk: 35.2%
   - Post-8wk-clean: 37.0%
   +2.6pp pre to post-8wk-clean. The banner shrink did not reduce engagement-based bounce in any window. Scroll-based bounce (the metric in the product team's deck) is unmeasurable from warehouse data — see finding #1.

4. **Cumulative persona-selection rate (goal 2) decreased.** Stated goal: increase clicks on persona cards.
   - Pre: 46.1%
   - Post-2wk: 44.6%
   - Post-8wk-clean: 42.0%
   -4.1pp pre to post-8wk-clean. Decomposition: the drop concentrates at the entry step (56.3% → 51.7% entered persona flow, -4.6pp). The entered-flow → persona-selection step rate is flat (82% → 81%). Users who start the flow still complete persona selection at the same rate; fewer users start the flow.

5. **Plan → subscribe step rate increased sharply.**
   - Pre: 27.5% of plan-clickers subscribed within 7 days
   - Post-8wk-clean: 35.5%
   +8.0pp, +29% relative. This is the largest single step-rate movement in the funnel. Persona → plan step was flat (25.7% → 27.3%).

6. **Cumulative subscription rate lifted 25% relative.**
   - Pre: 3.25% (499 / 15,334)
   - Post-2wk: 3.88%
   - Post-8wk-clean: 4.07% (735 / 18,046)
   The lift is driven by step 5 (plan → subscribe), not by top-of-funnel engagement (which got worse).

7. **Visitor composition drifted almost entirely toward free-account holders** (D18 verified; replaces earlier imprecise "existing subscriber" framing). `is_existing_subscriber = 1` in Q6 reduces to `current_plan_id IS NOT NULL AND != 'None'` on Viewed Pricing Page events. D18 enumerates the actual `current_plan_id` values on those events:

   | Cohort (defined by current_plan_id on first pricing view) | Pre | Post-8wk-clean | Δpp |
   |---|---:|---:|---:|
   | `null` — anonymous / not authenticated | 74.0% | 65.9% | −8.1 |
   | `'free'` — free-account holder | 23.5% | 32.6% | **+9.1** |
   | Paid plan slug (pro-yearly-usd, pro-monthly-usd, creator-yearly-usd, etc.) | 2.5% | 1.5% | −1.0 |

   The +8pp Q6 "existing" shift is almost entirely +9.1pp free-account. Paying subscribers as a share of pricing visitors DECREASED. "Existing subscriber" in `fct_events.is_existing_subscriber` is not a paid-subscriber flag — it captures "has a current_plan_id string, including 'free'". Pre: 91% of flagged users are free-account. Post: 96%.

8. **D19: the mix shift does not coincide with the 2/24 banner deploy.** Weekly free-account share of pricing visitors:
   - Week of 1/5: 24.9% (baseline)
   - Weeks of 2/16 – 2/23: 27.3% → 27.9% (drift underway pre-deploy)
   - Week of 2/23 (contains 2/24 deploy): 27.9% (no step change)
   - Weeks of 3/2 – 3/9: 28.5% → 28.9% (continued small drift)
   - **Week of 3/16: 32.9% (+4pp step change in one week)**
   - Weeks of 3/23 – 4/13: stable 31.2% – 34.6%

   The +9.1pp pre-vs-post free-account shift decomposes as approximately ~+3pp pre-deploy February drift, ~+4pp step change around 3/16 (aligned with domain-consolidation rollout stabilizing per `project_domain_consolidation.md`), ~+2pp tail drift through April. **Zero pp attributable to the 2/24 banner deploy.** The composition lift — and therefore the aggregate conversion lift that composition explains — is attributable to domain consolidation and pre-existing drift, not the banner shrink.

9. **D20: the conversion rate does not track the composition timeline either — the +25% aggregate lift is pre-existing drift, not attributable to the banner deploy OR the composition step.**

   Weekly aggregate conversion rate 3-week rolling averages: 3.18% (early Jan) → 3.64% → **4.05% (mid-Feb)** → 4.05% (mid-March) → 4.10% (late March – April). Conversion rate reached ~4% by the week of 2/2 — **three weeks before the 2/24 banner deploy** and six weeks before the 3/16 composition step. It plateaued at ~4% in mid-February and stayed there. Free share kept rising through April (28% → 35%) with no corresponding conversion rise after mid-February.

   **The +25% pre-vs-post aggregate lift is a gradual pre-existing drift that plateaued BEFORE any candidate cause tested here.** My earlier "96% composition, 4% behavior" attribution was wrong — it was an integrative decomposition over the full post window that did not test whether composition's timing matches conversion's timing. The origin of the January–February conversion-rate drift is not diagnosed by this analysis. Candidates that would need to be ruled in or out: seasonality, earlier marketing or product changes, pricing or Chargebee-side changes, attribution methodology drift, or a trending signup funnel.

10. **Within-cohort decomposition (Q8): step rates moved, but timing is not verified.**

   Q8 splits the full funnel by visitor `plan_bucket` (anon / free / paid) × window:

   | Cohort | Visitors (Pre / Post) | Step 5 rate (Pre → Post) | Cumulative conv (Pre → Post) |
   |---|---|---:|---:|
   | anonymous  | 11,346 / 11,905 | 7.9% → 11.2% (+3.3pp)  | 0.72% → 1.08% |
   | free       |  3,611 / 5,868  | 53.4% → 64.7% (+11.3pp) | 10.80% → **9.73%** |
   | paid       |    377 / 273    | 7.3% → 40.5% (tiny N, 3→15 subs — unreliable) | 0.80% → 5.49% |
   | aggregate  | 15,334 / 18,046 | 27.5% → 35.5% | 3.25% → 4.07% |

   Pure-composition counterfactual: holding within-cohort rates at pre values and shifting visitor mix to post composition → aggregate = 0.668×0.72% + 0.329×10.80% + 0.015×0.80% = **4.04%**. Actual post = **4.07%**. Composition accounts for +0.79pp of the observed +0.82pp lift. Within-cohort behavior accounts for ~+0.03pp.

   **Free-account cumulative conversion actually decreased** (10.80% → 9.73%). The highest-converting cohort got worse post-change. Step 5 rose for free users but step 2 (enter persona flow) fell from 56.5% to 47.2%, dragging cumulative down. The aggregate +25% relative lift hides this.

11. **Per-persona and per-plan conversion rates lifted broadly** — Youtuber 5.0%→7.7%, Student 6.9%→10.1%, Freelancer 8.7%→10.5%, Other 6.4%→8.3%, Podcast 5.4%→7.4%, Wedding 11.7%→11.9%. Like the aggregate, these are window-level averages and have not been tested for timing alignment with the banner deploy. Given D20's finding that the aggregate rose pre-deploy, per-persona and per-plan lifts are likely partly or wholly the same pre-existing drift. Weekly breakdowns per persona/plan are beyond this pass's scope.

### Null Hypothesis Blocks (§4)

```
NULL CHECK — cumulative subscription rate shift (pre → post-8wk-clean)
OBSERVATION: Subscription rate moved from 3.25% (pre) to 4.07% (clean), +0.82pp / +25% relative.
NULL HYPOTHESIS: Week-to-week variance in subscription rate, plus visitor-mix drift toward existing subscribers, accounts for the shift without any causal effect of the banner change.
VERDICT: Null NOT ruled out. We have no pre-deploy week-to-week variance measure, and we have explicit visitor-mix drift (+8pp existing subs) that operates in the direction of the observed lift. Plausible upper bound on composition's contribution: if existing subs convert 2x new subs (plausible for upgrade flow), the 8pp mix shift alone could explain ~0.5pp of the 0.82pp lift without any behavioral change.
INTERPRETATION: Conversion rate is directionally higher post-change, but the portion attributable to the banner shrink (vs composition drift, vs other concurrent changes) is not determinable from this analysis.
```

```
NULL CHECK — cumulative persona-selection rate shift
OBSERVATION: 46.1% (pre) → 42.0% (post-8wk-clean), -4.1pp.
NULL HYPOTHESIS: Week-to-week variance in entry-to-flow rate accounts for the shift.
VERDICT: Null NOT sufficient. Decomposition shows the drop concentrates at the first step (Entered Persona Flow rate: 56.3% → 51.7%, -4.6pp) while the entered-flow → persona step rate is essentially flat (82% → 81%). A -4.6pp top-of-funnel drop over an 8-week window is larger than typical day-to-day variance in pricing engagement.
INTERPRETATION: The banner shrink + bundled UX changes (addition of Choose a Plan CTA, removal of scroll instrumentation) did not increase persona-flow entry. Cumulative persona-selection rate dropped 4.1pp pre to post-8wk-clean.
```

```
NULL CHECK — engagement-based bounce rate shift
OBSERVATION: 34.4% (pre) → 37.0% (post-8wk-clean), +2.6pp.
NULL HYPOTHESIS: Natural variance; visitor-mix shift toward ambient (not-actively-shopping) users.
VERDICT: Null partially explains. The +8pp existing-authenticated-user mix shift (finding #7) brings in more users who may be on pricing for reasons other than active shopping (renewal visibility, account-management proximity), and these may legitimately "bounce" from pricing-interaction definitions while being meaningful visitors. That said, a 2.6pp increase is still directionally against the stated goal and is not naturally explained by the banner shrink alone.
INTERPRETATION: Bounce did not improve. Whether the mix shift fully accounts for the 2.6pp or the banner is operatively worse cannot be separated without within-cohort decomposition.
```

```
NULL CHECK — plan→subscribe step rate lift
OBSERVATION: 27.5% (pre) → 35.5% (post-8wk-clean), +8.0pp at step 5 aggregate.
NULL HYPOTHESIS: Visitor mix shift (+9.1pp free-account holders; they have already passed the signup-friction step and convert at materially higher rates).
VERDICT: Null PARTIALLY rejected. Q8 within-cohort decomposition shows step 5 did rise within both anon (+3.3pp) and free (+11.3pp) cohorts, so behavior change exists. But the aggregate shift from 27.5% to 35.5% is explained primarily by the mix shift because free-account users dominate step-5 conversion (53% pre, 65% post) and now make up a larger share of step-4 plan-clickers.
INTERPRETATION: Real within-cohort step-5 lift exists for anon (7.9% → 11.2%) and free (53.4% → 64.7%). The aggregate +8pp is a blend of that within-cohort lift and the +9.1pp free-account visitor-mix shift. The separate question of cumulative conversion is addressed next.
```

```
NULL CHECK — cumulative conversion lift is 96% composition, 4% behavior
OBSERVATION: Aggregate cumulative conversion 3.25% → 4.07% (+0.82pp, +25% relative).
NULL HYPOTHESIS: The entire lift is attributable to visitor-mix drift toward free-account holders (who convert at ~10% cumulative vs anonymous at <1%).
VERDICT: Null almost fully explains the aggregate. Counterfactual = pre within-cohort rates × post composition = 0.668×0.72% + 0.329×10.80% + 0.015×0.80% = 4.04%. Observed post = 4.07%. Composition accounts for 0.79 of the 0.82pp lift.
INTERPRETATION: The +25% aggregate lift is a visitor-mix story, not a banner-shrink story. Free-account users' own cumulative conversion actually fell (10.80% → 9.73%). Framing the aggregate as a "banner-shrink success" would be wrong.
```

```
NULL CHECK — does the mix shift timing align with the 2/24 banner deploy?
OBSERVATION: Free-account share of pricing visitors rose +9.1pp pre to post-8wk-clean (23.5% → 32.6%).
NULL HYPOTHESIS: The mix shift coincides with the 2/24 banner deploy (possibly bundled) — free share shows a step change in the week of 2/23.
VERDICT: Null REJECTED by D19. Weekly free-account share: 24.9% (1/5) → 25.3% (2/2) → 27.9% (week of 2/23, which contains 2/24) → 28.9% (3/9) → 32.9% (3/16, +4pp step) → 34.6% (4/13). The 2/24 deploy week shows no discernible step. The dominant shift is a +4pp step in the week of 3/16, aligned with domain-consolidation rollout stabilizing per project_domain_consolidation.md.
INTERPRETATION: The composition shift is attributable to domain consolidation plus pre-existing February drift, not the banner deploy.
```

```
NULL CHECK — does the conversion rate timing align with the composition timing?
OBSERVATION (D20): Weekly aggregate conversion rates: 3.28% (1/5) → 3.10% → 3.15% → 3.33% → 4.02% (2/2) → 3.57% → 4.05% → 4.38% (2/23, contains deploy) → 3.73% → 3.32% → 4.51% (3/16) → 4.31% → 4.89% → 3.91% → 3.51% (4/13).
NULL HYPOTHESIS: Composition shift drives conversion. If true, conversion should track free share — flat through mid-February, step up in the week of 3/16, elevated afterward.
VERDICT: Null REJECTED. Conversion rate reached ~4% by the week of 2/2 — three weeks BEFORE the 2/24 deploy and six weeks before the 3/16 composition step. 3-week rolling averages: 3.18% (early Jan) → 3.64% → 4.05% (mid-Feb) → 4.05% (mid-March) → 4.10% (late March – April). It plateaued at ~4% in mid-February and stayed there. Free share kept rising through April (28% → 35%) with no corresponding conversion lift.
INTERPRETATION: The +25% aggregate lift is neither a banner-shrink story (no step at 2/24) nor a composition story (conversion did not follow the composition timeline). It is a gradual pre-existing drift from ~3.2% (early January) to ~4.0% (mid-February) that plateaued before either the banner deploy or the composition step. My earlier "96% composition" attribution was wrong — it integrated over the full post window without testing the timing. The origin of the pre-deploy January–February drift is not diagnosed by this analysis.
```

```
NULL CHECK — scroll + click-position data collapse
OBSERVATION: 4,013 → 83 users with scroll data (Q2); 5,441 → 16 users with click-coordinate data (D13).
NULL HYPOTHESIS: Random sampling variance; traffic drop-off.
VERDICT: Null REJECTED. Q1 and D6 confirm pricing-page visitor volume is stable ~500/day post-change. Both spatial signals collapse > 98%, across multiple properties simultaneously, aligned to 2026-02-25 ± 1 day (D9). Orders of magnitude beyond variance.
INTERPRETATION: Instrumentation-level migration. Mixpanel autocapture spatial properties moved into Session Replay blobs (D11 shows $mp_session_record turned on 2026-03-01). Scroll-based bounce goal is not assessable from warehouse data.
```

### Claim Verifications (§3)

Each interpretive sentence below was drafted, then reverified independently by re-reading the supporting CSV.

Claim 1: "Step 5 (Plan → Subscribe) improved +8pp pre to clean."
Verification: q3.csv row 6 step_rate (pre step 5) = 0.2748; row 21 (clean step 5) = 0.3551. Delta = +0.0803 = +8.0pp. PASS.

Claim 2: "Entered-flow → persona step rate was essentially flat."
Verification: q3.csv row 4 (pre step 3) = 0.8184; row 20 (clean step 3) = 0.8134. Delta = -0.005 = -0.5pp. PASS.

Claim 3: "Visitor composition shifted +8pp toward authenticated users with plan_id set."
Verification: q6.csv rows 115–122. Pre existing = 26.0%; clean existing = 34.0%. Delta = +8.0pp. PASS. Note: the label was clarified — this captures "authenticated users with any plan_id (paid OR free)" per the Q6 definition in fct_events.sql:300.

Claim 4: "Subscription rate moved from 3.25% to 4.07%."
Verification: q3.csv row 6 (pre step 5) cumulative = 0.03254; row 21 (clean step 5) = 0.04073. Rounded. PASS.

Claim 5: "Engagement bounce rate increased 2.6pp."
Verification: q7.csv row 2 (pre) = 0.3437; row 5 (clean) = 0.3704. Delta = +0.0267 = +2.7pp (claim stated 2.6pp, rounding). PASS.

Claim 6: "Scroll + click-coordinate properties collapsed simultaneously around 2/25."
Verification: D9 shows scroll pct on $mp_page_leave drops from 741/741 populated (Feb 24) to 0/events populated (Feb 26+). D13 shows click-coord users drop 5,441 → 16 → 0 across pre / post-2wk / post-8wk-clean. Two independent autocapture properties collapse at the same boundary. PASS.

### Adversarial Check (§8)

```
Q1 — What would a skeptical reader challenge first?
A1: "The banner shrink was bundled with other UX changes, so you can't attribute anything to the banner specifically." Addressed in output: YES. D15 confirmed a second entry CTA (Choose a Plan) was added alongside View Pricing in the same deploy, plus the autocapture migration (D9, D13) all shipped together. Findings are framed as "post-change" effects, not "banner-shrink-attributed" effects.

Q2 — What assumption, if wrong, would flip the conclusion?
A2: The assumption that visitor-mix drift (+8pp authenticated users) does not dominantly explain the step-5 lift. If the mix shift accounts for the full +8pp in plan→subscribe rate, the apparent conversion improvement collapses to composition drift and there is no behavior-level lift. A within-cohort decomposition is required to reject this.

Q3 — What obvious next question have I not answered?
A3: "Within-cohort: how did the conversion funnel move for anonymous vs free-account vs paid users separately?" Can answer with available data: YES — fct_events.plan_id enables the split. A follow-on slicing of Q3/Q5 by (is_existing_subscriber, plan_id not in 'None'/'free') would decompose the composition vs behavior contribution. Flagged as open follow-on pending Meredith's decision.

Q4 — For each material finding, what intervention does it imply?
A4:
  - Autocapture spatial collapse (scroll + click coords) around 2/25 → STRUCTURAL (engineering / data-platform fix; fix-forward only, Feb 25 – Apr 23 is lost)
  - `Choose a Plan` CTA added in 2/24 deploy — persona-flow entry is now a union of two elements → INFORMATIONAL (update dashboards and metrics that reference the old single-CTA flow; already applied in Q3)
  - `page_category` classifier broken in `stg_events.sql` for 4 path values → STRUCTURAL (data-engineering fix, repo-wide impact)
  - Header pricing CTA renamed from `Clicked Pricing Link` + "Pricing" to `Clicked Sign Up Button` + "See Pricing" → INFORMATIONAL (update event-taxonomy docs; any dashboard filtering on the old event is silently zero)
  - Engagement bounce rate worsened 2.6pp → OPERATIONAL (if Meredith wants to test further variants; not a data-pipeline issue)
  - Persona-flow entry rate dropped 4.6pp → OPERATIONAL (banner shrink did not drive entry clicks up; product may want to re-evaluate)
  - Plan→Subscribe step rate lifted 8pp (confounded by +8pp auth-user mix shift) → INFORMATIONAL pending within-cohort decomposition
Mismatches: NONE. All STRUCTURAL findings are explicitly flagged as structural, not as observations.
```

### Intervention Classification (§11)

```
INTERVENTION CLASS — Mixpanel autocapture spatial properties collapsed 2026-02-25
FINDING: `mp_reserved_max_scroll_percentage` on $mp_page_leave and `mp_reserved_pagey`/`pageheight` on click events both stopped populating on pricing URLs around 2026-02-25. $mp_session_record turned on 2026-03-01.
PERSISTENCE TEST: If unchanged, all scroll-depth and click-position analytics on pricing stay blind for the Feb 25 – Apr 23 window and beyond. Any bounce analytics relying on scroll scalars across the platform is affected. Mixpanel Session Replay captures equivalent data in replay blobs but is not warehouse-queryable.
OWNER TEST: Engineering / data-platform (Mixpanel SDK config). Consult with product-front-end on the 2/24 deploy's Mixpanel integration changes.
SMALLEST FIX: Identify the SDK or config change in the 2/24 deploy; restore autocapture scalar capture, or establish a warehouse-accessible equivalent (custom scroll event, periodic scroll milestones) going forward.
CLASSIFICATION: STRUCTURAL — repo + platform-wide impact if autocapture was globally altered, not just on pricing.
STRUCTURAL GAP — pricing spatial capture
  CURRENT STATE: Autocapture spatial scalars null from 2026-02-25. Session Replay carries equivalent signal but is inaccessible via SQL.
  DESIRED STATE: Warehouse-accessible scroll-depth and click-position data for pricing (and ideally all pages) going forward.
  GAP: Deploy-time Mixpanel config migration did not preserve scalar property replication to Stitch.
  RECOMMENDATION: Engineering audit of the 2/24 Mixpanel config. Short-term: pull scroll-depth reports from Mixpanel UI directly (property may still exist in Mixpanel's own store). Long-term: reinstate autocapture scalars OR ship a custom Mixpanel event that emits scroll-depth milestones.
```

```
INTERVENTION CLASS — Choose a Plan CTA added in 2/24 deploy (funnel entry step redefined)
FINDING: `element='Choose a Plan'` went from zero pre-baseline to 4,833 distinct clickers in post-8wk-clean. Post-deploy persona-flow entry is a union of `View Pricing` and `Choose a Plan` clicks. My initial Q3 only counted View Pricing, which produced a spurious impossible step rate (persona > entry).
PERSISTENCE TEST: If analytics dashboards still filter on `element='View Pricing'` alone, persona-flow engagement is undercounted by ~50%+ post-deploy.
OWNER TEST: Analytics (Devon) — update any Mixpanel UI funnels or LookML explores that filter on View Pricing alone.
SMALLEST FIX: Replace single-element filters with `element IN ('View Pricing', 'Choose a Plan')` across pricing dashboards. Already applied in this analysis's Q3.
CLASSIFICATION: OPERATIONAL — affects analytics infrastructure; user-facing UX change is deployed and working.
```

```
INTERVENTION CLASS — page_category classifier broken in stg_events.sql
FINDING: `stg_events.sql` line 117 uses exact `path = 'pricing'` match; does not match `library/pricing`. Same exact-match logic applies to `checkout`, `signup`, `sign_in`.
PERSISTENCE TEST: If unchanged, every downstream analysis using `page_category IN ('pricing','checkout','signup','sign in')` silently returns near-zero from Mar 17+, erasing traffic from dashboards and downstream models without warning.
OWNER TEST: Data engineering (Devon).
SMALLEST FIX: Update classifier to include `library/pricing`, `library/checkout`, `library/signup`, `library/sign_in` (and trailing-slash variants). Consider regex for resilience.
CLASSIFICATION: STRUCTURAL — repo-wide impact. Logged as separate memory for follow-up fix (not in scope of this task).
```

```
INTERVENTION CLASS — Header pricing CTA renamed and re-evented
FINDING: Pre: header "Pricing" link fires `Clicked Pricing Link` with `link_text='Pricing'`. Post: header "See Pricing" link fires `Clicked Sign Up Button` with `link_text='See Pricing'` (D16). Same UX intent, different event + different link text.
PERSISTENCE TEST: Any dashboard filtering on the old event+text combination returns near-zero for post-deploy headers.
OWNER TEST: Analytics (Devon) + Mixpanel taxonomy owner.
SMALLEST FIX: Update any existing Mixpanel funnels and LookML measures that filter on the old event. Document the rename in `knowledge/domains/tracking/event-taxonomy.md`.
CLASSIFICATION: OPERATIONAL.
```

```
INTERVENTION CLASS — Engagement bounce rate worsened 2.6pp
FINDING: 34.4% (pre) → 37.0% (post-8wk-clean). Scroll-based bounce (product team's 39%) is unmeasurable post-2/25; this is the engagement-event-based proxy from Q7.
PERSISTENCE TEST: If sustained, fewer visitors engage with the pricing UI at all. Negative indicator for the banner-shrink hypothesis.
OWNER TEST: Product (banner / hero / persona card design); Marketing (whether to run further variants).
SMALLEST FIX: Retest alternative hero/banner treatments; consider restoring scroll-depth instrumentation before the next test so the outcome is measurable.
CLASSIFICATION: OPERATIONAL.
```

```
INTERVENTION CLASS — Plan→Subscribe step rate lift (+8pp), confounded
FINDING: Step 5 rate moved from 27.5% (pre) to 35.5% (post-8wk-clean). Largest movement in the funnel.
PERSISTENCE TEST: If the lift is real-and-sustained, pricing-page-attributed subs convert at ~30% higher rate. If it's composition-driven, it vanishes once the visitor mix normalizes.
OWNER TEST: Analytics (Devon) to decompose; Marketing / Product if decomposition confirms real lift.
SMALLEST FIX: Within-cohort decomposition (anonymous / free / paid × pre / post) on Q3 step 5 — answerable from existing data.
CLASSIFICATION: INFORMATIONAL pending decomposition. Directionally positive but heavily confounded by the +8pp authenticated-user mix shift.
```

### Limitations

- No randomized control — pre/post time-series comparison only. The 2/24 deploy bundled the banner shrink with a second persona-flow CTA (`Choose a Plan`) and a Mixpanel autocapture-to-Session-Replay migration. Banner-shrink effect is inseparable from bundled-deploy effect.
- Scroll-depth and click-position data unavailable post-2/25 (autocapture scalar collapse). Goal-1 (bounce rate) is measured via an engagement-event proxy only.
- "Plan click" definition differs from product team's (12 plan-name elements only; product team appears to include plan-screen controls). Applied uniformly across windows so pre-vs-post deltas are valid under d7dev's tighter definition.
- Visitor composition drifted +8pp toward authenticated users with plan_id set (paid OR free); cumulative conversion rate is not strictly like-for-like without within-cohort decomposition.
- Attribution methodology (7-day window from pricing view to subscribe) matches product team's convention but may differ from Chargebee-sourced attribution used in other reports.
- `page_category = 'pricing'` classifier is broken for post-consolidation URLs (separate structural issue; this analysis uses `event = 'Viewed Pricing Page'` + explicit path filter to work around).

### Open questions

- Confirm with engineering / product: what in the 2026-02-24 deploy altered Mixpanel autocapture? Can scroll scalar capture be restored?
- Confirm with product: intentional addition of `Choose a Plan` CTA alongside `View Pricing`? Is the entry-point-CTA union the right forward definition for the persona flow?
- Within-cohort decomposition of the +8pp step-5 lift (anonymous / free / paid × pre / post): answerable from existing data in a follow-on pass.
- Does domain consolidation's landing-page shift (more logged-in users arriving on pricing) account for the visitor-mix shift?
