# Fix LinkedIn creative_id normalization in staging

## Summary

- **stg_fct_creatives**: replace `right(id, 9)` with `split_part(id, ':', -1)` so the creative_id primary key reflects the full LinkedIn URN numeric tail, not a length-truncated prefix.
- **stg_linkedin_ads_creative_content**: same replacement so `dim_ad_content.linkedin_content.ad_id` stays aligned with `fct_ad_performance.ad_id`.
- **schema.yml** (new): `unique` + `not_null` tests on `creative_id` for both models.

## Root cause

LinkedIn creative URNs have the form `urn:li:sponsoredCreative:NNN…`. The prefix is 25 characters, so URN length equals 25 + numeric-tail length. `right(id, 9)` returned the full tail only while the tail was 9 digits. Starting ~Oct 2025 LinkedIn began issuing 10-digit IDs, so `right(id, 9)` truncated the leading digit on the creatives side while `ad_analytics_by_creative.creative_id` stored the raw 10-digit numeric. The INNER JOIN in `stg_linkedin_ads_ad_performance_report` on `a.ad_id = b.creative_id` silently missed every post-rollover analytics row.

## Scale of the miss (pre-fix)

Diagnostic query results (see `d7dev/etl/tasks/2026-04-22-linkedin-id-normalization-fix/findings.md`):

- `ad_analytics_by_creative.max(start_at) = 2026-04-21` — source is not stalled.
- 2026-01 through 2026-04: 0–1% of analytics rows joined under `right(id, 9)`.
- 16,430 USD of 2026 LinkedIn spend currently missing from `fct_ad_performance`.
- 100% recovery under `split_part(id, ':', -1)` across all months.
- Zero collisions and zero nulls across the 153 current LinkedIn creatives under the new key.

Marketing (Taylor) independently confirmed LinkedIn is spending more in 2026 than in 2025, which contradicts the `fct_ad_performance` = 0 signal and is consistent with the silent-join-failure diagnosis.

## Pre-merge

No DELETE against `soundstripe_prod` required. `stg_fct_creatives` and `stg_linkedin_ads_creative_content` are views; `fct_ad_performance` and `dim_ad_content` are full-refresh tables. No incremental watermark to shift.

## Test plan

- [x] `dbt build -s +fct_ad_performance +dim_ad_content` on `develop_dab` (targets `soundstripe_dev`). All builds and tests pass.
- [x] Spot-check in `soundstripe_dev`: 2026 LinkedIn spend non-zero, LinkedIn `creative_name` coverage ≥ 90% on 2026 active rows.
- [ ] Post-merge QA against `soundstripe_prod` via `d7dev/etl/tasks/2026-04-22-linkedin-id-normalization-fix/verify/verify.sql` (V1–V5).
- [ ] Looker `Ad Content Performance` dashboard cache refreshed; LinkedIn tiles show non-zero 2026 spend; Facebook tiles unchanged vs pre-merge.
- [ ] Asana ticket updated with root cause + coverage numbers + PR link.
