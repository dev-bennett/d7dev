# Enterprise Reporting Fixes — 2026-05-06

@../CLAUDE.md

## Purpose

Two follow-up engineering changes derived from the 2026-05-05 enterprise-reporting variance reconciliation (`analysis/adhoc/2026-05-05-enterprise-reporting-comparison/`). Each can ship independently; bundling into one PR is also fine.

## Subdirectories

- `fix1_mql_free_email_filter/` — Apply HubSpot list 4459 (`[MASTER] ALL Contacts w/ Free Email Domain List`) exclusion to `dim_mql_mapping`. Closes variance 3 (Looker MQL count = 758 vs HubSpot = 470, gap = 312 free-email contacts).
- `fix2_deals_source_swap_to_hpd/` — Switch `stg_deals.sql` source from `pc_stitch_db.hubspot_new.deals` (Stitch ETL with ghost-record drift) to `hubspot_platform_data.v2_daily.objects_deals` (HubSpot's authoritative Operations Hub data share). Closes variance 5 (24 ghost April deals; 345 lifetime).

## Conventions

- Both fixes target the same dbt repo (`SoundstripeEngineering/dbt-transformations`), branch `develop_dab` → `main`.
- Snowflake dev target: `soundstripe_dev`. Prod via PR merge.
- Each subdir contains a drop-in replacement model file and a `notes.md` with the change rationale, expected impact, and verification.
