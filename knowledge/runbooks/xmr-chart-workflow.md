# XmR Chart Generation Workflow

## Overview

Generate Wheeler XmR (Individuals & Moving Range) process behavior charts for KPIs from `dim_daily_kpis`. Charts detect statistical signals indicating process changes.

## Prerequisites

- Snowflake access (EMBEDDED_ANALYST role, read-only)
- Python 3.12+ with matplotlib, pandas
- CSV export capability from Snowflake worksheet

## Active Charts

Location: `analysis/data-health/2026-04-03-xmr-scratch-work/weekly-sliding-baseline/`

| KPI | Directory |
|-----|-----------|
| visitors | `visitors/` |
| enterprise_form_submissions | `enterprise_form_submissions/` |
| new_subscribers | `new_subscribers/` |

## Steps

1. **Run the SQL** — Open `<kpi>/<kpi>.sql` in Snowflake. The query is self-contained: config CTE sets `data_start` and derives the baseline window automatically.
2. **Export results** — Export to `<kpi>/<kpi>.csv` with header row included.
3. **Generate chart** — `cd <kpi>/ && python3 <kpi>.py`. Output writes to `../charts/<today>/<kpi>.png`.

## Configuration

Edit the `config` CTE in the SQL file:
- `data_start`: First day of the analysis period (must be a Monday for weekly)
- `baseline_weeks`: Trailing window size (default 20, Wheeler recommends 20-25 for stable limits)

## Signal Rules

See `charts/<date>/signal-rules.md` for definitions.

## Adding a New KPI

1. Create `<kpi>/` directory with CLAUDE.md
2. Copy an existing SQL file, change the column reference in `source_data`
3. Copy an existing Python file, change CSV/PNG filenames and title text
4. For NVL-wrapped columns (nullable from LEFT JOINs): use `NVL(k.<col>, 0)`
5. For churned_subscribers: use `ABS(k.churned_subscribers)`
