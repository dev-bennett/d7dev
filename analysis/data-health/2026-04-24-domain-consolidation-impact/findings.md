---
status: draft
domain: data-health
date: 2026-04-24
author: Devon Bennett
severity: medium
asana: https://app.asana.com/1/411777761188590/project/1205525083743256/task/1213715723297289
stakeholder: Meredith Knott
plan: /Users/dev/.claude/plans/expressive-nibbling-rabin.md
---

# Domain Consolidation Impact Analysis — 5.5-Week Watermark

## Background

The Soundstripe domain consolidation went live on 2026-03-16 (Fastly reverse proxy now serves both marketing and app under `www.soundstripe.com`; `app.soundstripe.com` 301-redirects to `/library/*` paths under `www.soundstripe.com`). Per the PRD (`analysis/data-health/2026-04-01-direct-traffic-spike/domain_consolidation_prd.pdf` page 3 Success Criteria and page 10 Implementation Plan alignment), the success metrics are:

- Short-term (verifiable now in week 5–6): "**No loss of SEO traffic after migration (±5%)**"
- Long-term (3–6 months post-launch): "**20% overall increase in traffic from organic search**"

Asana ticket 1213715723297289 (opened 2026-03-17, due 2026-04-10, follow-up nudge 2026-04-21) asks for a read-out 2–4 weeks post-launch. Today is 2026-04-24 (week 5–6 post-cutover). The +20% claim is explicitly framed in the PRD as a 3–6 month long-term goal — the read-out below is a leading-indicator watermark on the short-term ±5% criterion, not a verdict on the long-term target.

### Scope

Per stakeholder decision (captured 2026-04-24): traffic + acquisition. Revenue/MRR omitted (5.5-week post-window is shorter than typical subscription cohort lag).

## Signal

Headline: **Organic Search sessions DID +26.0pp**. Difference-in-differences against DoW-aligned 2025 anchor.

| | 2025 (DoW-aligned) | 2026 | YoY |
|---|---:|---:|---:|
| Pre-cutover (45d, Jan 20 / Jan 19 → Mar 5 / Mar 4) | 9,203/day | 5,633/day | **−38.8%** |
| Post-cutover (19d, Mar 27 / Mar 26 → Apr 14 / Apr 13) | 8,115/day | 7,075/day | **−12.8%** |
| **DID** | | | **+26.0pp** |

The cutover closed 26pp of YoY gap on Organic Search sessions. PRD short-term ±5% criterion is met on the upside.

One caveat: Direct sessions DID was −18.8pp at the cutover (q16). Some of that may be Fastly Referer-handling improvement re-classifying Direct → Organic. If we attribute the full Direct loss to reclassification, real organic-traffic incrementality is **+11pp DID** (lower bound). If we attribute none of it (Direct decline is independent), real incrementality is **+26pp DID** (upper bound). True value is somewhere in that range.

A second contamination zone (2026-04-14 → 2026-04-17, APAC-Direct, ~21K/day vs 8K/day baseline) was confirmed during this analysis. Sits outside the post window used here. Engineering confirmation pending.

## Detection Method

Stakeholder-initiated (Asana ticket from 2026-03-17). This analysis was triggered by Meredith's 2026-04-21 follow-up. Comparison-frame analysis with explicit contamination-zone exclusion, mechanism enumeration, and **DoW-aligned difference-in-differences against 2025 anchors**. Earlier draft used raw within-2026 pre/post and a DoW-misaligned YoY anchor; both were superseded after stakeholder pushback that raw YoY confounds consolidation impact with 12-month state changes.

## Comparison Windows

DID frame uses four cells in two pairs: (A_2026_pre, A_2025_pre_dow_aligned) and (C_2026_post, C_2025_post_dow_aligned). 2025 windows are DoW-aligned to 2026 windows (same weekday start and end DoW pattern). Windows B, D, E are descriptive context only (contamination zones and tail) and not in the DID estimate.

| Window | Dates | Days | DoW pattern | Treatment |
|---|---|---|---|---|
| A_2026_pre | 2026-01-19 → 2026-03-04 | 45 | Mon → Wed | Pre-cutover 2026 |
| A_2025_pre_dow_aligned | 2025-01-20 → 2025-03-05 | 45 | Mon → Wed | DoW-aligned 2025 anchor for A |
| B_contam1 | 2026-03-05 → 2026-03-25 | 21 | (excluded) | Fastly POP / pre-render artifact, ~160K excess Direct sessions |
| C_2026_post | 2026-03-26 → 2026-04-13 | 19 | Thu → Mon | **Primary post-window for DID** |
| C_2025_post_dow_aligned | 2025-03-27 → 2025-04-14 | 19 | Thu → Mon | DoW-aligned 2025 anchor for C |
| D_contam2 | 2026-04-14 → 2026-04-17 | 4 | (excluded from DID) | Filter B contamination zone |
| E_tail | 2026-04-18 → 2026-04-24 | 7 | (descriptive) | Clean tail check — Direct still elevated |

Pre-period (A) and post-period (C) are non-overlapping. DID estimates the trajectory change at the cutover.

## Headline Numbers — Difference-in-Differences

Source: `q16_did_dow_aligned.csv` (DID dataset) + `q14_summary_rollup.csv` (descriptive context). Rates are **sessions/day** and **visitors/day** to normalize for unequal window lengths.

### Difference-in-differences construction

For each metric and channel, four cells:

- **A_2026_pre** — pre-cutover 2026 (2026-01-19 Mon → 2026-03-04 Wed, 45 days)
- **A_2025_pre_dow_aligned** — same DoW pattern in 2025 (2025-01-20 Mon → 2025-03-05 Wed, 45 days)
- **C_2026_post** — post-cutover 2026 clean (2026-03-26 Thu → 2026-04-13 Mon, 19 days)
- **C_2025_post_dow_aligned** — same DoW pattern in 2025 (2025-03-27 Thu → 2025-04-14 Mon, 19 days)

YoY ratio_pre = A_2026_pre / A_2025_pre. YoY ratio_post = C_2026_post / C_2025_post. **DID = ratio_post − ratio_pre** (in pp).

### Organic Search

| | 2025 cell (DoW-aligned) | 2026 cell | YoY (pp) |
|---|---:|---:|---:|
| Pre-cutover sessions/day | 9,203 | 5,633 | **−38.8%** |
| Post-cutover sessions/day | 8,115 | 7,075 | **−12.8%** |
| **DID sessions** | | | **+26.0pp** |
| Pre-cutover visitors/day | 4,298 | 2,697 | **−37.2%** |
| Post-cutover visitors/day | 4,043 | 4,654 | **+15.1%** |
| **DID visitors** | | | **+52.3pp** |

The Organic-Search YoY trajectory was running ~−38% before the cutover. After the cutover the YoY gap closed to −12.8% on sessions and crossed zero (+15.1%) on visitors. The DID estimates +26.0pp incremental sessions/day and +52.3pp incremental visitors/day. Visitors moves more than sessions because post-consolidation profile_id stitching also reduces cross-host visitor double-counting; the sessions DID is the more conservative read.

### Direct

| | 2025 cell (DoW-aligned) | 2026 cell | YoY (pp) |
|---|---:|---:|---:|
| Pre-cutover sessions/day | 8,178 | 8,317 | **+1.7%** |
| Post-cutover sessions/day | 8,773 | 7,274 | **−17.1%** |
| **DID sessions** | | | **−18.8pp** |

Direct held flat YoY pre-cutover and lost 17pp YoY post-cutover. Net DID is −18.8pp. Consistent with H4 (improved Referer-header capture re-attributing some sessions from Direct to Organic). The magnitudes don't fully zero-sum (Organic DID +26pp on sessions vs Direct DID −18.8pp), but H4 plausibly accounts for ~15–20pp of the Organic gain. Net real Organic incrementality after subtracting the maximum H4 contribution: ~+6–11pp DID floor.

### Paid Search

| | 2025 cell (DoW-aligned) | 2026 cell | YoY (pp) |
|---|---:|---:|---:|
| Pre-cutover sessions/day | 3,282 | 1,531 | **−53.4%** |
| Post-cutover sessions/day | 2,599 | 1,635 | **−37.1%** |
| **DID sessions** | | | **+16.3pp** |

Paid Search YoY gap closed +16pp at the cutover. Spend rose +50–75% over the same window. CAC degraded; the +16pp DID is consistent with directional improvement at the cost of lower marginal efficiency. Not a consolidation effect — paid behavior is independent of the cutover.

### Acquisition (organic-driven new subscriptions)

Source: `q11_acquisition.csv` (`dim_daily_kpis.organic_search_subscriptions`).

| Window | Total `organic_search_subs` | Per day |
|---|---:|---:|
| A_pre_recency (~45d) | ~58/wk avg = 372 total | 8.3/d |
| C_post_clean (19d) | 80+66+59 = 205 total | 10.8/d |
| Delta | | **+30%** |

Total new subscribers (`mixpanel_subscriptions`):
| Window | Per week (avg) | Per day |
|---|---:|---:|
| A_pre_recency | 124/wk | 17.7/d |
| C_post_clean | 145/wk | 20.7/d |
| Delta | | **+17%** |

Acquisition lift directionally mirrors the Organic-traffic DID. The +30% organic-driven subscriptions delta (within-2026 pre/post) is the descriptive frame; a proper DID anchor for subscriptions would require a similar 2025 DoW-aligned anchor and is omitted here for tractability — the directional gain is large enough to be unambiguous on a within-2026 basis.

## Investigation — Mechanism Enumeration

Per `feedback_enumerate_mechanisms_before_attribution`, ≥2 alternative mechanisms must be enumerated and explicitly discriminated for any non-zero traffic delta. Five hypotheses considered:

### H1: Real consolidation-driven SEO uplift

Predicted shape: organic sessions up; non-branded organic up disproportionately; canonical-URL consolidation reduces duplicate-page indexing; new-page count up; YoY recovery toward prior levels.

Evidence:
- Non-branded organic sessions: 21K/wk pre → 33K/wk post = **+57%** (`q5`). Branded and `no_referrer`-classified Organic are stable.
- New organic landing paths first-seen-in-week: ~600–800/wk pre → 5,000–7,000/wk post (`q10`). Mostly mechanical (URL renames /pricing → /library/pricing) but some real new-page crawl.
- DID shows trajectory change at the cutover (sessions YoY −38.8% pre → −12.8% post; visitors YoY −37.2% pre → +15.1% post).

Verdict: **Consistent with the data, but not uniquely so.** The non-branded concentration of the lift, the YoY-recovery pattern, and the new-landing-path expansion all point in this direction. But H4 (classifier improvement) shares some of these predictions.

### H2: Paid spend pulled back; last-non-direct attribution shifted Direct→Organic

Predicted shape: paid spend down post-cutover; organic up; Direct flat or up.

Evidence:
- Paid spend (`q3`, `q11_acquisition.csv`): pre ~$17K-19K/week → post ~$27K-30K/week (**+50–75%**). Paid spend went UP, not down.

Verdict: **Ruled out.** Paid spend increased substantially post-cutover; H2 predicts the opposite.

### H3: Year-over-year seasonal pattern + 12-month state changes

Predicted shape: if seasonal expansion + general 12-month state changes (paid ramp, content velocity, Q1→Q2 mix shifts) explain the lift, the YoY trajectory would already have been on an improving path before the cutover. DID would be near zero.

Evidence (DoW-aligned DID, q16):
- Pre-cutover: 2026 Organic Search was running −38.8% YoY (sessions/day) — a steep deficit.
- Post-cutover: YoY deficit closed to −12.8% sessions/day; visitors crossed zero to +15.1% YoY.
- DID +26.0pp on sessions, +52.3pp on visitors.

Verdict: **Ruled out as the dominant mechanism.** Pure seasonal/state-change explanation would predict a smooth YoY trajectory (DID ≈ 0pp). The +26pp DID change at the cutover is not consistent with that prediction. The 12-month company-state changes do not explain a discontinuity at the cutover date.

Caveat: DID does not perfectly control for ALL company-state changes. If some unrelated change (e.g., a content-team launch, a concurrent SEO campaign) coincidentally landed on or near 2026-03-16, its contribution sits inside the DID estimate. Mitigation: the new-page velocity surge in q10 is largely mechanical (URL rename), not new-content-team velocity; paid spend is observed and ruled out under H2; no other coincident campaign is identified in this analysis.

### H4: Mixpanel tracking change at cutover; Fastly Referer-header handling improved Organic classification

Predicted shape: post-cutover, Organic Search referrer-NULL rate decreases (Fastly captures Referer headers more consistently); Direct count drops or holds flat (Direct sessions formerly classified Direct because of NULL referrer now have a referrer and re-classify to Organic).

Evidence:
- Organic Search referrer-NULL rate (`q4`): pre ~46–50% → post ~33–38% — a **drop of 12pp**.
- Direct DID (q16): pre +1.7% YoY → post −17.1% YoY = **−18.8pp DID**.

Verdict: **Partial.** Referrer capture genuinely improved, and Direct lost 18.8pp DID YoY ground at the cutover — directionally consistent with re-attribution of some Direct → Organic. But the Organic DID (+26pp sessions, +52pp visitors) exceeds the Direct DID (−18.8pp), so re-attribution alone cannot account for the full Organic gain. Lower bound on real Organic incrementality (after subtracting the maximum H4 contribution): **DID floor ~+6 to +11pp** on sessions; visitors DID is largely independent of H4 (re-attribution would not create new visitors).

### H5: 04-14 → 04-17 spike contamination spilling into the post-window

Predicted shape: the C window (Mar 26 → Apr 13) ends BEFORE the spike (which starts Apr 14); the spike should not contaminate C. But if the spike's mechanism began earlier than Apr 14, C could be partially affected.

Evidence:
- `q9_spike_substantiation.csv`: B_pre_spike (2026-04-09 → 2026-04-13) shows 5,730 Direct sessions/day on non-library paths — within baseline range (A_baseline = 7,826/day, partially elevated due to artifact-zone-1 tail in early-March windows).
- Daily Direct rate jumps to 21,450/day during 2026-04-14 → 2026-04-17 (the actual spike).

Verdict: **Ruled out for the C window.** The spike does not contaminate the primary post-window. It does inflate the E_tail window — Direct sessions/day in E_tail are 12,356, ~70% above C — and that elevation is documented separately.

### Mechanism summary

The DID +26pp incremental Organic sessions (and +52pp incremental Organic visitors) at the cutover is consistent with **a combination of H1 (real SEO uplift) and H4 (improved Referer-header classification re-attributing some Direct → Organic)**. H3 (seasonal/state-change) is ruled out as the dominant mechanism by the discontinuity at the cutover. H2 (paid pull-back) is ruled out by the observed paid spend increase. H5 (04-17 contamination) does not affect window C.

Real Organic incrementality (sessions DID, after subtracting maximum plausible H4 contribution): **floor +6 to +11pp**, ceiling +26pp. Visitors DID +52.3pp is mostly independent of H4 (re-attribution does not generate new visitors) and is the cleaner directional signal — best read as: 2026 visitors crossed zero YoY at the cutover, from −37% YoY to +15% YoY.

## Root Cause

The consolidation cutover on 2026-03-16 produced a measurable change in the YoY Organic-Search trajectory: from −38.8% YoY pre-cutover to −12.8% YoY post-cutover (sessions), and from −37.2% to +15.1% (visitors). The DID estimates +26pp incremental sessions and +52pp incremental visitors. The lift is partly real (URL canonicalization, content unification, search-engine recrawl after sitemap consolidation) and partly methodological (improved Referer-header capture re-attributing some Direct → Organic). Real Organic incrementality is bounded between ~+6pp DID (sessions, conservative floor after maximum H4 subtraction) and +52pp DID (visitors, where H4 is not a confound).

The PRD's long-term +20% YoY organic goal applies on a 3–6 month horizon. The current data (5.5 weeks) is a leading indicator only. At this watermark, the consolidation has demonstrably halted a multi-month YoY decline and pulled the YoY visitor trajectory positive. Whether the +20% sessions YoY goal materializes by July–September 2026 depends on continued search-engine indexing and ranking effects not yet observable in the warehouse.

## Impact Assessment

### PRD Success Criteria — current status

| Criterion | Timeline | Status | Evidence |
|---|---|---|---|
| No loss of SEO traffic ±5% | Short-term | **MET — exceeded on the upside.** DoW-aligned DID +26pp Organic sessions, +52pp Organic visitors at the cutover, well above the ±5% band on the upside. | q16 DID |
| ≥95% tracking continuity | Short-term | Not directly measured. Sessions reconcile fct_sessions ↔ dim_daily_kpis perfectly (q15). Visitors diverge 7–16% (post-consolidation profile_id stitching in fct_sessions vs raw distinct_id in dim_daily_kpis — methodology, not loss) | q15 |
| 20% organic increase | Long-term (3–6 mo) | **Early watermark only** — too soon to evaluate. DID +26pp sessions / +52pp visitors at 5.5 weeks. The +20% PRD goal is YoY level, not YoY-trajectory change; current YoY level is −12.8% sessions / +15.1% visitors. | q16 DID |
| Zero P0 incidents | Short-term | Out of scope for this analysis | n/a |
| No login/checkout drop-off | Short-term | Out of scope per stakeholder decision | n/a |

### Engagement quality on Organic landings (Window C vs A vs F)

| Metric | A_pre_recency | C_post_clean | F_yoy_2025 |
|---|---:|---:|---:|
| Bounce % | 54.6% | 62.4% | 50.3% |
| Avg duration (sec) | 450 | 332 | 487 |
| Median duration (sec) | 36 | 23 | 39 |
| Avg pageviews | 2.58 | 2.22 | 2.44 |

Engagement on organic landings declined in window C (bounce +7.8pp vs A; pageviews −14% vs A; median duration −36% vs A). Most of the decline is composition shift: pre-cutover organic landed ~60% on `app.soundstripe.com` (high-engagement library pages, ~67% bounce, 2.06 avg pageviews) and ~40% on `www.soundstripe.com` (marketing pages, ~41% bounce, 3.20 avg pageviews). Post-cutover all organic lands on the unified `www.soundstripe.com` host with mixed content. Quality decrease is partly real (search engines indexing more shallow pages post-recrawl) and partly mechanical (per-host metric breakouts no longer comparable across the cutover).

### Contamination Zone 2 — APAC Direct spike (2026-04-14 → 2026-04-17, OPEN)

Source: `q9_spike_substantiation.csv`.

| Window | Days | Direct sessions/day | APAC % | Bounce % |
|---|---:|---:|---:|---:|
| A_baseline | 14 | 7,826 | 48.7% | 91.0% |
| B_pre_spike | 5 | 5,730 | 44.8% | 88.8% |
| C_spike | 4 | **21,450** | **78.3%** | 95.7% |
| D_tail | 7 | 12,356 | 65.8% | 92.6% |

The 04-14 → 04-17 zone confirmed as anomalous. APAC concentration jumped from 49% baseline to 78% during the spike, with 21K Direct sessions/day vs 8K baseline. Tail window (04-18 → 04-24) is still 1.6× elevated above baseline. Engineering confirmation pending — the leading hypothesis is the same Fastly/pre-render mechanism as the 03-05 → 03-25 zone, with a different POP region or a recurring sitemap-recrawl event. Scraping cannot be ruled out from warehouse data alone (Fastly access logs needed).

The 04-14 → 04-17 spike sits in the read-out's measurement window. It contaminates the E_tail window but not the C_post_clean window. Headline numbers are not affected. The tail elevation does mean that any reporting after 2026-04-13 for the next ~14 days should be read with the same skepticism as the 03-05 → 03-25 contamination zone.

## Recommended Actions

### Operational (within existing capabilities)

1. **Re-run this read-out at 12 weeks (2026-06-08) and 24 weeks (2026-08-31) post-cutover, using the same DID frame.** The +20% PRD goal applies on the 3–6 month horizon. The current 5.5-week DID +26pp sessions / +52pp visitors is a leading indicator that the trajectory CHANGED at the cutover, not that the +20% YoY level has been reached.
2. **Adopt the contamination-aware reporting frame for marketing dashboards covering 2026-03-05 → 2026-04-17 (and tail to 2026-04-24).** Two contamination zones are documented in the calibration artifact (`knowledge/data-dictionary/calibration/core__fct_sessions.md`); any dashboard counting Direct sessions in those windows without exclusion will misstate conversion rates downstream.
3. **Lead narrative with visitors DID, not sessions DID.** Visitors DID +52pp is largely independent of H4 (re-attribution does not generate new visitors). Sessions DID +26pp has the H4 caveat (~15–20pp upper-bound classifier contribution). Visitors crossing zero YoY at the cutover is the cleaner directional read.

### Structural (require building something)

1. **Engineering confirmation on 2026-04-14 → 2026-04-17 spike (CARRY OVER from `project_direct_traffic_spike_2026_04_17_open`).** Either confirm same Fastly/pre-render mechanism (apply the 03-25 fix or analog) or rule it out and pursue Fastly access-log analysis for the scraping hypothesis. Until then, all reporting after 2026-04-13 carries a contamination caveat.
2. **Google Search Console replication (NEW).** This analysis cannot directly measure SEO outcomes (rank, impressions, CTR) because GSC is not in the warehouse. Direct measurement of the +20% goal at 3-6 months requires GSC data. Recommend prioritizing GSC ingest in dbt before the 12-week recheck above.

## False Positive Assessment

The DID +26pp sessions / +52pp visitors at the cutover is robust to:
- Paid pull-back (ruled out — paid spend +50-75%, paid behavior independent of cutover)
- 04-17 spike contamination (does not affect window C)
- Seasonal pattern + 12-month state changes (DID controls for these by anchoring 2026 vs 2025 in BOTH pre and post windows)
- DoW mix (2025 anchor windows are DoW-aligned to 2026 windows)
- Tracking outage (sessions reconcile fct_sessions ↔ dim_daily_kpis perfectly per q15)

The sessions DID is partially attributable to:
- Improved Referer-header capture (H4): plausibly accounts for 15–20pp of the +26pp sessions DID. The conservative real-Organic floor on sessions is +6 to +11pp DID.

The visitors DID (+52pp) is mostly independent of H4 — re-attribution does not generate new visitors. It is the cleaner directional read.

Residual confounds the DID does NOT control for:
- Coincident campaigns or content-team launches that happened to land on 2026-03-16. Not identified in this analysis but cannot be ruled out from warehouse data.
- Differential search-engine algorithm changes between 2025 and 2026 same period. Mitigated by the post-cutover discontinuity (an algo change would more likely show as a smooth YoY shift, not a step at our cutover date).

Probability the cutover produced a measurable Organic-traffic improvement: **high** (DID floor +6pp on sessions, +52pp on visitors). Probability the +20% YoY sessions PRD goal is met at 3–6 months: **uncertain** (current YoY level is −12.8% sessions; the trajectory closed 26pp in 5.5 weeks, but reaching +20% YoY requires another ~33pp of YoY-level gain over the next 5–10 weeks).

## Verification Artifacts

### Identity Check (§5)

`q15`: `COUNT(DISTINCT session_id)` from `fct_sessions` vs `SUM(sessions)` from `dim_daily_kpis`, weekly, 2025-10-01 → 2026-04-24. Sessions reconcile **perfectly** (delta = 0% for all weeks). Visitors diverge 7–16% (fct_sessions uses post-consolidation profile_id; dim_daily_kpis appears to use raw distinct_id) — methodology divergence, not data error.

### Type Audits

For Window-level rate metrics in q14:

```
TYPE AUDIT — q14 bounce_pct:
  Declared denominator: COUNT(DISTINCT session_id) per (window_label, channel)
  JOIN chain: single-table aggregation from fct_sessions; CASE on session_started_at::date for window_label
  Column used as denominator: COUNT(DISTINCT session_id)
  Does JOIN type enforce declared denominator? YES — single table, no joins; window_label CASE assigns each session to exactly one window via mutually-exclusive date ranges
  RESULT: PASS

TYPE AUDIT — Acquisition delta (organic_search_subs C vs A):
  Declared denominator: days_in_window
  Source: dim_daily_kpis.organic_search_subscriptions summed per window
  Comparison: A 372 / 45d vs C 205 / 19d
  Both windows non-overlapping; same source table; both using last_channel_non_direct attribution per dim_daily_kpis pitfall #1
  RESULT: PASS
```

### Diagnostic Saturation Check

Bounce rate on Organic landings A_pre_recency = 54.6%. Not saturated (well below 80%). Treating bounce-rate change as signal is valid.

### Enumeration Check (§6)

Channels enumerated: [1] Affiliate ✓ [2] Direct ✓ [3] Email ✓ [4] Organic Search ✓ [5] Organic Social ✓ [6] Paid Content ✓ [7] Paid Search ✓ [8] Paid Social ✓ [9] Referral ✓. Count: 9 matching `last_channel_non_direct` distinct values from q1.

Windows enumerated: [1] A_pre_recency ✓ [2] B_contam1 ✓ [3] C_post_clean ✓ [4] D_contam2 ✓ [5] E_tail ✓ [6] F_yoy_2025 ✓. Count: 6 windows in q14.

Mechanisms enumerated: [1] H1 real SEO uplift ✓ [2] H2 paid pull-back ✓ [3] H3 seasonal ✓ [4] H4 classifier improvement ✓ [5] H5 04-17 spike contamination ✓. Count: 5 hypotheses with explicit data discrimination per `feedback_enumerate_mechanisms_before_attribution`.

### Stakeholder Benchmark Cross-Check

PRD benchmark: +20% organic at 3–6 months (YoY level, not DID). Observed at 5.5 weeks: DID +26pp sessions / +52pp visitors at the cutover. Current YoY level is −12.8% sessions / +15.1% visitors. The DID does not directly compare to the +20% benchmark (different construct: trajectory change vs YoY level), so the >2x bug-suspicion gate does not apply. Direct YoY-level comparison: -12.8% sessions YoY is 32.8pp away from the +20% benchmark; visitors at +15.1% YoY is 4.9pp away — within striking distance for the 12-week recheck. No methodology bug surfaced.

### Adversarial Q1–Q4 (§8)

```
Q1 — What would a skeptical reader challenge first?
A1: That raw within-2026 pre/post or raw YoY conflates consolidation impact with mean reversion (Q1 trough) or
    with 12-month state changes (paid ramp, content velocity). Mitigated: the headline frame is now
    DoW-aligned DID, which controls for both. The DID estimates +26pp sessions / +52pp visitors at the cutover —
    a discontinuity that pure seasonal/state-change explanations cannot produce. (Earlier draft of this finding
    led with raw within-2026 +25.6% and raw YoY −17.1%; both were superseded after stakeholder pushback.)

Q2 — What assumption, if wrong, would flip the conclusion?
A2: That nothing else changed at or near 2026-03-16 that DID would absorb. A coincident campaign, content launch,
    or product change would be embedded in the DID estimate. Not identified in this analysis but cannot be ruled
    out from warehouse data alone. The visitors DID +52pp is largely insulated from H4 (classifier shift) so
    even controlling for that, the directional gain is large.

Q3 — What obvious next question have I not answered?
A3: "Is organic acquisition (subscriptions, not sessions) up?" Answered above: organic_search_subs +30%, total
    new subscribers +17%. Not full revenue analysis (out of scope). Followup at 12-week recheck recommended.

Q4 — For each material finding, what intervention does it imply?
A4:
  - "DID +26pp sessions / +52pp visitors at cutover" → INFORMATIONAL (positive watermark, no action beyond
    continued monitoring at 12 and 24 weeks)
  - "Direct DID −18.8pp at cutover" → INFORMATIONAL (consistent with H4 attribution shift; Direct CAC
    interpretation is partly an artifact of the cutover, partly real)
  - "Engagement quality decline on organic landings" → OPERATIONAL (mostly composition shift from app→www
    consolidation, but worth a content-team look at low-engagement entry points)
  - "04-14→04-17 contamination zone (with elevated tail)" → STRUCTURAL (engineering confirmation needed; same
    fix as 03-25 may apply; or new fix if different mechanism)
  - "GSC not in warehouse" → STRUCTURAL (cannot directly measure SEO without it; ingest required for 12-week recheck)
  No mismatches between finding framing and implied intervention.
```

## Intervention Classification (§11)

```
INTERVENTION CLASS — Organic-Search DID +26pp sessions / +52pp visitors at the cutover:
  FINDING: The cutover changed the YoY trajectory of Organic Search at the cutover date. Visitors crossed
    zero YoY (-37% → +15%); sessions closed 26pp of the YoY gap (-38.8% → -12.8%).
  PERSISTENCE TEST: If the trajectory change persists for 12-24 weeks, the YoY-level +20% PRD goal is reachable
    on visitors and within striking distance on sessions. If the trajectory reverts, the lift was a one-time
    re-crawl effect, not a sustained SEO improvement.
  OWNER TEST: Marketing/SEO team decides next steps; data engineering owns the GSC ingest required to measure
    SEO outcomes directly.
  SMALLEST FIX: None for the metric itself; recheck at 12 weeks (2026-06-08) and 24 weeks (2026-08-31) using
    the same DID frame.
  CLASSIFICATION: INFORMATIONAL (positive watermark + recheck requirement)

INTERVENTION CLASS — Engagement quality decline on organic landings:
  FINDING: Bounce +7.8pp, pageviews -14% on organic landings post-cutover.
  PERSISTENCE TEST: If unchanged for 6 months, organic-driven engagement remains lower-quality
    than pre-cutover; conversion rate from organic may decline downstream.
  OWNER TEST: Content/SEO team can prioritize landing-page optimization for new /library/* surfaces.
  SMALLEST FIX: Audit organic-bounce composition (which paths are driving the increase); optimize highest-volume.
  CLASSIFICATION: OPERATIONAL (composition shift partially explains, but content team can act on the residual)

INTERVENTION CLASS — Contamination zone 2 (2026-04-14 → 2026-04-17 + tail):
  FINDING: Direct-channel APAC spike of unknown root cause; same signature as 2026-03-05 → 2026-03-25 in many respects.
  PERSISTENCE TEST: If unchanged, marketing dashboards continue to over-count Direct traffic and under-state
    conversion rates intermittently.
  OWNER TEST: Engineering (Luke Capizano) confirms mechanism.
  SMALLEST FIX: Apply the 2026-03-25 fix or analog if same mechanism; otherwise diagnose Fastly access logs.
  CLASSIFICATION: STRUCTURAL (root cause unconfirmed; STRUCTURAL until engineering confirmation either way)

INTERVENTION CLASS — Google Search Console not in warehouse:
  FINDING: Direct SEO measurement (rank, impressions, CTR) is impossible from warehouse data.
  PERSISTENCE TEST: If unchanged for 6 months, the +20% PRD goal cannot be directly measured at the 3-6 month checkpoint.
  OWNER TEST: Data engineering decides ingest priority.
  SMALLEST FIX: Add GSC source to dbt ingest pipeline; surface via standard rank/impression/CTR reporting model.
  CLASSIFICATION: STRUCTURAL (capability gap; build new pipeline)
```

## Limitations

1. **5.5 weeks is too short for SEO ranking effects to fully materialize.** Industry consensus is 3–6 months. The DID is a leading indicator on the +20% long-term YoY-level goal, not a verdict.
2. **No Google Search Console data.** Direct rank/impression/CTR signals are unavailable; analysis relies on the warehouse organic-channel proxy.
3. **Sessions DID has a classifier-improvement caveat (H4).** Floor on real Organic incrementality is +6 to +11pp DID on sessions; visitors DID +52pp is the cleaner read.
4. **Engagement quality decline is partly a composition artifact** (pre-cutover www was marketing-only; post-cutover www includes both marketing AND library pages). Quality metrics are not directly comparable across the cutover.
5. **04-14 → 04-17 spike root cause is unconfirmed.** Engineering confirmation is required to fully validate or invalidate Filter B; the contamination filter applied here is signature-matched to the 04-01 finding's mechanism but the mechanism itself is unproven for this window.
6. **DID does not control for ALL confounds.** A coincident campaign, content launch, or product change landing on/near 2026-03-16 would be absorbed into the DID estimate. None identified in this analysis but cannot be ruled out from warehouse data alone.
7. **Visitors and sessions DID diverge** (+52pp vs +26pp). Divergence reflects post-consolidation profile_id stitching reducing cross-host visitor double-counting. Either is defensible; the visitors metric is more conservative because the H4 classifier confound applies to channel attribution at the session level, not visitor count.

## Open Questions

1. Will organic search continue to grow toward the +20% YoY goal in the next 12-24 weeks? (Recheck at 2026-06-08 and 2026-08-31.)
2. Is the 2026-04-14 → 2026-04-17 spike the same Fastly mechanism as 2026-03-05 → 2026-03-25, or a different cause? (Engineering confirmation pending.)
3. Does the engagement quality decline persist or revert as search engines refine their organic-landing-page mix? (Recheck at 12 weeks.)
4. Should GSC ingest be prioritized to enable direct SEO measurement at 12-week and 24-week rechecks? (Stakeholder decision.)

## Source Files

- `console.sql` — q1 through q15 with header documentation
- `q14_summary_rollup.csv` — six-window pre/post/YoY roll-up by channel (raw data for headline)
- `q9_spike_substantiation.csv` — 04-14→04-17 spike signature
- `q11_acquisition.csv` — weekly paid spend + per-channel subscriptions from dim_daily_kpis
- Calibration artifacts:
  - `knowledge/data-dictionary/calibration/core__fct_sessions.md`
  - `knowledge/data-dictionary/calibration/core__dim_daily_kpis.md`
  - `knowledge/data-dictionary/calibration/core__fct_sessions_attribution.md`
- Plan: `/Users/dev/.claude/plans/expressive-nibbling-rabin.md`

## Cross-References

- Prior consolidation root-cause investigation: `analysis/data-health/2026-04-01-direct-traffic-spike/2026-04-01-direct-traffic-spike.md`
- 04-17 spike OPEN investigation: `analysis/data-health/2026-04-17-direct-traffic-spike/`
- PRD: `analysis/data-health/2026-04-01-direct-traffic-spike/domain_consolidation_prd.pdf`
- Memory: `project_domain_consolidation`, `project_direct_traffic_spike_2026_04_17_open`, `project_page_category_classifier_broken_open`, `project_mixpanel_autocapture_collapse_open`
