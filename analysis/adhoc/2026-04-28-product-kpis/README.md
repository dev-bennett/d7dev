# Product KPIs 24-Month Trend Review

| | |
|---|---|
| **Workspace** | `analysis/adhoc/2026-04-28-product-kpis/` |
| **Stakeholder** | Meredith Knott (Product) |
| **Analyst** | Devon Bennett |
| **Status** | draft (Stage 0 scaffolded 2026-04-28) |
| **Source dashboard** | Looker Dashboard 19 — Product KPIs |
| **Time window** | 24-month monthly grain (2024-05 → 2026-04) |

## The question

Several tiles on the Product KPIs dashboard appear to be trending down in the trailing months. Are those declines real product/business signal, real mix-shift signal, or measurement artifacts of recent infrastructure events?

## In-scope KPIs (14 tiles)

Source: `product_kpis.lkml` (this directory).

| # | Tile | Explore | Measure | Bucket |
|---|---|---|---|---|
| 1 | Global Revenue per Session | fct_sessions | total_revenue_per_session | Revenue |
| 2 | 1 Yr LTV per Transaction | fct_sessions | avg_transaction_and_sub_1yr_revenue | Revenue |
| 3 | Global Rev/Session — App Engaged 45s+ | fct_sessions | total_revenue_per_session (filtered) | Revenue |
| 4 | Purchase CVR (per Session) | fct_sessions | overall_conversion_rate | Acquisition |
| 5 | Sign Ups per Session | fct_sessions | sign_ups_per_session | Acquisition |
| 6 | MQL Form Submissions per Session | fct_sessions | mqls_per_session | Acquisition |
| 7 | % Subscribers Downloading Songs: 0–7d | fct_subscriber_activity_mixpanel | song_downloading_subscriber_rate_param @ 7 | Engagement |
| 8 | Songs/Downloading Subscriber: 0–30d | fct_subscriber_activity_mixpanel | songs_downloaded_by_subscriber_param @ 30 | Engagement |
| 9 | % Subscribers Downloading Songs: 30–60d | fct_subscriber_activity_mixpanel | engaged_subscriber_rate_30_to_60 | Engagement |
| 10 | Sessions/Engaged Subscriber: 30–60d | fct_subscriber_activity_mixpanel | sessions_per_engaged_subscriber_30_to_60 | Engagement |
| 11 | Engaged Visitor Sign-Up CVR | fct_sessions | visitor_sign_up_cvr (filtered engaged) | Acquisition |
| 12 | Subscription Expansion 0–30d | subscription_changes_retention | expansion_rate (prior_plan ∈ {personal,pro,pro-plus}) | Expansion |
| 13 | Avg 1Yr LTV Expansion Value 0–30d | subscription_changes_retention | avg_1_yr_value_of_expansion | Expansion |
| 14 | New Tile (placeholder; duplicate of #1) | fct_sessions | total_revenue_per_session | Placeholder |

## Methodology

Three-pass workflow per `analysis-methodology.md`:

1. **BUILD-A** — 24m monthly series for all 14 KPIs (consolidated query)
2. **BUILD-B** — data-quality diagnostic suite quantifying contamination at the input layer
3. **BUILD-C** — per-declining-KPI decomposition (rate × share by host/channel/cohort)
4. **VERIFY** — Type Audits, §6 enumeration, §5 identity check, stakeholder benchmark cross-check
5. **INTERPRET** — null hypothesis, mechanism enumeration, metric-validity verdict per KPI
6. **RECOMMEND** — §11 intervention class; dashboard / definition / DQ remediation buckets

## Deliverables

| File | Status |
|---|---|
| `findings.md` | draft (awaiting Meredith review); includes per-KPI verdict table + follow-up mini-analysis roadmap (M1–M6) |
| `console.sql` | q01–q05 (file-resident); q06–q09 ran via MCP, results in q06.csv/q07.csv/q08.csv |
| `tables/` (14 per-tile CSVs + `kpi_summary.csv` + `regime_windows.csv`) | complete; replaces the deleted in-house PNG set |
| `scripts/tables.py` | complete; pure-stdlib derivation of per-tile rates from q01/q02/q03/q07 |
| `contract-and-rates.md` (§2 contract + §1 RATE blocks) | complete |
| `checkpoint.md` (§9) | complete |
| `q01.csv` – `q08.csv` (raw data) | complete |

## Status log

- **2026-04-28** — workspace scaffolded; CLAUDE.md, README.md created; tile inventory captured from `product_kpis.lkml`; LookML measure SQL traced for all 14 tiles; calibration prerequisites confirmed (fct_sessions, fct_sessions_attribution, dim_daily_kpis already current as of 2026-04-24-r2).
- **2026-04-28** — calibration artifact written for `core.fct_subscriber_activity_mixpanel` via warehouse-calibrator subagent (`knowledge/data-dictionary/calibration/core__fct_subscriber_activity_mixpanel.md`). Three load-bearing gotchas surfaced (right-censoring, monthly-sub end_date snap, full-rebuild meaning shift).
- **2026-04-28** — BUILD passes A/B complete: q01 (fct_sessions tiles), q02 (subscriber-activity tiles), q03 (expansion tiles, billing_interval fix applied), q06 (host bucket split), q07 (artifact-vs-real contamination), q08 (cohort plan-mix).
- **2026-04-28** — VERIFY pass complete: q09 dim_daily_kpis benchmark at 2025-09 — sessions exact match (479,416); §5 identity check on tile 4 verified.
- **2026-04-28** — INTERPRET + RECOMMEND complete: `findings.md` written with per-KPI verdict table, per-declining-KPI deep-dives (NULL CHECK / mechanism enumeration), §11 intervention classification, §8 Adversarial Q1–Q4.
- **2026-04-28** — chart set generated; tile 4, 5, 9, 12 visually verified (y-axis at 0, regime shading visible, legend outside plot, no overlap).
- **2026-04-28** — Sentence Audit (§10) zero banned phrases. CLAUDE.md chain verified. Files staged but NOT committed (per `feedback_dont_assume_commits`).
- **2026-04-28** — chart set deleted by analyst as unsatisfactory; replaced with `tables/` (14 per-tile CSVs + `kpi_summary.csv` wide + `regime_windows.csv`) generated by `scripts/tables.py`. Charting now done downstream in analyst's tool of choice.
- **2026-04-28** — `findings.md` extended with "Follow-up mini-analysis roadmap" section (M1–M6) tying each follow-up to specific findings + roll-up KPI tiles.
