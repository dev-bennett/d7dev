# Domain Consolidation Impact Analysis — 5.5-Week Watermark

Format: ready-to-paste into Asana. Platform-safe (no bare dollar signs, no backticks, no angle brackets).

---

## Title

Read-out: Domain Consolidation Impact — Traffic and Acquisition (5.5-Week Watermark)

---

## Description

Per Meredith Knott's request (Asana ticket from 2026-03-17, 04-21 nudge): impact analysis of the 2026-03-16 domain consolidation cutover. Today is 2026-04-24, week 5–6 post-cutover.

Two PRD success criteria are in scope:

- Short-term, evaluable now: "No loss of SEO traffic after migration (within plus or minus 5 percent)"
- Long-term, evaluable at 3–6 months: "20 percent overall increase in traffic from organic search"

The analysis is framed as a leading-indicator watermark on the short-term criterion. The 20 percent organic increase is explicitly framed in the PRD as a 3–6 month long-term goal — week 5–6 is too soon to evaluate that outcome.

Out of scope per stakeholder decision: revenue and MRR (subscription cohort lag exceeds the 5.5-week post-window).

---

## Update 1 — Work plan

Posted retroactively. Approach follows the project's three-pass analytical workflow with explicit mechanism enumeration and contamination-zone handling.

1. Phase 0 — Read PRD verbatim. Confirmed the plus-or-minus-5-percent short-term criterion and the 20 percent long-term forecast.
2. Phase 1 — Calibrate fct_sessions, dim_daily_kpis, fct_sessions_attribution (pending pre-analysis). Three calibration artifacts written.
3. Phase 2 — Setup task directory at analysis/data-health/2026-04-24-domain-consolidation-impact/.
4. Phase 3 — BUILD pass. Fifteen diagnostic queries (q1 through q15) covering: weekly traffic by channel and host, paid-spend control, channel-classifier audit, branded vs non-branded organic, organic landing concentration, host consolidation totals, year-over-year anchor, 2026-04-14 to 2026-04-17 spike substantiation, new-page velocity, acquisition by channel, engagement quality, contamination filter validation, summary roll-up, identity check.
5. Phase 4 — VERIFY pass. Type Audits on rate metrics, Identity Check fct_sessions versus dim_daily_kpis, Enumeration Checks, manual spot-check, diagnostic saturation check on bounce rate, contamination filter validation against control windows.
6. Phase 5 — INTERPRET pass. Null Hypothesis Blocks, Claim Verification on every interpretive sentence, Adversarial Q1 through Q4, Stakeholder Benchmark Cross-check vs the PRD plus-20-percent benchmark, Intervention Classification per finding.
7. Phase 6 — Deliverable. Findings document and this ticket comment, plus CSV exports.

Comparison frame: pre-period 2026-01-19 to 2026-03-04 (45 days, recency-matched), contamination zone 1 hard-excluded 2026-03-05 to 2026-03-25 (Fastly POP and pre-render artifact, root cause confirmed by Luke 2026-04-01), primary post-window 2026-03-26 to 2026-04-13 (19 days, clean), contamination zone 2 (2026-04-14 to 2026-04-17 plus tail through 2026-04-24, signature confirmed in this analysis), year-over-year anchor 2025-03-26 to 2025-04-13 (19 days, calendar-matched).

---

## Update 2 — Summary of findings

Posted 2026-04-24 after the BUILD-VERIFY-INTERPRET passes.

Status: read-out complete. Two open structural items surfaced for follow-up; they do not block the read-out but they constrain how confidently the long-term plus-20-percent goal can be evaluated.

### Headline

**Organic Search sessions DID plus 26 percentage points** at the cutover. Difference-in-differences vs DoW-aligned 2025 anchor.

- Pre-cutover (2026-01-19 → 2026-03-04 vs 2025-01-20 → 2025-03-05): 5,633/day vs 9,203/day → 2026 was running minus 38.8 percent YoY
- Post-cutover (2026-03-26 → 2026-04-13 vs 2025-03-27 → 2025-04-14): 7,075/day vs 8,115/day → 2026 is running minus 12.8 percent YoY
- **DID: 2026 closed 26 pp of YoY gap at the cutover.**

Caveat: Direct sessions DID was minus 18.8 pp at the same cutover. Some of that may be Fastly Referer-handling re-classifying Direct as Organic. If all of it is reclassification, real organic-traffic incrementality is **plus 11 pp DID**. If none of it is, real incrementality is **plus 26 pp DID**. True value is somewhere in that range.

Plus-or-minus-5-percent PRD short-term criterion is met on the upside.

### Acquisition

Organic-driven new subscriptions from dim_daily_kpis:

- Pre window A: 8.3 per day
- Post window C: 10.8 per day  → plus 30 percent

Total new subscribers (mixpanel_subscriptions) across all channels: plus 17 percent. Acquisition lift directionally mirrors traffic.

### Mechanism enumeration

Five hypotheses considered for the DID plus 26 pp sessions / plus 52 pp visitors at the cutover:

1. Real consolidation-driven SEO uplift — consistent. Non-branded organic up 57 percent (branded stable). New organic landing paths first-seen-in-week jumped from 600-800 per week pre-cutover to 5,000-7,000 per week post-cutover (mostly URL renames /pricing → /library/pricing, some real new crawl).
2. Paid spend pulled back, attribution shifted Direct to Organic — RULED OUT. Paid spend went UP 50 to 75 percent post-cutover.
3. Year-over-year seasonal pattern + 12-month state changes — RULED OUT as dominant mechanism. Pure seasonal/state-change explanation predicts a smooth YoY trajectory (DID near zero). The plus-26-pp DID change at the cutover is a discontinuity that does not match that prediction.
4. Improved Referer-header capture (Fastly classifier shift) — partial. Organic referrer-NULL rate dropped from roughly 47 percent pre to roughly 34 percent post. Direct DID minus 18.8 pp at the cutover is consistent with some re-attribution. Plausible upper bound on H4 contribution to the sessions DID: 15 to 20 pp. Floor on real Organic incrementality: plus 6 to 11 pp DID on sessions. Visitors DID is largely insulated (re-attribution does not generate new visitors).
5. 2026-04-14 to 2026-04-17 contamination spilling into post-window — RULED OUT. Spike does not contaminate window C.

Real Organic incrementality: floor plus 6 to 11 pp DID on sessions; visitors DID plus 52 pp is the cleaner directional read.

### 2026-04-14 to 2026-04-17 spike — confirmed APAC-concentrated Direct contamination

This analysis confirmed the second contamination zone. APAC concentration jumped from 49 percent baseline to 78 percent during the spike; daily Direct volume from 8K per day baseline to 21K per day. Tail (2026-04-18 to 2026-04-24) is still 1.6 times elevated above baseline. Engineering confirmation pending — leading hypothesis is the same Fastly or pre-render mechanism as 2026-03-05 to 2026-03-25 with a different POP region or a sitemap-recrawl event. Documented separately in project memory and the 04-17 OPEN investigation.

### Engagement quality on organic landings

Bounce rate up 7.8 percentage points window C vs A; pageviews per session down 14 percent; median duration down 36 percent. Most of the decline is composition shift (pre-cutover organic landed roughly 60 percent on app.soundstripe.com which is high-engagement library content; post-cutover all organic lands on the unified host with mixed marketing and library content). Some residual real quality decline likely; worth a content-team look.

---

## PRD success-criteria status

| Criterion | Timeline | Status |
|---|---|---|
| No loss of SEO traffic plus-or-minus 5 percent | Short-term | MET — DID plus 26 pp sessions / plus 52 pp visitors at the cutover, well outside the plus-or-minus-5-percent band on the upside |
| Greater-or-equal-to 95 percent tracking continuity | Short-term | Sessions reconcile fct_sessions vs dim_daily_kpis perfectly. Visitors diverge 7 to 16 percent (post-consolidation profile_id stitching, not loss). |
| 20 percent organic traffic increase | Long-term, 3 to 6 months | Early watermark only. Current YoY level is minus 12.8 percent on sessions, plus 15.1 percent on visitors. Trajectory closed 26 pp YoY gap in 5.5 weeks; reaching plus 20 percent YoY level on sessions requires another 33 pp of YoY-level gain over the next 5 to 10 weeks. |
| No login or checkout drop-off | Short-term | Out of scope for this analysis |
| Zero P0 incidents | Short-term | Out of scope |

---

## Recommendations

1. Re-run this read-out at 12 weeks post-cutover (2026-06-08) and 24 weeks post-cutover (2026-08-31), using the same DID frame. The plus-20-percent PRD goal applies on the 3 to 6 month horizon.
2. Adopt the contamination-aware reporting frame for any marketing dashboard that covers 2026-03-05 to 2026-04-17 (and tail to 2026-04-24). Calibration artifact at knowledge/data-dictionary/calibration/core__fct_sessions.md documents the two contamination signatures.
3. Engineering confirmation on the 2026-04-14 to 2026-04-17 spike is the highest-leverage open item. Either confirm same Fastly or pre-render mechanism (apply the 03-25 fix or analog), or rule it out and pursue Fastly access-log analysis. Until then, all reporting after 2026-04-13 carries a contamination caveat.
4. Google Search Console is not in the warehouse. Direct measurement of the plus-20-percent goal at 3 to 6 months requires GSC ingest. Recommend prioritizing GSC source addition to dbt before the 12-week recheck.
5. Lead narrative with visitors DID, not sessions DID. Visitors DID plus 52 pp is largely independent of H4 (re-attribution does not generate new visitors). Sessions DID plus 26 pp has the H4 caveat (15 to 20 pp upper-bound classifier contribution). Visitors crossing zero YoY at the cutover is the cleaner directional read.
6. Audit the engagement quality decline on organic landings. Pre-cutover the organic mix was roughly 60 percent app library and 40 percent www marketing; post-cutover the unified host blends both. Quality metrics are partially incomparable across the cutover; content team can act on residual bounce/pageview decline once the composition baseline is established.

---

## Artifacts

- analysis/data-health/2026-04-24-domain-consolidation-impact/findings.md (full write-up, 9 sections, hypothesis enumeration, intervention classifications)
- analysis/data-health/2026-04-24-domain-consolidation-impact/console.sql (q1 through q15 diagnostic queries)
- analysis/data-health/2026-04-24-domain-consolidation-impact/q16_did_dow_aligned.csv (DoW-aligned DID dataset — primary headline source)
- analysis/data-health/2026-04-24-domain-consolidation-impact/q14_summary_rollup.csv (six-window descriptive roll-up by channel — context only)
- analysis/data-health/2026-04-24-domain-consolidation-impact/q9_spike_substantiation.csv (2026-04-14 to 2026-04-17 spike signature evidence)
- analysis/data-health/2026-04-24-domain-consolidation-impact/q11_acquisition.csv (weekly paid spend and per-channel subscription counts)
- knowledge/data-dictionary/calibration/core__fct_sessions.md (calibration artifact with both contamination signatures documented)

---

## Task status

Read-out complete. Recommend leaving the ticket OPEN for the 12-week recheck (2026-06-08) and 24-week recheck (2026-08-31). The two structural follow-ups (engineering confirmation on 2026-04-14 spike, GSC ingest) are tracked separately:

- 2026-04-17 spike: project_direct_traffic_spike_2026_04_17_open memory; needs engineering confirmation from Luke Capizano or Fastly access-log analysis
- GSC ingest: structural recommendation 4 above; needs data engineering scoping

If you want a recurring readout cadence (weekly Slack summary or a Looker dashboard), let me know and I can set that up.
