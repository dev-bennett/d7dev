# Phase 1 findings — LinkedIn ID normalization

## Summary

Root cause confirmed. `right(id, 9)` in `stg_fct_creatives.sql` and `stg_linkedin_ads_creative_content.sql` truncates LinkedIn creative IDs that grew past 9 digits. The INNER JOIN in `stg_linkedin_ads_ad_performance_report.sql` drops every analytics row whose numeric creative_id is 10 digits.

- Stitch is healthy. `ad_analytics_by_creative` max_date = 2026-04-21, `creatives` max_modified = 2026-04-17. Branch B (escalate) ruled out.
- Step-change confirmed: pre-2026 months 100% joined, 2026 months 0–1% joined.
- `split_part(id, ':', -1)` and `regexp_substr(id, '[0-9]+$')` each restore 100% join coverage across all months.
- All three candidate keys have 0 NULLs, 0 collisions across the 153 creatives in the current population.

**Recommend: `split_part(id, ':', -1)`** — it is tied to LinkedIn's URN format, shorter than the regex, and cannot accidentally extract embedded digits if LinkedIn ever adds a non-URN column value.

## Evidence

### Q1 — Stitch freshness (`q1.csv`)

| table | max_date | min_date | rows | distinct_keys |
|---|---|---|---|---|
| ad_analytics_by_creative | 2026-04-21 | 2024-09-30 | 1,680 | 143 |
| campaigns | 2026-04-14 | 2024-09-17 | 35 | 35 |
| creatives | 2026-04-17 | 2024-09-30 | 153 | 153 |

All three tables refreshed within the last five days. Source is not stalled.

### Q2 equivalent — ID length distribution (`q2.csv`)

| source | id_length | distinct_ids |
|---|---|---|
| analytics | 9 | 120 |
| analytics | 10 | 23 |
| creatives | 34 | 122 |
| creatives | 35 | 31 |

The URN prefix `urn:li:sponsoredCreative:` is 25 characters, so:

- creatives URN length 34 → 9-digit numeric tail (122 creatives, maps to the 120 analytics 9-digit IDs — older creatives)
- creatives URN length 35 → 10-digit numeric tail (31 creatives, maps to the 23 analytics 10-digit IDs — newer creatives)

`right(id, 9)` on a 34-char URN returns the exact 9-digit tail (safe). `right(id, 9)` on a 35-char URN drops the leading digit of a 10-digit tail (breaks the join).

### Q4 current join coverage (`q3.csv`)

| month | analytics_rows | total_spend_usd | rows_joined | pct_joined |
|---|---|---|---|---|
| 2026-04 | 233 | 5,037 | 1 | 0.4% |
| 2026-03 | 346 | 7,208 | 0 | 0.0% |
| 2026-02 | 105 | 3,616 | 1 | 1.0% |
| 2026-01 | 17 | 569 | 0 | 0.0% |
| 2025-12 | 22 | 623 | 22 | 100.0% |
| 2025-11 | 49 | 561 | 49 | 100.0% |
| ... (all prior months) | | | | 100.0% |

Step-change at 2026-01. Unjoined 2026 spend total: 16,430 USD.

### Q5 proposed key coverage (`q4.csv` / `q5.csv`)

| month | pct_right9 | pct_split | pct_regex |
|---|---|---|---|
| 2026-04 | 0.4% | 100.0% | 100.0% |
| 2026-03 | 0.0% | 100.0% | 100.0% |
| 2026-02 | 1.0% | 100.0% | 100.0% |
| 2026-01 | 0.0% | 100.0% | 100.0% |
| 2025-12 and earlier | 100.0% | 100.0% | 100.0% |

Both proposed keys fully recover 2026 coverage without regressing older months.

### Q6 key-scheme safety (`q6.csv`)

| key_scheme | total_keys | null_or_empty | colliding_keys | worst_collision |
|---|---|---|---|---|
| right_9 | 153 | 0 | 0 | 1 |
| split_colon | 153 | 0 | 0 | 1 |
| regex_numeric | 153 | 0 | 0 | 1 |

All three are currently safe. `right_9` would begin producing collisions once creatives with the same trailing 9 digits enter the population — `split_colon` is structurally immune because the URN tail is LinkedIn's actual primary key.

## Decision

Proceed with Phase 2, Branch A (dbt normalization fix). Drafts land in `dbt/` mirroring the submodule layout.
