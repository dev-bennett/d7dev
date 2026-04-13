# Visitors -- Weekly Sliding 20-Week Baseline XmR

@../CLAUDE.md

## Purpose

Weekly XmR process behavior chart for VISITORS using a rolling 20-week trailing baseline.

## Table Reference

- Source: `soundstripe_prod.core.dim_daily_kpis`
- Metric: `visitors` (aggregated weekly via SUM)

## Files

- `visitors.sql` -- Weekly sliding-baseline XmR query
- `visitors.py` -- Chart generation script
- `visitors.csv` -- Query results (exported manually)
