# New Subscribers -- Weekly Sliding 20-Week Baseline XmR

@../CLAUDE.md

## Purpose

Weekly XmR process behavior chart for NEW SUBSCRIBERS using a rolling 20-week trailing baseline.

## Table Reference

- Source: `soundstripe_prod.core.dim_daily_kpis`
- Metric: `new_subscribers` (aggregated weekly via SUM)

## Files

- `new_subscribers.sql` -- Weekly sliding-baseline XmR query
- `new_subscribers.py` -- Chart generation script
- `new_subscribers.csv` -- Query results (exported manually)
