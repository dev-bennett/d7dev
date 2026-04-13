# Baseline: Post-Backfill Notification Performance

@../../CLAUDE.md

Re-run of exploration queries against the rebuilt mart tables (fct_notification_deliveries, dim_notification_content) after the Stitch replication key fix and dbt full-refresh. Establishes the corrected performance baselines for LookML dashboard validation.

## Conventions

- Queries labeled --qa through --qj in baseline.sql
- CSV exports named qa.csv through qj.csv to match query labels
