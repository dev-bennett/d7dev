# Domain Consolidation Impact Analysis

## 5.5-Week Watermark — Read-out for Meredith Knott

Cutover: 2026-03-16 · Read-out date: 2026-04-24

---

## The Question

Domain consolidation went live 2026-03-16 (app.soundstripe.com merged under www.soundstripe.com via Fastly). Did it work?

PRD success criteria, verbatim:

- **Short-term:** "No loss of SEO traffic after migration (±5%)" — evaluable now
- **Long-term:** "20% overall increase in traffic from organic search (3–6 months post-launch)"

Today is 5.5 weeks post-cutover. The +20% goal applies on a 3–6 month horizon, so this read-out is a leading-indicator watermark on the short-term ±5% criterion.

---

## Why Difference-in-Differences

Two intuitive frames are wrong for this question:

- **Raw within-2026 pre/post** conflates consolidation impact with mean reversion from a Q1 trough.
- **Raw same-period YoY** conflates consolidation impact with 12-month company-state changes (paid ramp, content velocity, product mix). Soundstripe is in a different position than a year ago.

**Difference-in-differences (DID)** anchors 2026 against 2025 in BOTH pre-cutover and post-cutover windows, then takes the difference. The result is the **trajectory change at the cutover**, with seasonal and state-difference patterns differenced out.

2025 anchor windows are DoW-aligned (start on the same weekday as the corresponding 2026 window) so weekday/weekend mix is identical.

---

## Comparison Windows

| Window | Dates | Days |
|---|---|---|
| 2026 pre-cutover | 2026-01-19 → 2026-03-04 | 45 |
| 2025 pre (DoW-aligned) | 2025-01-20 → 2025-03-05 | 45 |
| 2026 post-cutover (clean) | 2026-03-26 → 2026-04-13 | 19 |
| 2025 post (DoW-aligned) | 2025-03-27 → 2025-04-14 | 19 |

Hard-excluded contamination zones:

- **2026-03-05 → 2026-03-25** — Fastly POP / pre-render artifact (~160K excess Direct sessions, engineer-confirmed root cause)
- **2026-04-14 → 2026-04-17** — APAC Direct spike, root cause pending engineering

---

## Headline: At Least +11pp Real Organic Lift

The conservative, defensible read on real organic-traffic incrementality is **+11pp DID at minimum**, with an upper bound of +26pp depending on how a concurrent Direct-channel shift is treated.

| Real organic-traffic incrementality | DID |
|---|---:|
| **Conservative floor** (assumes Direct decline is reclassification to Organic) | **+11pp** |
| Upper bound (assumes Direct decline is independent of cutover) | +26pp |

**PRD short-term ±5% criterion: MET on the upside even at the conservative floor.**

The lift is real and material. The two numbers are both defensible reads of the same underlying data; lead with +11pp where downside risk matters, +26pp where best-case framing is appropriate.

---

## Supporting Data: YoY Gap Closure

| | 2025 (DoW-aligned) | 2026 | YoY |
|---|---:|---:|---:|
| Pre-cutover (45d) | 9,203/day | 5,633/day | **−38.8%** |
| Post-cutover (19d) | 8,115/day | 7,075/day | **−12.8%** |
| **DID** | | | **+26.0pp** |

Before the cutover, 2026 Organic sessions were running 39% below 2025. After the cutover, 2026 is running 13% below 2025. The YoY gap closed 26 percentage points at the cutover.

Concurrently, **Direct sessions DID was −18.8pp** at the same cutover. Some of that decline is likely Fastly re-classifying Direct → Organic (the post-cutover environment captures Referer headers more consistently — Organic's referrer-NULL rate dropped from ~47% to ~34%). The +11pp floor on the prior slide is what survives if we attribute the entire Direct decline to reclassification.

---

## Mechanisms Considered

| Hypothesis | Verdict |
|---|---|
| H1 — Real consolidation-driven SEO uplift | Consistent. Non-branded organic +57%. New organic landing paths surge 7-10× post-cutover (mostly URL renames; some real new crawl). |
| H2 — Paid spend pulled back, attribution shifted to Organic | **Ruled out.** Paid spend went UP +50–75% post-cutover. |
| H3 — Seasonal pattern + 12-month state change | **Ruled out as dominant.** Pure seasonality predicts DID near zero, not a +26pp discontinuity at the cutover date. |
| H4 — Fastly Referer-handling re-classified Direct → Organic | Partial. Accounts for the +11 to +26pp range above. |
| H5 — 04-17 spike contaminating post-window | Ruled out. Spike sits outside the post window. |

---

## Acquisition Lift

Organic-driven new subscriptions, within-2026 pre/post:

- Pre-cutover average: **~58 / week**
- Post-cutover average (clean window): **~73 / week**
- **Delta: +30%**

Total new subscribers across all channels: **+17%**

Acquisition lift directionally mirrors the Organic-traffic DID. Small absolute base. Revenue/MRR omitted (subscription cohort lag exceeds the 5.5-week post-window).

---

## Open Structural Items

**1. 2026-04-14 → 2026-04-17 Direct spike — engineering confirmation pending**

APAC-concentrated (78% APAC vs 49% baseline), 21K Direct sessions/day vs 8K baseline. Tail elevated through 2026-04-24. Leading hypothesis: same Fastly/pre-render mechanism as March. Until confirmed, all reporting after 2026-04-13 carries a contamination caveat.

**2. Google Search Console not in the warehouse**

Direct SEO measurement (rank, impressions, CTR) is impossible from current warehouse data. Analysis relies on the Mixpanel organic-channel proxy. **Recommend prioritizing GSC ingest before the 12-week recheck.**

---

## Bottom Line

**The cutover closed 26pp of the YoY gap on Organic Search sessions. Real lift is at minimum +11pp YoY trajectory closure. PRD ±5% short-term criterion is met. PRD +20% long-term goal still needs another ~13pp of YoY-level closure over the next 5–10 weeks to land.**

**Next steps:**

1. Re-run this analysis at 12 weeks (2026-06-08) and 24 weeks (2026-08-31) using the same DID frame.
2. Engineering confirmation on the 2026-04-14 → 2026-04-17 spike.
3. Prioritize Google Search Console ingest for direct SEO measurement at 12-week recheck.
4. Adopt contamination-aware reporting frame for marketing dashboards covering 2026-03-05 → 2026-04-17.
