# Tables — Product KPIs 24-Month Trend Review

@../CLAUDE.md

Computed-rate tables, one per in-scope KPI tile plus a wide summary. Generated from `../q01.csv`, `../q02.csv`, `../q03.csv`, `../q07.csv` by `../scripts/tables.py`. These replace the deleted PNG chart set; charting is now done downstream by the analyst in their preferred tool.

## Files

- `kpi_summary.csv` — wide format. One row per month, columns for every tile's rate (and corrected variant where session-denominator artifact applies) plus volume context. Drop into a chart tool to recreate the dashboard side-by-side.
- `tile_NN_<slug>.csv` (14 files) — long format, one tile per file. Columns: `month_start, rate_reported, rate_corrected (where applicable), absolute_count, censored_flag`.
- `regime_windows.csv` — 2 rows. Domain cutover (2026-03-05 → 2026-03-25) and APAC artifact (2026-04-14 → 2026-04-17). For overlay shading.

## Rate definitions

Each tile's `rate_reported` and `rate_corrected` columns derive from the components in `../q01.csv`, `../q02.csv`, `../q03.csv` using the formulas captured in `../scripts/tables.py`. The formulas mirror the LookML measures of Dashboard 19 with two known approximations:

1. Tiles 1, 3, 14 (revenue/session) approximate the LTV-modeled total_revenue as `license_revenue + subscribing_sessions × 200 + mqls × 300`. The exact LookML measure multiplies subscribers by per-plan LTV-1yr; this approximation captures the trend shape but not the exact tile value. See `../findings.md` and `../console.sql` q01 caveat (b).
2. Tile 11 uses `visitors_engaged` as a proxy for `unique_non_registered_visitors` (the strict LookML denominator). The proxy includes already-registered users, depressing the rate level vs. the strict measure but preserving trend.

## Censored_flag semantics

For tiles 7-10, `censored_flag = 1` indicates the cohort has not yet completed the observation window required by the measure definition (recent-month bias-low):
- Tile 7 (0-7d): cohorts starting in 2026-04 are partially observed at 2026-04-28
- Tiles 8 (0-30d): cohorts starting 2026-03 onward
- Tiles 9, 10 (30-60d): cohorts starting 2026-03 onward (April returns NaN at 2026-04-28)

Treat censored rows as not-comparable to non-censored history.

## Run

```
python3 scripts/tables.py
```

From task workspace root. Pure Python stdlib — no matplotlib dependency.
