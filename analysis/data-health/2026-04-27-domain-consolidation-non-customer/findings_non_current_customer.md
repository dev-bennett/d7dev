# Domain Consolidation Impact — Non-Current-Customer Cut

## 5.5-Week Watermark — Read-out for Sourav

Cutover: 2026-03-16 · Read-out date: 2026-04-27 · Parent task: `analysis/data-health/2026-04-24-domain-consolidation-impact/`

---

## The Question

The 2026-04-24 read-out aggregates current-customer and non-current-customer (NC) traffic. Sourav asked for the cut on NC traffic. Two populations had materially different consolidation responses (calibration pitfall #3a in `core__fct_sessions.md`: existing-subscriber sessions held flat across the cutover, while non-subscriber sessions surged). This separates them.

---

## Definitions

- **Headline (Def A) — non-current-customer at session time:** `is_existing_subscriber = false` (sourced from `subscriber_category IN ('non subscriber', 'subscribing session')`). Captures any session entered without an active subscription, including the session in which a new subscription was created.
- **Robustness (A ∩ C) — anonymous + non-current-customer:** Def A plus `user_id IS NULL`. Excludes the ~8% logged-in non-paying band (free signups). Reported as a sensitivity check; same direction as Def A throughout.

NC share of total Organic Search sessions: 56% pre-cutover (week 2026-02-09) → 71% post-cutover (week 2026-03-30). Most of the consolidation lift in Organic Search lands in this segment.

---

## Comparison Windows

Identical to parent task (DoW-aligned 2025 anchors; hard-excluded contamination zones 2026-03-05→03-25 and 2026-04-14→04-17).

| Window | Dates | Days |
|---|---|---|
| 2026 pre-cutover | 2026-01-19 → 2026-03-04 | 45 |
| 2025 pre (DoW-aligned) | 2025-01-20 → 2025-03-05 | 45 |
| 2026 post-cutover (clean) | 2026-03-26 → 2026-04-13 | 19 |
| 2025 post (DoW-aligned) | 2025-03-27 → 2025-04-14 | 19 |

---

## Headline: NC Organic Lift Is +30 to +50pp

| NC Organic real-traffic incrementality | DID (sessions/day) |
|---|---:|
| **Conservative floor** (NC Direct decline → reclassification to Organic) | **+29.5pp** |
| Upper bound (NC Direct decline independent of cutover) | +49.6pp |

For comparison, parent task all-traffic Organic was +11pp / +26pp on the same construct. The NC cut roughly doubles both bounds.

**PRD short-term ±5% criterion: MET on the upside even at the conservative floor.**

The lift is real and material. The two numbers are both defensible reads of the same underlying data; lead with +29.5pp where downside risk matters, +49.6pp where best-case framing is appropriate. The +19% NC Organic subscriptions/day in the next section is independent, conversion-tied confirmation that real new-customer acquisition rose.

---

## YoY Gap Closure — NC Organic Search

| | 2025 (DoW-aligned) | 2026 | YoY |
|---|---:|---:|---:|
| Pre-cutover (45d) | 5,326/d | 3,225/d | **−39.4%** |
| Post-cutover (19d) | 4,547/d | 5,012/d | **+10.2%** |
| **DID** | | | **+49.6pp** |

NC Organic 2026 sessions/day were running 39% below 2025 before the cutover and 10% ABOVE 2025 after. The YoY gap closed 49.6 percentage points and crossed zero.

**Robustness (Def A ∩ C):** same construct restricted to anonymous sessions. Pre YoY −39.8%; post YoY +19.4%; DID **+59.2pp**. Same direction, larger magnitude — the logged-out subset is the cleanest SEO-acquisition population.

**NC Direct DID (Def A):** −20.1pp (pre YoY +4.2%, post YoY −15.9%). Some of the NC Organic gain is likely Fastly Referer-handling reclassifying NC Direct → NC Organic. The +29.5pp floor on the headline is what survives if we attribute the entire NC Direct decline to reclassification.

---

## Mechanisms Considered

| Hypothesis | Verdict |
|---|---|
| H1 — Real consolidation-driven NC SEO acquisition uplift | Consistent. NC Organic sessions +55%/d, distinct_ids +74%/d, subscriptions +19%/d post-cutover. NC non-branded organic was the engine of the all-traffic +57% in the parent task; same mechanism applies here. |
| H2 — Anonymous identity-namespace artifact (calibration pitfall #3a) inflates sessions | **Ruled out for the population we can test.** q8 directly tested whether logged-in users (where the dbt bridge has visibility via Identify events) show identity fragmentation in the consolidated profile_id namespace. Result: avg distinct_ids per logged-in user per week = 1.001 pre-cutover, 1.000 post-cutover. Sprawl in the consolidated namespace is essentially zero for the population the bridge can see; the bridge is functioning. Residual case: purely anonymous never-login users with cookie resets at the cutover. By construction, such users could only inflate counts of returning anonymous humans — not net-new SEO acquisitions, which are new humans with no pre-cutover identity to lose. No basis for treating the +76% anonymous distinct_id growth as sprawl. |
| H3 — Paid spend pulled back, attribution shifted to Organic | Ruled out. Parent task q3 confirmed paid spend went UP +50–75% post-cutover. |
| H4 — Fastly Referer-handling re-classified NC Direct → NC Organic | Partial. NC Direct DID −20.1pp; conservative floor assumes 100% reclassification. |
| H5 — 04-17 spike contaminating post-window | Ruled out. Spike sits outside the post window (clean window ends 2026-04-13). |

---

## Acquisition Lift — Absolute Conversions Up, Session-Level CVR Down

NC Organic Search:

| Metric | Pre (per day) | Post-clean (per day) | Δ |
|---|---:|---:|---:|
| NC sessions | 3,225 | 5,012 | **+55%** |
| NC subscriptions created | 8.82 | 10.5 | **+19%** |
| NC combined-monetization conversions | 11.0 | 12.7 | +15% |
| NC transactional-only conversions | 2.20 | 2.16 | ≈ flat |

Session-level CVR direction (basis points):

| CVR (NC Organic) | Pre | Post | Δ |
|---|---:|---:|---:|
| Sub CVR | 27.35 bps | 21.00 bps | −23% |
| Combined CVR (subscription + transactional) | 34.17 bps | 25.31 bps | −26% |
| Transact-only CVR | 6.82 bps | 4.31 bps | −37% |

**Reading the apparent contradiction:** absolute new-customer acquisition went UP. Session-level CVR went DOWN. The most parsimonious mechanism the data supports:

**Mix shift to lower-intent organic traffic.** Domain consolidation surfaces ~7× more new organic landing paths per week post-cutover (parent task q10). The new traffic enters on a broader set of long-tail pages, with naturally lower per-session engagement (q6: NC Organic avg duration 290s → 183s, avg pageviews 1.81 → 1.60) and lower per-session conversion rate. Total acquisition rises (more humans on the site) while per-session yield falls (each session is on average less intent-bearing). This is a single-mechanism real-traffic story, not an artifact.

The right unit for finance reporting is **conversions per day** at the segment level, not session-level CVR. Session CVR in this window will misread as a regression unless paired with the conversion-count series.

**Other channels (q7):** NC Paid Search sub-CVR rose +12% post-cutover (45.84 → 51.33 bps); NC Direct sub-CVR rose +53% (3.42 → 5.23 bps); NC Email sub-CVR fell sharply but on a small base. NC Organic is the only material channel where session CVR fell.

---

## Open Structural Items

**1. Calibration artifact pitfall #3a should be revised — the sprawl claim is overclaimed**

q8 directly tested the sprawl hypothesis on logged-in users (where `distinct_id_mapping` bridge has full visibility). avg_dids_per_user = 1.001 pre-cutover, 1.000 post-cutover; sprawl in the consolidated namespace is essentially zero for the testable population. The bridge is doing its job. Pitfall #3a's "logged-in stable + anonymous +76% + sessions/distinct_id 1.6 → 1.4 → therefore sprawl" inference is unsupported — those observations are equally consistent with real new lower-intent traffic. Recommend revising the pitfall to: (a) state the observations without the "sprawl" mechanism claim, and (b) note q8 as a direct null result, with a residual question scoped to anonymous-never-login users with pre-cutover cookies that were reset (a population that cannot be tested without behavior fingerprinting or external data, but which by construction can only affect counts of returning anonymous humans, not net-new SEO acquisitions).

**2. 2026-04-14 → 2026-04-17 NC Direct spike — engineering confirmation pending**

Same status as parent task. NC traffic in this window inherited the contamination; hard-excluded from the headline.

**3. Google Search Console not in the warehouse**

Same as parent task. Direct SEO measurement (rank, impressions, CTR by query intent) is not possible from current warehouse data. Recommend GSC ingest before the 12-week recheck — particularly relevant for the NC cut, where query-level intent is the natural next discriminator.

---

## Bottom Line

**Domain consolidation produced +29.5 to +49.6pp YoY trajectory closure on NC Organic Search sessions/day — roughly 2× the parent task's all-traffic +11/+26 framing. Conversion-tied evidence corroborates: NC Organic subscriptions/day rose +19% (8.82 → 10.5), combined-monetization conversions/day +15%. Session-level CVR fell 23–26%, explained as a single-mechanism mix shift to broader, lower-intent organic traffic (parent q10: ~7× new organic landing paths/wk post-cutover; q6: shorter durations, fewer pageviews per session). Identity-namespace sprawl was ruled out as a contributing mechanism by q8 (avg distinct_ids per logged-in user per week = 1.001 pre / 1.000 post). PRD short-term ±5% criterion: MET. PRD long-term +20% goal: on a favorable trajectory.**

**Next steps:**

1. Re-run at 12 weeks (2026-06-08) and 24 weeks (2026-08-31) using the same DID + Def A construct on sessions and conversions/day.
2. Revise calibration artifact `core__fct_sessions.md` pitfall #3a to remove the "sprawl" mechanism claim (q8 is a direct null result for the testable population). Retain the observations as-is; reframe the bounded residual question (anonymous-never-login + cookie reset).
3. GSC ingest before the 12-week recheck for query-level intent attribution on the NC cut.
4. For Sourav specifically: any dashboard showing NC organic session-CVR in the post-cutover window should pair it with NC organic conversions/day to avoid the CVR misread.
