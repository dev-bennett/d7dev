# Q1 Deep Dive -- Sliding 90-Day Baseline XmR

@../CLAUDE.md

## Purpose

Per-KPI XmR process behavior charts using a rolling 90-day trailing baseline. Each KPI has its own subdirectory with SQL, Python chart script, and CSV data.

## Table Reference

- Source: `soundstripe_prod.core.dim_daily_kpis`

## Structure

```
q1-sliding-baseline/
├── charts/<YYYY-MM-DD>/       # chart PNGs, date-stamped on generation
├── <kpi_name>/
│   ├── CLAUDE.md
│   ├── <kpi_name>.sql         # XmR query (run in Snowflake, export to CSV)
│   ├── <kpi_name>.csv         # query results (manually exported w/ header row)
│   └── <kpi_name>.py          # chart script (reads CSV, writes to charts/<date>/)
└── CLAUDE.md
```

## Workflow

1. Run `<kpi>.sql` in Snowflake
2. Export results to `<kpi>/<kpi>.csv` (include header row)
3. Run `python3 <kpi>.py` to generate chart in `charts/<today>/`

## KPIs

Subscription: active_subscribers, active_monthly_subscribers, active_yearly_subscribers, new_subscribers, churned_subscribers, net_chg_active_subscribers
Revenue: mrr, arr, net_chg_mrr
Traffic: visitors, sessions, core_visitors
Marketing: enterprise_form_submissions, spend, core_spend, impressions, clicks
Paid Search: paid_search_spend, paid_search_impressions, paid_search_clicks
Paid Social: paid_social_spend, paid_social_impressions, paid_social_clicks
Display: display_spend, display_impressions, display_clicks
Conversions: mixpanel_subscriptions, core_mixpanel_subscriptions, direct_subscriptions, organic_search_subscriptions, paid_search_subscriptions, total_transactions, single_song_rev
