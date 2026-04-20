---
status: draft
date: 2026-04-15
task: analysis/enterprise/pql/tasks/2026-04-15-knowledge-discovery
phase: A (Contacts-shape discovery)
data_refresh: 2026-04-14 18:59 UTC (latest ingest_ts)
---

# Phase A — HubSpot Contacts Object Findings

## Question

What is the full warehouse-level shape of `soundstripe_prod.hubspot.hubspot_contacts`, and which numeric score fields could plausibly be the "lead score" Ryan is seeing jump from ~0.5 to ~0.65 in February 2026?

## Methodology

Twelve queries (A1–A12) against the full table. Score-field A3 and became-field A9 queries used BERNOULLI(1) and BERNOULLI(5) samples respectively; every other query ran against the full table. Rate Declarations and Type Audits recorded per query below.

## Headline numbers

- **Total contacts:** 1,757,498 rows. All `object_type='CONTACT'`, `objecttypeid='0-1'`.
- **Ingest window:** 2026-04-09 → 2026-04-14 18:59 UTC. Freshness lag (ingest_ts vs. lastmodifieddate) is 0–1 minute per lifecyclestage — effectively real-time.
- **`SOUNDSTRIPE_INTERNAL_ACCOUNT`:** 100% `false` across the whole table (A2). Either employee/test accounts are flagged elsewhere, or the derivation (`properties:hs_internal_user_id IS NOT NULL`) is not firing. **Open question: where do internal accounts get tagged?**

## Lifecyclestage distribution (A4)

| lifecyclestage | rows | pct |
|---|---|---|
| lead | 1,488,180 | 84.68% |
| customer | 184,984 | 10.53% |
| subscriber | 44,932 | 2.56% |
| `258326067` (unmapped ID) | 20,108 | 1.14% |
| `258322204` (unmapped ID) | 4,895 | 0.28% |
| salesqualifiedlead | 4,891 | 0.28% |
| `262492257` (unmapped ID) | 4,417 | 0.25% |
| (empty) | 4,069 | 0.23% |
| opportunity | 955 | 0.05% |
| marketingqualifiedlead | 67 | 0.00% |

**Three integer-like stages** (`258326067`, `258322204`, `262492257`) are unmapped HubSpot custom-stage IDs showing as raw integers instead of labels. Likely correspond to NTR/UNQL/similar based on A9's `became_a_ntr_lead_status` / `became_a_unql_lead_status`. Worth chasing through the HubSpot pipeline config.

## Scoring-field inventory (A6, A7, A8, A10)

| field | pct populated | min | max | mean | p50 | range-fit for Ryan's 0.5/0.65 |
|---|---|---|---|---|---|---|
| `snowflake__lead_score` (Polytomic) | **1.52%** | 0.15 | 0.95 | **0.572** | 0.59 | **STRONG** — overall mean 0.572, within 0.15 of Ryan's 0.5. Range is right. |
| `hs_predictivecontactscore_v2` (HubSpot vendor) | 89.44% | 0.02 | 23.14 | 1.43 | 1.07 | Overall no; **by lifecyclestage: subscriber mean = 0.69 (A7b)** — strong fit for Feb 0.65. |
| `customer_health_score` | 93.85% | 0 | 0 | 0 | 0 | NO — all zeros. |
| `hubspotscore` (HubSpot native rule-based) | 93.85% | -100 | 30 | -6.46 | 2 | NO — range and mean wrong. |
| `lead_score_2_0` | 93.85% | -119 | 359 | -33.98 | -54 | NO. |
| `new_member_health_score` | 93.85% | 0 | 2 | 0.009 | 0 | NO — mean near zero. |
| `ryan___lead_score_value` | 93.85% | 0 | 95 | 3.64 | 2.5 | NO. |

**Primary candidates for Ryan's field (ranked):**
1. `snowflake__lead_score` — the Polytomic write-back from the XGBoost pipeline. Mean 0.572 across the full table sits almost exactly at the midpoint of Ryan's 0.5 → 0.65 story.
2. `hs_predictivecontactscore_v2` filtered to `lifecyclestage='subscriber'` — subscriber mean is 0.69.

Neither is ruled out by A-series alone; C2's monthly stratified means will disambiguate.

### Lifecyclestage × `hs_predictivecontactscore_v2` (A7b)

| lifecyclestage | with_score | mean | p50 |
|---|---|---|---|
| lead (84.7% of table) | 100% | 1.43 | 1.08 |
| customer | 7.2% | 2.51 | 2.61 |
| **subscriber** | 100% | **0.69** | 0.50 |
| salesqualifiedlead | 100% | 3.11 | 2.83 |
| opportunity | 100% | 3.64 | 2.5 |
| marketingqualifiedlead | 100% | 3.66 | 3.66 |

Subscriber stage is uniquely in the 0.5–0.69 band — the exact shape of Ryan's observation.

## `became_*` fields (A9)

14 distinct became-fields enumerated. Highlights:

- **`became_a_pql_lead_status` — 564 rows, first appearance 2025-04-07**. This confirms the PQL process went live April 2025.
- **`became_a_dtc_lead_status` — 136 rows, first appearance 2025-04-10**. DTC upsell tracking also went live April 2025.
- `became_active_subscriber_date` — 9,867 rows, spans Feb 2016 → Apr 2026. The historical one.
- `became_abandon_cart_lead` — 45,660 rows, but latest activity 2024-06-25. Field appears defunct post-June 2024.
- `became_a_sal_lead_status`, `_sql_`, `_mql_`, `_unql_`, `_ntr_`, `_ent_cus_`, `_new_`, `_exclude_` — all populated with low volumes, aligned to the funnel-state taxonomy.

## `*_last_changed` scoring timestamps (A10)

**Zero rows returned.** No per-field last-changed timestamps exist in PROPERTIES for any score, predictive, or lead-related field. Implication: we cannot do temporal score-drift analysis at the per-contact per-event grain directly from `HUBSPOT.HUBSPOT_CONTACTS`; score change timing has to be inferred from the warehouse side (`enterprise_lead_scoring_model.created_ts`, `polytomic_sync_*.lead_score_ts`).

## Identity-key co-occurrence (A11)

- 1,756,785 / 1,757,498 have `email` (99.96%)
- 1,571,107 have `soundstripe_user_id` (89.4%)
- 1,570,491 have `chargebee_customer_id` (89.4%)
- 1,570,488 (**89.4%**) have ALL THREE. Nearly complete identity triple for the Soundstripe-linked subset.
- **185,681 (10.57%) are `email_only`** — no soundstripe_user_id, no chargebee_customer_id. These are marketing-only HubSpot contacts (form fills, list subscribers without account creation).
- 616 have email + soundstripe_user_id but no chargebee. 0 have email + chargebee but no soundstripe.

**Significant correction to the planned Ryan cohort-(a) definition.** Every Soundstripe user evidently gets a `chargebee_customer_id` at account creation, including free users. So "free account sign-ups" CANNOT be defined as "has email, no chargebee_customer_id" — that definition maps to marketing contacts, not free product users. Better cohort definitions for Phase C:
- **Cohort (a, revised):** `lifecyclestage='subscriber'` (44,932 contacts) — HubSpot's native convention for free subscribers
- **Cohort (b):** `has_free_account='true'`
- **Cohort (c):** `fct_sessions.SIGNED_UP=1` joined to HubSpot (Mixpanel-side)

Queries.sql C1–C6 use the filter `lifecyclestage IN ('subscriber','lead') AND chargebee_customer_id IS NULL` — this will return a population dominated by email-only marketing contacts, not free product signups. **The cohort definition should be narrowed to `lifecyclestage='subscriber'` alone for the primary cohort-(a) queries.** See the "Follow-on" section below for the revised queries.

## Freshness (A12)

All lifecyclestages show 0–1 minute lag between `lastmodifieddate` and `ingest_ts`. No sync delay concerns affect the Ryan diagnostic.

## Source distributions (A5a–A5d)

Headline from `hs_analytics_source` (A5b): OFFLINE 33%, ORGANIC_SEARCH 25%, PAID_SEARCH 19%, DIRECT_TRAFFIC 17%. PAID_SOCIAL / SOCIAL_MEDIA / REFERRALS / OTHER_CAMPAIGNS / AI_REFERRALS / EMAIL_MARKETING collectively ~5%.

`hs_object_source_label` (A5d): INTEGRATION dominates at 52.2% — most contacts enter via API (likely Soundstripe → HubSpot sync). INTERNAL_PROCESSING 23.5%, ANALYTICS 6.3%, FORM 4.5%. This lands the primary acquisition channel in Soundstripe-native product signups (not HubSpot forms).

## Preliminary signal for Ryan's question

A-series alone cannot answer Ryan's question, but it narrows the hypothesis space:

- **The two fields in Ryan's value range are `snowflake__lead_score` (mean 0.57, 1.5% coverage) and `hs_predictivecontactscore_v2` among subscribers (mean 0.69, 100% of 44,932 subscriber-stage contacts).** Other scoring fields are ruled out by range.
- Every free Soundstripe sign-up has a `chargebee_customer_id`, so planned cohort-(a) filter `IS NULL chargebee_customer_id` does not isolate free product signups. Use `lifecyclestage='subscriber'` instead.
- No per-field last-changed timestamps → temporal score-shift analysis must rely on warehouse-side timestamps (`enterprise_lead_scoring_model.created_ts`, `polytomic_sync_*.lead_score_ts`).

B1 results (in this directory, should be in `pipeline-shape/` — see below) already show a **3x jump in PQL volume Jan → Feb 2026** (321 → 1,007). Combined with the C8 git-audit finding that Jan 28 2026 commit `5491a68` changed casting in `leads_for_training.sql` and `leads_for_scoring.sql`, and the fact that `enterprise_lead_scoring_model.py` retrains from scratch every dbt run, the leading explanation for Ryan's shift is **population composition change + model retraining on modified training-data composition**, not a hand-edited scoring rule.

## Type Audits (§1)

Every rate-producing query in Phase A carried a Rate Declaration. Audits:

### A2 — `internal_account_rate`
- Declared denominator: all contacts
- JOIN chain: none (single table)
- Column used as denominator: `SUM(COUNT(*)) OVER ()`
- JOIN type enforces declared denominator: YES (no joins; OVER () = full table)
- RESULT: **PASS**

### A3 — `key_population_rate`
- Declared denominator: sampled rows
- JOIN chain: CROSS JOIN LATERAL FLATTEN (produces multiple rows per source row)
- Column used as denominator: `sample_size.n` (distinct source row count)
- JOIN type enforces declared denominator: YES — `COUNT(DISTINCT object_id)` in numerator, against source row count in denominator
- RESULT: **PASS**

### A6 — `snowflake_lead_score_coverage`
- Declared denominator: all contacts
- JOIN chain: none
- Column used as denominator: `COUNT(*)`
- JOIN type enforces declared denominator: YES
- RESULT: **PASS**

### A11 — `identity_combination_rate`
- Declared denominator: all contacts
- JOIN chain: none
- Column used as denominator: implicit `COUNT(*)` in each `COUNT_IF` over the same CTE
- JOIN type enforces declared denominator: YES
- RESULT: **PASS**

## Open questions / follow-ons

1. **Re-run C1–C6 with revised cohort (a)** = `lifecyclestage='subscriber'` only (drop the `chargebee_customer_id IS NULL` clause). See `../ryan-feb-score-shift/queries.sql` — patches needed.
2. **Run C2 against both candidate fields with the revised cohort**: `snowflake__lead_score` AND `hs_predictivecontactscore_v2`. C2 as written already covers both.
3. **Run B2–B7** to complete pipeline-shape: XGBoost model recency, Polytomic sync completeness, per-month score distributions.
4. **Move `b1.csv` from `contacts-shape/` to `pipeline-shape/`** (it was misfiled by export path).
5. Investigate `SOUNDSTRIPE_INTERNAL_ACCOUNT=100% false` across all 1.76M rows — is `hs_internal_user_id` being set by any upstream process, or is this a broken derivation?
6. The three integer-string lifecyclestages (`258326067`, `258322204`, `262492257`) should be decoded — likely NTR / UNQL / custom stage IDs.
