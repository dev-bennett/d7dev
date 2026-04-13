# Weekly XmR -- Sliding 20-Week Baseline

@../CLAUDE.md

## Purpose

Per-KPI XmR process behavior charts using weekly aggregation and a rolling 20-week (~90 day) trailing baseline. Covers 2024-01-01 (first full Monday) through the last complete week.

## Table Reference

- Source: `soundstripe_prod.core.dim_daily_kpis`

## Structure

```
weekly-sliding-baseline/
├── charts/<YYYY-MM-DD>/       # chart PNGs, date-stamped on generation
├── <kpi_name>/
│   ├── CLAUDE.md
│   ├── <kpi_name>.sql         # weekly XmR query (run in Snowflake, export to CSV)
│   ├── <kpi_name>.csv         # query results (manually exported w/ header row)
│   └── <kpi_name>.py          # chart script (reads CSV, writes to charts/<date>/)
└── CLAUDE.md
```

## Workflow

1. Run `<kpi>.sql` in Snowflake
2. Export results to `<kpi>/<kpi>.csv` (include header row)
3. Run `python3 <kpi>.py` to generate chart in `charts/<today>/`

## KPIs

- visitors
- enterprise_form_submissions
- new_subscribers

## Key Differences from Daily Version

- Source data aggregated to ISO weeks (Monday start) via DATE_TRUNC + SUM
- Baseline window: 20 weeks preceding (not 90 rows)
- Excludes current incomplete week via `DATE_TRUNC('week', CURRENT_DATE())`
- data_start: 2024-01-01 (first full Monday of 2024)
