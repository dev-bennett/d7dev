# LinkedIn creative_id normalization fix

@../CLAUDE.md

## Purpose

Fix the LinkedIn ad reporting lineage so `fct_ad_performance` reflects actual 2026 LinkedIn spend and `dim_ad_content` creative names join correctly in the `ad_content_performance` Looker explore.

Working hypothesis (per plan at `~/.claude/plans/enumerated-noodling-snowflake.md`): `right(id, 9)` in `stg_fct_creatives.sql` and `stg_linkedin_ads_creative_content.sql` truncates LinkedIn creative IDs that grew past 9 digits in late 2025, causing the INNER JOIN in `stg_linkedin_ads_ad_performance_report.sql` to drop all creatives created after that threshold.

## Structure

- `diagnose/` — read-only warehouse queries to confirm root cause before writing dbt edits
- `dbt/` — drafted dbt edits (created after Phase 1 decision gate)
- `verify/` — pre/post verification queries (created in Phase 4)
- `README.md` — task status + phase log

## Conventions

- All queries run against `pc_stitch_db.linkedin_ads.*` (raw Stitch source) or `soundstripe_prod.marketing.*` (mart layer).
- Results land as CSVs next to the SQL file (`q1.sql` → `q1.csv`).
- dbt drafts mirror the directory layout of `context/dbt/models/staging/linkedin_ads/` and `context/dbt/models/marts/marketing/` — so a diff against the submodule is one-to-one.
