---
table: soundstripe_prod.finance.fct_ltv_subscription_projections
last_calibrated: 2026-04-30
schema_hash: cee10897bd15afb5bf2ea979b61441a260d9aa03993fea5f9f30402eac2874f1
dbt_model: marts/finance/fct_ltv_subscription_projections.sql
row_count: 2376777
bytes_gib: 0.074
col_count: 21
---

# finance.fct_ltv_subscription_projections — Calibration

## Purpose (business meaning)

Per-subscription lifetime value table combining actual invoice payments with model-based revenue projections. Each subscription appears as multiple rows — one per billing month (actual or projected) — enabling cumulative LTV calculations at 1-year, 3-year, or 5-year horizons. The table is the primary source for LTV cohort reporting in Looker (Product KPIs dashboard, tile: "1-Yr LTV by cohort"). It supports LTV comparisons across plan tier (creator, pro, pro-plus, business, twitch-pro) and billing cycle (month, quarter, year), and carries attribution columns (channel, session) to answer "what is the LTV of the organic-search cohort" or "what is the LTV per plan purchased through paid social." No schema.yml description exists in the dbt repo — this purpose is derived from the model SQL and LookML view context.

## Lineage

- **dbt model:** `context/dbt/models/marts/finance/fct_ltv_subscription_projections.sql`
- **Upstream dbt refs:**
  - `ref("dim_ltv_subscriber_payments")` — actuals leg: one row per (subscription, invoice payment); sourced from `PC_STITCH_DB.CHARGEBEE.INVOICES` via `stg_invoices`
  - `ref("dim_ltv_subscriber_projections_monthly")` — projections leg: one row per (subscription, future month); uses `subscription_ltv_assumptions.sql` retention curve lookups
  - `ref("subscription_periods")` — provides `CONVERTING_SESSION_ID` and `LAST_CHANNEL_NON_DIRECT`; sources session data from `ref("fct_sessions")` via a `CREATED_SUBSCRIPTION = 1` filter + first-session QUALIFY
- **Upstream raw sources (via subscription_periods and dim_ltv_subscriber_payments):**
  - `source("soundstripe", "subscriptions")` — raw Chargebee subscription records
  - `source("soundstripe", "users")` — raw user profile attributes (business_type, project_types, user_type)
  - `PC_STITCH_DB.CHARGEBEE.INVOICES` — raw invoice payments
- **dbt tags:** none declared in model config
- **Materialization:** `table` (full rebuild on each run — no incremental logic)
- **Incremental watermark behavior:** n/a — full table rebuild. The late-arrival drop issue documented in `project_statsig_model_late_arrival_open.md` (incremental predicate filtering on event watermark) does NOT apply here. This model rebuilds from scratch on every run.

## Columns (primary + frequently used)

| Column | Type | Source | Description | Known nulls / gotchas |
|---|---|---|---|---|
| `subscription_id` | TEXT | `dim_ltv_subscriber_payments.subscription_id` / `dim_ltv_subscriber_projections_monthly.subscription_id` | Chargebee subscription identifier. Shared across both actuals and projections legs. | NOT a unique row identifier — the PK for a row is `(subscription_id, months_to_invoice, value_type)` |
| `soundstripe_subscription_id` | NUMBER | `soundstripe.subscriptions.id` | Internal Soundstripe numeric subscription ID | Used to join back to raw `subscriptions` source; hidden in LookML |
| `value_type` | TEXT | Hardcoded in UNION | `'invoice payment'` for actual revenue rows; `'projected payment'` for model-based projection rows. | Critical filter for any revenue SUM — see pitfalls |
| `months_to_invoice` | NUMBER | `dim_ltv_subscriber_payments.months_to_invoice` / `dim_ltv_subscriber_projections_monthly.months` | Month offset from subscription start (0 = first month). Used to bound LTV windows (e.g., `<= 12` for 1-yr LTV). | Projections leg uses `months` alias from the projections model; actuals leg uses the column directly |
| `months_into_subscription` | NUMBER | Upstream dim models | Count of months elapsed in subscription as of the model run date | Used in LookML `ltv_1_yr_total` filter: `months_into_subscription <= 12` |
| `total_amount_paid` | FLOAT | `SUM(invoice amount)` for actuals; `SUM(value_assumption)` for projections | Revenue amount for this row. FLOAT. **Includes both actual and projected rows unless `value_type` is filtered.** | See pitfall 1 |
| `plan_type` | TEXT | `subscription_periods` / `dim_ltv_subscriber_payments` | Plan tier: `creator`, `pro`, `pro-plus`, `business`, `twitch-pro`. `pro-plus` uses hyphen (not space) in warehouse; check against LookML filter values. | `enterprise` may appear in raw data but is not in the `subscription_ltv_assumptions` reference set — projection rows for enterprise subscriptions fall back to `pro` assumption via coalesce logic in `dim_ltv_subscriber_payments` |
| `billing_period_unit` | TEXT | Chargebee | Billing cycle: `month`, `quarter`, or `year` | Enum from `subscription_ltv_assumptions`; any value outside {month, quarter, year} has no projection assumption row |
| `plan_detail` | TEXT | `dim_ltv_subscriber_payments` | Concatenation of `plan_type \|\| '\|' \|\| billing_period_unit` (e.g., `pro\|year`). | Uses pipe `\|` separator, not space — different from the LookML `plan_cohort` dimension (which uses space). Do not mix the two. |
| `sub_start_date` | DATE | `subscription_periods.start_date` | Subscription start / cohort date. The primary dimension for time-based cohort analysis. | All timeframes exposed in LookML (date, week, month, quarter, year) |
| `sub_end_date` | DATE | `subscription_periods.end_date` | Subscription end date. For active (non-cancelled) subscriptions, sourced as `COALESCE(cancelled_at, current_term_end)`. Defaults to `'2099-12-25'` for active subs in the projections model. | Active subscriptions show a far-future sentinel date, not NULL |
| `current_contract_state` | TEXT | derived in this model (not on `subscription_periods`) | Current subscription state (e.g., `active`, `cancelled`). **Pitfall:** despite the name, this column does NOT exist on `core.subscription_periods` — it is computed/joined into this LTV table specifically. Confirmed via `information_schema.columns` 2026-04-30. Do not reference `subscription_periods.current_contract_state` in queries; it will error. Use `cancelled_at IS NOT NULL` derived state if querying subscription_periods directly. | |
| `retention_assumption` | FLOAT | `subscription_ltv_assumptions` seed | Monthly retention probability from the LTV model. NULL for `'invoice payment'` rows (actual data has no retention assumption). | Always NULL on actuals rows — do not aggregate |
| `overall_retention` | FLOAT | `subscription_ltv_assumptions` | Cumulative retention at this month offset. NULL for actuals rows. | Always NULL on actuals rows |
| `converting_session_id` | TEXT | `subscription_periods` → `fct_sessions.session_id` | Session ID of the first converting session for this subscription. | See pitfall 3 for contamination inheritance |
| `last_channel_non_direct` | TEXT | `subscription_periods` → `fct_sessions.last_channel_non_direct` | Last non-direct marketing channel at the time of subscription conversion. | Inherits fct_sessions contamination zones. See pitfall 3. |
| `business_type_array` | TEXT | `LISTAGG(DISTINCT users.business_type)` | Business types declared by the user — concatenated string, not an array. | See pitfall 4 |
| `project_types` | TEXT | `LISTAGG(DISTINCT users.project_types)` | Project types declared by the user — concatenated string, not an array. | See pitfall 4 |
| `user_types` | TEXT | `LISTAGG(DISTINCT users.user_type)` | User types declared by the user — concatenated string, not an array. | See pitfall 4 |

Full schema (21 cols): `SELECT column_name, data_type FROM soundstripe_prod.information_schema.columns WHERE table_schema = 'FINANCE' AND table_name = 'FCT_LTV_SUBSCRIPTION_PROJECTIONS' ORDER BY ordinal_position`.

## Canonical joins

| To table | On | Cardinality | Notes |
|---|---|---|---|
| None needed for LTV aggregates | — | — | This table is pre-joined. All subscription, user, session, and projection attributes are in a single wide row. No additional joins are required for standard LTV reporting. |
| `finance.subscription_ltv_assumptions` | Reference only — join already materialized | — | Retention curve lookup baked in at model build time. Do not re-join at query time. |
| `core.fct_sessions` | `fct_ltv_subscription_projections.converting_session_id = fct_sessions.session_id` | M:1 | For pulling additional session attributes not carried in this table. Join is LEFT — `converting_session_id` is NULL when no converting session was matched (anonymous or pre-session-tracking conversions). |

## Grain & identity

- **Grain:** one row per (subscription_id, months_to_invoice, value_type). A single subscription produces N actuals rows (one per paid invoice month) plus M projection rows (one per future month through the model horizon).
- **Primary key:** composite `(subscription_id, months_to_invoice, value_type)` — no single-column PK. `subscription_id` alone is NOT unique.
- **Distinct-subscription column:** `subscription_id` for `COUNT(DISTINCT subscription_id)` — the correct way to count subscriptions from this table.
- **Distinct-user column:** `soundstripe_subscription_id` → join to `subscriptions.user_id` for user-grain analysis. No direct `user_id` column in this table.

## Typical usage patterns

- **LTV window bounding:** filter `months_into_subscription <= 12` for 1-yr LTV, `<= 36` for 3-yr, `<= 60` for 5-yr. The LookML `ltv_1_yr_total` measure does this via a `filters` block on `months_into_subscription`.
- **Revenue type separation:** always declare intent — actuals only (`value_type = 'invoice payment'`), projections only (`value_type = 'projected payment'`), or combined (no filter, summing both). The LookML `ltv_1_yr_total` sums both by design to produce blended LTV for in-flight cohorts.
- **Self-serve filter:** exclude `plan_type IN ('enterprise', 'twitch-pro')` for product KPI tiles. The LookML `is_self_serve` dimension (`plan_type NOT IN ('enterprise', 'twitch-pro')`) implements this.
- **Cohort grouping:** group by `sub_start_date` (truncated to month or quarter) + `plan_type` + `billing_period_unit` for standard cohort LTV reporting.
- **Date scoping:** the table has no event-timestamp column — it is a static snapshot rebuilt on each dbt run. No date predicate is needed for performance. At 2.4M rows and 74 MB, full-table scans are cheap.
- **Canonical queries:** none yet in `knowledge/query-patterns/`. First verified query from `lookml/tasks/2026-04-25-product-kpis-ltv-cohort/verify/sanity_checks.sql` is a promotion candidate after its second use.

## Known pitfalls

### 1. `SUM(total_amount_paid)` mixes actuals and projections by default

`value_type` takes two values: `'invoice payment'` (real collected revenue) and `'projected payment'` (model-based future expectation). Both populate `total_amount_paid`. An unfiltered `SUM(total_amount_paid)` adds actual and projected revenue together. This is intentional for blended LTV calculations on in-flight cohorts (where some months are actual, later months are projected), but will produce inflated numbers for any query intended to measure only realized revenue (e.g., a cash-collection report). Always declare intent and filter `value_type` explicitly.

### 2. `COUNT(*)` does not equal subscription count; `COUNT(DISTINCT subscription_id)` is required

The grain is per (subscription, month offset, value_type). A subscription that is 12 months old with both actuals and projections through month 60 will produce ~72 rows. `COUNT(*)` / 2.4M rows is not a subscription count. Use `COUNT(DISTINCT subscription_id)` for subscription headcount. The LookML `subscription_count` measure (`count_distinct` on `subscription_id`) is the correct pattern.

### 3. `last_channel_non_direct` inherits fct_sessions contamination zones

`LAST_CHANNEL_NON_DIRECT` flows into this table via `subscription_periods`, which pulls it from `fct_sessions` using a `CREATED_SUBSCRIPTION = 1` + first-session QUALIFY. This means it carries all contamination documented in `core__fct_sessions.md`:

- **Contamination zone 1 (2026-03-05 → 2026-03-25):** Fastly shield POP artifact inflated Direct sessions (~160K excess). Subscriptions that converted during this window may have `last_channel_non_direct = 'Direct'` as an artifact of the pre-render infrastructure event rather than genuine direct intent. Signature: `last_channel_non_direct = 'Direct'`, converting session country IN (`DE`, `NL`, `CA`).
- **Contamination zone 2 (2026-04-14 → 2026-04-17):** APAC-sourced Direct spike (OPEN — root cause unconfirmed). Subscriptions converting in this window may be similarly affected.
- **Cross-session attribution carry-forward:** `last_channel_non_direct` in `fct_sessions` is a LAST_VALUE window over the visitor's entire history. A subscription that converts via a Direct session may still show a prior-channel attribution if the visitor previously had a non-direct session.

For channel-attributed LTV analysis touching conversion dates in either contamination window, apply the contamination filter from `core__fct_sessions.md` via a JOIN to `fct_sessions` on `converting_session_id`.

### 4. `business_type_array`, `project_types`, `user_types` are LISTAGG strings, not arrays

These columns are produced by `LISTAGG(DISTINCT <col>)` in the dbt model's final SELECT, which concatenates multiple values with a comma by default. They are TEXT, not ARRAY or VARIANT. You cannot use `ARRAY_CONTAINS` or JSON functions on them. For filtering or counting specific values, use `LIKE '%<value>%'` or `SPLIT_TO_TABLE`. Multiple values per user are possible; a single-value assumption will miss multi-valued rows.

### 5. `plan_detail` uses pipe separator; LookML `plan_cohort` uses space

The warehouse `plan_detail` column is `plan_type || '|' || billing_period_unit` (e.g., `pro|year`). The LookML `plan_cohort` dimension concatenates with a space: `plan_type || ' ' || billing_period_unit` (e.g., `pro year`). These are not interchangeable in WHERE clauses. Use `plan_type` + `billing_period_unit` separately for filtering to avoid the separator discrepancy.

### 6. `pro-plus` vs `pro plus` — plan_type naming in assumptions vs warehouse

The `subscription_ltv_assumptions` seed (updated 2025-07-18) uses `pro-plus` (hyphen). The old commented-out assumptions block used `pro plus` (space). The current warehouse `plan_type` values should follow the hyphenated form. Verify with `SELECT DISTINCT plan_type FROM soundstripe_prod.finance.fct_ltv_subscription_projections` if filtering on plan_type = 'pro-plus' returns unexpected zeros.

### 7. Active subscriptions have sentinel `sub_end_date = '2099-12-25'`

Active (non-cancelled) subscriptions receive `sub_end_date = '2099-12-25'` in `dim_ltv_subscriber_payments` rather than NULL. Date range filters on `sub_end_date` will include these rows if the upper bound exceeds 2099-12-25. For "currently active" filtering, use `current_contract_state = 'active'` rather than a date-based filter.

### 8. Late-arrival drop (Statsig incremental pattern) does NOT apply

The open issue `project_statsig_model_late_arrival_open.md` describes an incremental model dropping late-arriving rows because the incremental predicate filters on event_ts > current watermark. `fct_ltv_subscription_projections` is materialized as `table` (full rebuild) — it has no incremental predicate. Late-arriving invoices or subscription updates will appear on the next full rebuild. No analogous late-arrival risk exists for this model.

## Cost profile (from query_history; 4 queries, above the 3-row floor)

- **P50 elapsed:** ~1,100 ms
- **P95 elapsed:** ~2,564 ms
- **P50 bytes scanned:** ~885 bytes (information_schema / metadata queries)
- **Largest scan observed:** ~443 KB at 2,564 ms elapsed (235 rows produced — likely a filtered aggregate)
- **Full-table characteristics:** 2.4M rows, 74 MB. At this size, an unscoped `SELECT *` or full-table aggregate costs well under $0.01 on X-Small. Date predicates are not required for cost control, but `value_type` and `months_into_subscription` filters are required for result correctness.
- **Avoid:** `SUM(total_amount_paid)` without a `value_type` filter when the intent is realized revenue only; `COUNT(*)` when the intent is subscription count.

Note: 4-query history is a small sample. P95 is likely understated. Profile will improve as the table is used in LookML explores.

## Prior analyses referencing this table

None found in `analysis/` as of 2026-04-25. This is the first touch of this table in the d7dev workspace.

- `lookml/tasks/2026-04-25-product-kpis-ltv-cohort/` — Product KPIs dashboard LTV tiles; first use of this table. Verify SQL at `verify/sanity_checks.sql` is the next artifact.

## LookML semantics

Primary view (in-development): `lookml/tasks/2026-04-25-product-kpis-ltv-cohort/lkml/views/fct_ltv_subscription_projections.view.lkml`
Target Looker repo path: `views/Finance/fct_ltv_subscription_projections.view.lkml`
No existing view in `context/lookml/` references this table — this is a net-new view.

Key measures:
- `subscription_count` — `COUNT(DISTINCT subscription_id)` — correct subscription headcount denominator; do not use `COUNT(*)`.
- `ltv_1_yr_total` — `SUM(total_amount_paid)` filtered to `months_into_subscription <= 12` — blended actual + projected 1-yr revenue. Value is sensitive to cohort size (newer cohorts have more projection rows; older cohorts are mostly actuals).
- `ltv_1_yr_per_subscription` — `ltv_1_yr_total / NULLIF(subscription_count, 0)` — per-subscription 1-yr LTV; the headline metric for cohort comparison tiles. NULLIF guards against division by zero on empty cohorts.

Key dimensions for cohort analysis:
- `plan_type` + `billing_period_unit` (or `plan_cohort` which concatenates them with a space)
- `is_self_serve` — `plan_type NOT IN ('enterprise', 'twitch-pro')` — default explore filter for Product KPIs tiles
- `sub_start_date` (dimension group) — cohort month; truncate to `sub_start_month` for time-series tile
- `value_type` — filter to `'invoice payment'` for realized-revenue-only views
- `last_channel_non_direct` — acquisition channel; use with contamination-zone awareness (see pitfall 3)
