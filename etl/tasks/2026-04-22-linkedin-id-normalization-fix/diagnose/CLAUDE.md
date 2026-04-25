# LinkedIn ID normalization — diagnose

@../CLAUDE.md

## Purpose

Read-only diagnostic queries that confirm the root cause of the LinkedIn `fct_ad_performance` / `dim_ad_content` join failure before any dbt edits.

## Query set

All queries live in a single file — `diagnose.sql` — with six labeled sections. Each section is one SELECT producing one exportable result. Run each section, export to the matching `qN.csv` next to the SQL.

| Label | Question answered |
|---|---|
| Q1 | Is Stitch still delivering 2026 rows to `ad_analytics_by_creative`, `creatives`, `campaigns`? |
| Q2 | What is the actual ID format (raw value, length, candidate normalizations) on each side of the join? |
| Q3 | What is the length distribution of IDs in each source table? |
| Q4 | How many analytics rows (and how much spend) survive the existing `right(id, 9)` join, by month? |
| Q5 | Do `split_part(id, ':', -1)` and `regexp_substr(id, '[0-9]+$')` recover the lost rows? |
| Q6 | Do any of the candidate normalizations emit NULLs or collapse distinct creatives into the same key? |

## Table references

All queries read from raw Stitch tables in `pc_stitch_db.linkedin_ads.*`:

- `ad_analytics_by_creative` — keyed by `creative_id` + `start_at` (daily performance telemetry)
- `creatives` — keyed by `id` (likely URN string `urn:li:sponsoredCreative:NNN...`)
- `campaigns` — keyed by `id`

## Execution

Devon runs `diagnose.sql` in the Snowflake worksheet, exports each query's result to `q1.csv ... q6.csv` in this directory, then posts the key numbers back to the session for the decision gate.
