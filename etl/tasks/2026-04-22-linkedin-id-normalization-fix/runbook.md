# Runbook — LinkedIn creative_id normalization fix

Implementation guide for promoting the Phase 2 dbt edits through dbt Cloud, validating against `soundstripe_prod`, and refreshing the `Ad Content Performance` Looker dashboard.

## Summary of the change

- Replace `right(id, 9)` with `split_part(id, ':', -1)` in two LinkedIn staging models so the creative-id join key matches LinkedIn URN semantics (numeric tail) instead of a length-based truncation that breaks once IDs grow past 9 digits.
- Add `unique` + `not_null` tests on the normalized `creative_id` in both models via a new `schema.yml`.
- No LookML code changes required. The `ad_id` column name stays identical; only underlying values shift for post-Oct-2025 creatives.
- No incremental-table backfill needed. Both staging models are views; `fct_ad_performance` and `dim_ad_content` materialize as tables that rebuild fully on every prod run.

Root cause evidence: `findings.md` in this task directory.

## Deployment workflow (repo SOP)

All dbt commands target `soundstripe_dev`. Production updates only via PR merge to `main`. No local dbt CLI — all model edits and runs happen in the dbt Cloud web IDE on `develop_dab`.

---

## Step 1 — Apply the file updates in dbt Cloud on `develop_dab`

1. Open dbt Cloud IDE. Confirm the active branch is `develop_dab` (if it isn't, pull latest and check it out).
2. Apply each file change. Source files to copy from are in `etl/tasks/2026-04-22-linkedin-id-normalization-fix/dbt-updates/`.

| dbt Cloud path | Action | Source in d7dev |
|---|---|---|
| `models/staging/linkedin_ads/stg_fct_creatives.sql` | Replace entire file | `dbt-updates/stg_fct_creatives.sql` |
| `models/staging/linkedin_ads/stg_linkedin_ads_creative_content.sql` | Replace entire file | `dbt-updates/stg_linkedin_ads_creative_content.sql` |
| `models/staging/linkedin_ads/schema.yml` | Create new file | `dbt-updates/schema.yml` |

3. Save all three files in the IDE.

## Step 2 — Build in dev

From the dbt Cloud command bar, run:

```
dbt build -s +fct_ad_performance +dim_ad_content
```

Targets `soundstripe_dev`. This rebuilds the two modified staging models plus every downstream dependency through `fct_ad_performance` and `dim_ad_content`.

Expected outcome: all builds succeed, all tests pass (including the new `unique` + `not_null` on `creative_id`).

If either new test fails: STOP. A failure means the current LinkedIn creatives population has a collision or a null URN — Phase 1 Q6 showed zero of either, so any failure is a fresh signal to diagnose.

## Step 3 — Spot-check in `soundstripe_dev`

Run this against the dev build before opening the PR:

```sql
-- 2026 LinkedIn spend should now be present in dev
SELECT DATE_TRUNC('MONTH', date) AS month
     , COUNT(*) AS row_count
     , SUM(spend) AS total_spend_usd
FROM soundstripe_dev.marketing.fct_ad_performance
WHERE platform = 'linkedin'
  AND marketing_test_ind = 0
  AND date >= '2026-01-01'
GROUP BY 1
ORDER BY 1 DESC;
```

Expected: one row per 2026 month with non-zero spend (Jan ≈ 569 USD, Feb ≈ 3,616, Mar ≈ 7,208, Apr ≈ 5,037 — from Phase 1 analytics totals).

Also:

```sql
-- LinkedIn creative_name join coverage in dev
SELECT DATE_TRUNC('MONTH', f.date) AS month
     , COUNT(*) AS row_count
     , ROUND(100.0 * SUM(CASE WHEN d.creative_name IS NOT NULL THEN 1 ELSE 0 END) / NULLIF(COUNT(*),0), 1) AS pct_named
FROM soundstripe_dev.marketing.fct_ad_performance f
LEFT JOIN soundstripe_dev.marketing.dim_ad_content d
    ON f.ad_id = d.ad_id AND f.platform = d.platform
WHERE f.platform = 'linkedin'
  AND f.marketing_test_ind = 0
  AND f.date >= '2026-01-01'
GROUP BY 1
ORDER BY 1 DESC;
```

Expected: `pct_named` ≥ ~90% for the months where Taylor has named the creatives.

## Step 4 — Commit on `develop_dab`

Use the commit message in `commit-message.txt`. Stage the three files in dbt Cloud's Git panel and commit.

Do not run any DELETE against `soundstripe_prod`. The affected models are a view, a view, and two full-refresh tables. Incremental-watermark prep is not required.

## Step 5 — Open PR `develop_dab` → `main`

Use the PR body from `pr-description.md`. CI on the PR runs build + tests on the affected models.

## Step 6 — Merge after CI passes

Merge to `main`. This triggers the scheduled production deployment that rebuilds `stg_fct_creatives`, `stg_linkedin_ads_creative_content`, `fct_ad_performance`, and `dim_ad_content` in `soundstripe_prod`.

## Step 7 — Wait for prod build to complete

Confirm in dbt Cloud's run history that the prod build finished successfully before running any QA against prod.

---

## Step 8 — QA against `soundstripe_prod`

Open `verify/verify.sql` in a Snowflake worksheet. Run each labeled section (V1–V5) and export each result to the matching `vN.csv` in `verify/`.

| Query | Expected |
|---|---|
| V1 — 2026 LinkedIn spend by month | Non-zero `total_spend_usd` for every month Jan–Apr 2026. Totals approximately match the Phase 1 analytics snapshot (569 / 3,616 / 7,208 / 5,037 USD). |
| V2 — LinkedIn creative_name coverage on 2026 rows | `pct_named ≥ 90%` on each 2026 month where Taylor named creatives. Older unnamed creatives stay NULL (expected). |
| V3 — Facebook regression | `pct_named` and `total_spend_usd` per month unchanged vs pre-merge. Any material shift means roll back. |
| V4 — `dim_ad_content` PK integrity | Zero rows returned. |
| V5 — Named creative spot-check | Named 2026 creatives appear (e.g., `Duplicate_Buyers_Guide_v*_FORM`, `Cheatsheet_Pink`) with non-zero `total_spend_usd`. |

If any of V1, V2, V4, V5 fail their expectations, go to the Rollback section before touching Looker. If V3 regresses Facebook, same — roll back.

---

## Step 9 — Looker refresh and validation

No LookML code edits required. The `ad_content_performance` explore still joins on `fct_ad_performance.ad_id = dim_ad_content.ad_id`; only the underlying Snowflake values changed.

**Clear dashboard cache.**

1. Open the `Ad Content Performance` dashboard in Looker.
2. Gear menu (top-right) → **Clear cache and refresh**. Wait for all tiles to reload.

**Validate the dashboard.**

1. Apply filters: `Platform = linkedin`, `Date = last 90 days`.
2. Confirm:
   - Spend scorecard is non-zero (pre-fix it was ~0).
   - Impressions and Clicks scorecards populate.
   - Spend trend line shows a LinkedIn series with non-zero values for 2026 months.
   - Top Ads detail table shows several rows with `creative_name` populated for 2026-active ads.
3. Switch filter to `Platform = facebook`. Confirm spend totals and CTA / creative-format tiles look unchanged from pre-merge values.

**Content Validator (optional).**

Looker Admin → **Content Validator**. Run against the `soundstripe_prod` model. Expected: no new errors referencing `fct_ad_performance`, `dim_ad_content`, or `ad_content_performance`.

---

## Step 10 — Close the Asana ticket

Post a comment on the `Ad Content Looker Reporting` ticket with:

- One-line root cause: "`right(id, 9)` truncated LinkedIn creative IDs that grew past 9 digits in late 2025, which caused the staging INNER JOIN to drop every recent creative."
- Pre-fix vs post-fix 2026 spend total from V1 (write as `16,430 USD` — no bare `$` per the platform-safe formatting rule).
- Named-creative coverage pct from V2 on the most recent full month.
- PR link.
- Pointer to `verify/` so Taylor can reconcile against LinkedIn Ads Manager.

---

## Rollback

If V1/V2/V4/V5 fail post-prod or V3 regresses Facebook:

1. Revert the PR on `main`. Wait for the prod deployment to rebuild from the reverted commit.
2. Re-open this task workspace and re-run Phase 1 diagnostics (`diagnose/diagnose.sql`) against the reverted state to isolate the new signal before attempting a second fix.

No manual backfill is needed on rollback. The staging models are views; `fct_ad_performance` and `dim_ad_content` rebuild fully on every run.
