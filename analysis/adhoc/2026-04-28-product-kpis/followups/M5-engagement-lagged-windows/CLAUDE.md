# M5 — Engagement Metric Recomputation on Lagged-Window Basis

@../CLAUDE.md

Recomputes tiles 7-10 with the cohort window restricted to fully observable cohorts (sub_start_month + 60 days ≤ analysis date). Removes the right-censoring bias that produces the dashboard's apparent recent-month decline.

## Files

- `queries.sql` — m5_q01: lagged-cohort engagement components
- `M5_engagement_lagged.csv` — per-cohort 4 engagement rates, May 2024 - Feb 2026 (22 cohorts, all fully 60d-observable as of 2026-04-29)
- `findings.md` — verdict and roll-up
