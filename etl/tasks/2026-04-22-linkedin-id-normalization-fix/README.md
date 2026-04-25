# 2026-04-22 — LinkedIn creative_id normalization fix

- **Status:** in-progress — root cause confirmed, dbt drop-ins + PR artifacts ready
- **Date:** 2026-04-22
- **PR:** pending
- **Models touched:** `stg_fct_creatives`, `stg_linkedin_ads_creative_content`, `stg_linkedin_ads/schema.yml` (new)
- **Source:** Ad Content Looker Reporting (Asana, Epics - Data)
- **Stakeholder:** Taylor Armstrong (marketing)

## Context

The `ad_content_performance` Looker dashboard shows ~zero LinkedIn spend from Dec 2025 onward, while Taylor has confirmed LinkedIn is actively spending more in 2026 than in 2025. Phase 1 diagnostics (`findings.md`) confirmed the cause: `right(id, 9)` in two LinkedIn staging models truncates the numeric tail of LinkedIn creative URNs for post-Oct-2025 creatives, silently failing the INNER JOIN in `stg_linkedin_ads_ad_performance_report`. `split_part(id, ':', -1)` restores 100% coverage with zero collisions.

16,430 USD of 2026 LinkedIn spend is currently missing from `fct_ad_performance` pre-fix.

## Files

- `findings.md` — Phase 1 diagnostic write-up with numbers and decision rationale
- `runbook.md` — step-by-step implementation in dbt Cloud + post-merge QA + Looker validation
- `commit-message.txt` — commit message for the `develop_dab` commit
- `pr-description.md` — PR body for `develop_dab` → `main`
- `diagnose/diagnose.sql` — Q1–Q6 diagnostic query set (completed)
- `diagnose/q1.csv … q6.csv` — Phase 1 exported results
- `dbt-updates/stg_fct_creatives.sql` — drop-in replacement
- `dbt-updates/stg_linkedin_ads_creative_content.sql` — drop-in replacement
- `dbt-updates/schema.yml` — new file with `unique` + `not_null` tests on the normalized `creative_id`
- `verify/verify.sql` — V1–V5 post-prod QA queries (run after merge + prod build)

## Deployment workflow (repo SOP)

All dbt commands target `soundstripe_dev`. Production updates only via PR merge to `main`. No local dbt CLI — model edits and runs happen in the dbt Cloud web IDE on `develop_dab`.

1. **Dev:** Apply the three file changes in dbt Cloud on `develop_dab`; run `dbt build -s +fct_ad_performance +dim_ad_content` and `dbt test`.
2. **Pre-merge prod prep:** none. Both staging models are views; `fct_ad_performance` and `dim_ad_content` are full-refresh tables.
3. **PR:** Open PR `develop_dab` → `main` using `pr-description.md`. CI runs automatic build/test.
4. **Merge:** On green CI, merge — triggers prod deployment.
5. **QA:** Run `verify/verify.sql` against `soundstripe_prod` AFTER the prod build completes.
6. **LookML:** No code change. Clear cache on `Ad Content Performance` dashboard and validate.

See `runbook.md` for the full step-by-step.

## Phase log

| Date | Phase | Outcome |
|---|---|---|
| 2026-04-22 | Discovery | Lineage mapped. Hypothesis: `right(id, 9)` truncates post-Oct-2025 creative IDs, INNER JOIN drops 2026 rows. |
| 2026-04-22 | Phase 1 — Diagnose | `diagnose/diagnose.sql` run. Stitch healthy. `right(id, 9)` drops 2026 rows at the 10-digit ID threshold. `split_part(id, ':', -1)` recovers 100% coverage, zero collisions. See `findings.md`. |
| 2026-04-22 | Phase 2 — Draft | Drop-in dbt files in `dbt-updates/`, post-prod QA in `verify/verify.sql`, implementation steps in `runbook.md`, `commit-message.txt` and `pr-description.md` ready. |
