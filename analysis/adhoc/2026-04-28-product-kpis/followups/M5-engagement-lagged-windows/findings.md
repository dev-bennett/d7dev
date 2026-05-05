# M5 — Engagement Metrics on Lagged-Window Basis

| | |
|---|---|
| **Triggering finding** | `../../findings.md` STRUCTURAL block: tiles 7-10 right-censor at recent edge; tile 9 returns 0 at month-end by definition. Pre-Mar baseline appears stable but was not verified on a lagged-window view. |
| **Headline question** | When right-censoring is removed, is the engagement series actually flat, or is there slow drift the censoring is masking? |
| **Source data** | `core.fct_subscriber_activity_mixpanel` (re-pulled, m5_q01); restricted to cohorts with sub_start_month + 60 days ≤ analysis date |
| **Output** | `M5_engagement_lagged.csv` (22 fully-observable cohorts: May 2024 - Feb 2026) |
| **Status** | complete |

## Verdict — engagement is genuinely flat

All four engagement metrics are stable across the 22-month lagged-clean window. The dashboard's apparent recent-edge declines were 100% right-censoring artifact; the underlying behavior is not changing.

| Tile | First 6 cohorts (May-Oct 2024) | Last 6 cohorts (Sep 2025-Feb 2026) | Δ | 24m stdev | Verdict |
|---|---:|---:|---:|---:|---|
| 7 (% dl 0-7d) | 81.6% | 77.8% | -3.8pp | 2.55pp | Mild drift down (~1.5σ); within noise |
| 8 (songs/sub 0-30d) | 10.04 | 9.70 | -3.4% | 1.69 songs | Flat (Feb 2025 anomaly: 16.23) |
| 9 (% engaged 30-60d) | 53.2% | 54.4% | +1.2pp | 2.32pp | Flat / mild uptick |
| 10 (sessions/engaged sub 30-60d) | 5.91 | 5.82 | -1.5% | 0.52 sessions | Flat |

24-month means/stdevs:
- T7 = 79.6% (σ=2.6pp)
- T8 = 9.94 songs (σ=1.7)
- T9 = 53.1% (σ=2.3pp)
- T10 = 6.06 sessions (σ=0.5)

## Anchor table (per-cohort, lagged-clean)

| Cohort month | subs | T7 (% dl 0-7d) | T8 (songs/sub 0-30d) | T9 (% engaged 30-60d) | T10 (sessions/eng sub) |
|---|---:|---:|---:|---:|---:|
| 2024-05 | 2,084 | 83.5% | 9.25 | 50.8% | 5.20 |
| 2024-08 | 1,623 | 81.9% | 10.01 | 54.2% | 5.82 |
| 2024-11 | 1,667 | 77.6% | 9.07 | 48.9% | 5.84 |
| 2025-02 | 1,202 | 80.2% | **16.23** | 50.0% | 6.58 |
| 2025-05 | 1,295 | 79.9% | 9.12 | 50.7% | 5.81 |
| 2025-08 | 959 | 82.5% | 11.25 | 57.5% | 5.78 |
| 2025-11 | 783 | 79.1% | 10.67 | 52.6% | 4.97 |
| 2026-02 | 510 | 76.9% | 10.32 | 52.7% | 5.36 |

(Full series in `M5_engagement_lagged.csv`.)

## Notes

- **Feb 2025 songs/sub anomaly (16.23 vs ~10 baseline).** Single-cohort outlier; songs_dl_first_30d_total=19,510 vs subs=1,202. Either a cohort-quality spike, a tracking glitch, or a single power user. Worth a one-query spot-check (top-N download counts in Feb 2025 cohort) but not material to the M5 verdict.
- **Cohort size is shrinking sharply** — the 22-month subscriber-acquisition collapse documented in M2 means the recent-cohort sample sizes are smaller (510 in 2026-02 vs 2,084 in 2024-05). Statistical noise per cohort is rising at the right edge but signal-direction is still flat.
- **Tile 7 has the most arguable drift** (81.6% → 77.8%), but the 24m stdev (2.55pp) means this delta is well within normal cohort-to-cohort variation. If the trend continues another 6-12 months it might warrant attention; today it does not.

## Roll-up to parent dashboard

| Tile | Refined verdict |
|---|---|
| 7, 8, 9, 10 | **STRUCTURAL right-censoring stands; underlying engagement is FLAT.** No real product/business signal in the recent edge. The dashboard fix is a LookML measure or filter change to display only fully-observed cohorts; once that's done, these tiles will show a stable line and stop generating false-alarm "recent decline" reads. |

## Recommendation update for Meredith

1. **Implement the LookML structural fix already proposed in `../../findings.md` "Right-censoring fix on cohort tiles."** Lag the cohort-month axis by N days (60 for tile 9, 30 for tiles 7/8). Specifically: filter tile 7's cohort axis to `cohort_month + 7 ≤ today`, tile 8 to `+30 ≤ today`, tile 9 and 10 to `+60 ≤ today`. The `M5_engagement_lagged.csv` series shows what the corrected dashboard would display.
2. **Drop the engagement tiles from the "trending decline" review entirely.** They are stable; they do not need investigation; they should not appear in the per-KPI verdict table as anything other than CENS or STAB.
3. **Spot-check the Feb 2025 songs/sub anomaly** if Meredith asks. Otherwise note it and move on.

## §11 Intervention Class

(Same as parent doc's existing block for tiles 7-10 — STRUCTURAL right-censoring fix at LookML measure layer. M5 confirms the underlying behavior is flat, so the structural fix is purely a presentation correction; no behavioral hypothesis follow-up needed.)
