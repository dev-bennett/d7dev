# Product KPIs — Year-in-Review (May 2024 - Apr 2026)

| | |
|---|---|
| **Stakeholder** | Meredith Knott (Product) |
| **Analyst** | Devon Bennett |
| **Source dashboard** | Looker Dashboard 19 — Product KPIs |
| **Window** | YoY full 12-month windows. **Y1 = May 2024 - Apr 2025**, **Y2 = May 2025 - Apr 2026**. |
| **Status** | draft 2026-04-30 |

## TL;DR

- **Acquisition fell roughly half.** New subs -48% YoY (18,744 → 9,710). Sessions -20%; conversion rate -35%. Three channels — Organic, Paid Search, Direct — account for 93% of the decline; each broke for a different reason.
- **Monetization actually improved.** LTV-modeled revenue per session rose **+18% YoY** because the new-subscriber mix shifted from Personal-tier to Pro-tier (Personal share 63% → 40%; Pro share 32% → 54%). Net revenue from new subs only fell -6%, despite -47% subs.
- **MQL volume grew +46% YoY** — pricing form +68%, demo form +109%. Sales-pipeline indicators are *up*, not down.
- **Engagement is flat.** The decline visible on the four cohort-window tiles is right-censoring on incomplete cohorts; underlying behavior has not changed.

---

## 1. Acquisition: -48% subs, three different stories

> [Chart: stacked time series of subscribing-sessions by channel, monthly, 24m. Highlights divergent channel trajectories.]

| Channel | Sessions Y1 | Sessions Y2 | CVR Y1 | CVR Y2 | Subs Y1 | Subs Y2 | Δsubs | Share of decline | What broke |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Organic Search | 2.85M | 2.46M | 0.28% | 0.20% | 8,053 | 4,977 | -3,076 | 34% | Sessions -14%, CVR -28%. Volume already recovering; CVR open. |
| Paid Search | 1.51M | 0.59M | 0.35% | **0.39%** | 5,300 | 2,322 | -2,978 | 33% | **Pure volume.** Sessions -61%, CVR slightly *up* |
| Direct | 2.93M | 2.81M | 0.13% | **0.06%** | 3,923 | 1,602 | -2,321 | 26% | **Pure CVR collapse.** Sessions flat, CVR -57% |
| All others | 0.76M | 0.57M | — | — | 1,468 | 809 | -659 | 7% | — |

**Paid Search is a budget story, not a quality story.** The channel still converts at historical efficiency. Volume fell because traffic stopped being bought. -2,978 subs at company LTV is material. Owner: marketing.

**Direct is a CVR-only story.** Same volume of Direct sessions, half the conversions per session. The conversion drop is in the engaged-session pool, not in low-engagement bot-signature traffic. Leading hypotheses: loyal-customer churn from "type-in-the-URL" traffic, or attribution shifting paid traffic into Direct. Owner: data-team diagnostic to discriminate.

**Organic Search.** Sessions fell -14% and per-session conversion rate fell -28% over the YoY window. A separate domain-consolidation impact analysis (2026-04-24) shows the volume component has begun to recover since the 2026-03-16 cutover. The per-session conversion drop is the open item — what drove it is not addressed by this analysis.

---

## 2. The monetization paradox: subs down -48%, revenue per session up +18%

> [Chart: side-by-side stacked bars of subscriber plan-mix Y1 vs Y2, with bar height = total subs.]

| | Y1 | Y2 | YoY |
|---|---:|---:|---:|
| New subs | 18,930 | 9,949 | -47.4% |
| Revenue (LTV-modeled) | \$3.57M | \$3.37M | -5.8% |
| Avg LTV per sub | \$189 | \$339 | **+79.3%** |
| Revenue per session | \$0.444 | \$0.524 | **+18.1%** |

Plan-mix shift among new subscribers:

| Plan tier | Y1 share | Y2 share | Δ |
|---|---:|---:|---:|
| Personal | 62.9% | 39.8% | **-23.1pp** |
| Pro | 32.3% | 54.3% | **+22.0pp** |
| Enterprise | 1.1% | 3.3% | +2.2pp |
| All others | 3.7% | 2.6% | -1.1pp |

Fewer subscribers; each one is worth substantially more. Net revenue from new acquisition only fell -6%.

---

## 3. The signup paradox: traffic-mix is the cause, not propensity

> [Chart: dual time series — analyst-derived per-visitor signup rate vs Looker tile 11 (Engaged Visitor Sign Up CVR). The two diverge.]

| Rate | Y1 | Y2 | YoY | Source |
|---|---:|---:|---:|---|
| Per-visitor signup rate (analyst-derived: signed_up_visitors / visitors) | 6.38% | 4.51% | -29% | M3 follow-up; **does NOT match Looker tile 5** (which uses session denominator) |
| Engaged Visitor - Sign Up CVR (Looker tile 11) | 19.84% | 18.72% | **-5.6%** | LookML measure `visitor_sign_up_cvr` filtered to engaged_session_ind='Yes' |

The engaged pool's signup propensity is roughly flat. The per-visitor rate falls because the engaged share of traffic is shrinking (32% of visitors in Y1 → 24% in Y2). Same dynamic underlies the Direct CVR collapse in §1: more people landing and bouncing; fewer landing and engaging.

**Engaged Visitor - Sign Up CVR is the cleanest tile on the dashboard** at -5.6% YoY. Recommend promoting to headline acquisition KPI.

> **Caveat for stakeholder delivery:** the per-visitor 6.38% / 4.51% figures are an analyst-derived view, not what Looker tile 5 (`Sign Ups per Session`) shows. Tile 5 uses a session denominator and reports a per-session rate. If the §3 narrative is shipped to stakeholders, either (a) replace the per-visitor row with tile 5's actual per-session value, or (b) explicitly label the per-visitor row as "analyst-derived alternative" so stakeholders don't expect to find 6.38% on the dashboard.

---

## 4. What's actually growing: MQL volume

> [Chart: monthly time series of three lines — pricing / enterprise / demo form submissions.]

| Component | Y1 volume | Y2 volume | YoY |
|---|---:|---:|---:|
| Pricing form | 1,035 | 1,741 | **+68%** |
| Enterprise form | 338 | 214 | -37% |
| Demo form | 81 | 169 | +109% |
| **Total MQLs** | **1,454** | **2,124** | **+46%** |

- MQL Form Submissions per Session should display three count tiles, one per form type. Sales staffing wants form-by-form lead volume.
- Enterprise form -37% YoY is the only declining component. Worth a separate look at whether the enterprise pipeline is filling at the rate sales expects.

---

## 5. What's NOT broken: engagement (the four cohort-window tiles)

> [Chart: % of Subscribers Downloading Songs: 30-60 Days, monthly cohorts. Single line using the LookML denominator (subs_60_plus). Series is flat at ~50-57% from May 2024 through Feb 2026, then drops sharply at Mar/Apr 2026 — the drop is right-censoring (those cohorts haven't reached day 60), not an engagement decline.]

These four tiles measure behavior in windows after subscription start (0-7d, 0-30d, 30-60d). Cohorts that haven't completed their window are bias-low — % of Subscribers Downloading Songs: 30-60 Days returns 0% in April 2026 because no April subscriber can have reached 30-60d by April 28.

Lagged-clean (cohorts that finished their window):

| Tile | First-half-of-window cohort mean | Last-half-of-window cohort mean | Δ |
|---|---:|---:|---|
| % of Subscribers Downloading Songs: 0 - 7 Days | 81.6% | 77.8% | -3.8pp (within 1.5σ) |
| Song Downloads per Downloading Subscriber: 0 - 30 Days | 10.04 | 9.70 | -3.4% |
| % of Subscribers Downloading Songs: 30-60 Days | 53.2% | 54.4% | +1.2pp |
| Sessions per Engaged Subscriber: 30-60 Days | 5.91 | 5.82 | -1.5% |

All within natural cohort-to-cohort variation. Engagement is flat. Fix is presentational: lag the cohort axis by the window size.

---

## 6. Dashboard hygiene

| Tile | Issue | Fix |
|---|---|---|
| New Tile | Placeholder; identical measure to Global Revenue per Session | Remove |
| Global Revenue per Session - App Engaged Sessions (45 seconds or more) | `has_app_view IN ('Yes','No')` filter is a no-op | Remove filter or fix the intended segmentation |
| Song Downloads per Downloading Subscriber: 0 - 30 Days | Title says "per Downloading Subscriber"; measure denominator is all subscribers | Rename title or swap denominator |
| MQL Form Submissions per Session | Single rate hides 3 differently-trending components | Replace with three count tiles (pricing/enterprise/demo) |
| The four cohort-window tiles (0-7d, 0-30d, two 30-60d) | Right-censoring produces fake declines at recent edge | Lag axis or filter to fully-observed cohorts |

---

## 7. What needs to happen

**Dashboard changes (Devon implements once approved):**

1. New Tile removal, Global Revenue per Session - App Engaged Sessions filter fix, Song Downloads per Downloading Subscriber: 0 - 30 Days title alignment.
2. MQL Form Submissions per Session: split into 3 count tiles.
3. The four cohort-window tiles: lag the cohort axis to fully-observed cohorts only.
4. Add `sign_ups_per_visitor` LookML measure; surface alongside per-session on Sign Ups per Session. Add a "subscriber plan mix" tile.
5. Promote Engaged Visitor - Sign Up CVR to headline acquisition position.

**Open follow-up analyses:**

6. **Direct CVR mechanism diagnostic:** logged-in vs anonymous Direct CVR YoY. Discriminates loyal-customer churn from attribution shift.
7. **Organic CVR mechanism diagnostic:** what drove the -28% YoY per-session conversion decline pre-cutover. Volume side already addressed by the 2026-04-24 domain-consolidation impact analysis.
8. **Plan-mix classifier audit.** The "pro" bucket pattern (`pro%, music%, sfx%, standard%, premium%`) may over-capture legacy plan names; if Personal → Pro is partly classifier coverage, the §2 mix-shift effect is overstated.
