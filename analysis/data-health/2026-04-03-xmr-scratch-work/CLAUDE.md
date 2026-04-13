# XmR Process Behavior Charts -- Scratch Work

@../CLAUDE.md

## Purpose

Wheeler XmR (Individuals & Moving Range) charts against `soundstripe_prod.core.dim_daily_kpis` for systematic signal detection.

## Methodology

Based on Donald Wheeler's "Understanding Variation" -- XmR charts with natural process limits (X̄ ± 2.66 × m̄R), signal rules: R1 (beyond limits), R2 (run of 8), R3 (2-of-3 beyond 2σ), R4 (trend of 6), mR (range signal).

## Structure

- `query_console.sql` -- Original Q1-Q7 daily XmR queries (fixed baseline)
- `q1.csv` through `q7.csv` -- Original query exports
- `q1-sliding-baseline/` -- Daily per-KPI XmR with 90-day sliding baseline (33 KPIs scaffolded)
- `weekly-sliding-baseline/` -- **Active** Weekly per-KPI XmR with 20-week sliding baseline (3 KPIs: visitors, enterprise_form_submissions, new_subscribers)

## Table Reference

- Source: `soundstripe_prod.core.dim_daily_kpis`
- dbt model: `context/dbt/models/marts/core/dim_daily_kpis.sql`
