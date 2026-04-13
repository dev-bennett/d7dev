# Enterprise Form Submissions -- Weekly Sliding 20-Week Baseline XmR

@../CLAUDE.md

## Purpose

Weekly XmR process behavior chart for ENTERPRISE FORM SUBMISSIONS using a rolling 20-week trailing baseline.

## Table Reference

- Source: `soundstripe_prod.core.dim_daily_kpis`
- Metric: `enterprise_form_submissions` (aggregated weekly via SUM)

## Files

- `enterprise_form_submissions.sql` -- Weekly sliding-baseline XmR query
- `enterprise_form_submissions.py` -- Chart generation script
- `enterprise_form_submissions.csv` -- Query results (exported manually)
