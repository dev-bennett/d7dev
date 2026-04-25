# Post-deploy verification

@../CLAUDE.md

QA queries to confirm the LinkedIn creative_id normalization fix landed correctly in prod. Run `verify.sql` after the dbt PR merges and prod finishes its next scheduled build.

Each labeled query in `verify.sql` is one SELECT producing one exportable result. Export as `v1.csv ... v5.csv` here.

| Label | What it confirms |
|---|---|
| V1 | 2026 LinkedIn spend is now present in `fct_ad_performance` (primary symptom gone) |
| V2 | LinkedIn creative_name coverage in the `ad_content_performance` join reaches ≥90% on 2026 active rows |
| V3 | No Facebook regression — spend and name coverage unchanged pre/post |
| V4 | `dim_ad_content.ad_id` is unique per `(ad_id, platform)` — no collisions introduced |
| V5 | Spot-check: named April 2026 creatives from the ticket (e.g. `Duplicate_Buyers_Guide_v*_FORM`) appear with spend |
