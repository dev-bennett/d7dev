# 2026-04-30 — Supe Usage Tracking Foundation

- **Status:** deployed 2026-04-30 18:56 UTC; schema review complete (see below); awaiting Stitch pickup before downstream dbt work
- **Date:** 2026-04-30
- **PR:** [SoundstripeEngineering/api#4147](https://github.com/SoundstripeEngineering/api/pull/4147) — merged 2026-04-30 18:56 UTC; head `feat/per-request-usage-tracking` → `master`; +5,714 / -98 across 76 files
- **Models touched:** none yet on the data side. Downstream dbt sources / staging models will follow once tables land in `pc_stitch_db` (or wherever Stitch picks them up).
- **Source:** AJ Robertson Slack heads-up, 2026-04-30 11:03 AM
- **Stakeholder / engineering owner:** AJ Robertson
- **Reference doc:** [Data Team Reference — Supe Usage Tracking Tables](https://www.notion.so/soundstripe/Data-Team-Reference-Supe-Usage-Tracking-Tables-35109a5cfadb812dbf08c8eaaf43ab12) (Notion; sits alongside existing `supe_searches` + eval-table references under "Supe Search Enterprise API")

## Timeline

- **2026-04-30 11:03 AM** — AJ heads-up Slack (planned ship by end of week, schema doc shared)
- **2026-04-30 5:17 PM** — AJ confirms PR shipped this morning, test data seeded in the new tables. Schema-review gate is now open. Stitch pickup status TBC — verify before downstream dbt work.

## Originating message — AJ Robertson, 2026-04-30 11:03 AM

> Heads up: I'm planning to ship the Supe usage tracking foundation (PR #4147) by end of week. It adds five new tables (supe_pricing_tables, supe_contract_terms, supe_usage_events, supe_usage_snapshots, supe_usage_rollup_runs) plus a couple of new columns on contracts and supe_searches. The append-only supe_usage_events ledger is the new bill of record for the Supe enterprise API: one row per request, with frozen contract/term context and Soundstripe's estimated LLM cost.
>
> I wrote up a data team reference page covering schemas, indexes, CHECK constraints, billable status meanings, data volume expectations, and a handful of starter queries (daily volume, period-to-date vs. limit, failure rate, cache hit rate, gross margin): https://www.notion.so/soundstripe/Data-Team-Reference-Supe-Usage-Tracking-Tables-35109a5cfadb812dbf08c8eaaf43ab12. It sits alongside the existing references for supe_searches and the eval tables under the Supe Search Enterprise API page.
>
> No customer traffic is hitting these tables yet (Amazon hasn't turned on), so initial volume will be near-zero. Let me know if anything in the schema looks off or if there are queries you'd want me to add to the doc.

## Scope (engineering side, AJ's PR)

- **5 new tables**
  - `supe_pricing_tables` — pricing reference for Supe enterprise API
  - `supe_contract_terms` — per-contract term definitions / limits
  - `supe_usage_events` — **append-only ledger; bill of record.** One row per Supe enterprise-API request, with frozen contract/term context and Soundstripe's estimated LLM cost
  - `supe_usage_snapshots` — periodic rollup snapshots (cadence TBC from schema)
  - `supe_usage_rollup_runs` — metadata on rollup-job executions
- **2 modified tables**
  - `contracts` — new columns (TBC)
  - `supe_searches` — new columns (TBC)

## Volume expectation

Near-zero on launch. Amazon (the launch customer) hasn't turned on the API yet. Initial period will be primarily internal traffic / smoke tests. Expect material volume only after Amazon activation.

## Schema review (Notion doc + PR #4147 migration diff, 2026-04-30)

### Reconciliation: doc vs migrations

All 5 new tables and 2 modified tables match the doc on column names, types, nullability, defaults, FKs, CHECK constraints, and primary indexes. The tuning migration `20260428000000_tune_supe_usage_event_indexes.rb` (5 days after the original) DROPs a single-column index on `source` (cardinality 2 — planner ignores) and ADDs a single-column index on `occurred_at` for non-api_key-leading time-range scans. The doc reflects the post-tuning state.

### Substantive findings

**1. The "Soundstripe cost vs. customer overage revenue" example query overstates customer revenue.** `customer_overage_rate_cents` is the per-event overage RATE, charged only when usage exceeds `Contract.supe_operation_limit`. The doc query sums it across ALL `billable` / `cached_billable` rows in a 30-day window — that conflates "overage rate × all billable events" with "overage rate × events beyond limit." Today with seed `overage_rate_cents = 0` across all contracts the bug is hidden (sum is zero regardless). Once a real rate is set, the query overstates revenue by the count of in-limit events × rate. A correct version needs to subtract `LEAST(events_in_period, supe_operation_limit)` from the billable count before multiplying.

**2. `source` no longer has a dedicated index.** Per the tuning migration. Filtering `WHERE source = 'live'` cannot use an index. Always combine with a selective predicate (typically an `occurred_at` range). Snapshots are pre-filtered to `live` on the application side (rollup excludes backfilled rows), so this caveat is event-grain only.

**3. Snowflake date reconstruction.** Snapshots store dates as `(year, month, day)` integer columns. Snowflake equivalent of Postgres `MAKE_DATE` is `DATE_FROM_PARTS(year, month, day)`. The dbt staging model should derive a single `bucket_date` column up-front to keep downstream queries clean. None of the doc example queries Snowflake-translate cleanly without this swap.

**4. Pricing-table prefix-match is runtime-only.** `Supe::Pricing.estimate` resolves the pricing key via `LIKE model || '%'` and writes the resolved row's `pricing_version_id` onto the event. Downstream warehouse joins should always join on `pricing_version_id`, never on `model || '%' LIKE` semantics. The point-in-time "active price for a given model" example query in the doc does the prefix-match correctly because that's the resolution use case, not an event join.

**5. Frozen-billing-context invariant.** `contract_id`, `contract_term_id`, `customer_overage_rate_cents` snapshotted at write time. Rule for the data team: aggregations that need bill-of-record values must use the columns on the event row, NOT joins to the live `supe_contract_terms` / `contracts`. Worth promoting to a calibration pitfall once `supe_usage_events` has volume.

### Doc-drift items (low-priority for AJ)

- Doc's `supe_usage_events` index table lists "Single `api_key_id`" and "Single `supe_search_id`" as FK-auto-generated. Migration suppresses both via `t.references ..., index: false`. Composite indexes (`api_key_id, occurred_at`) and partial-unique (`supe_search_id WHERE NOT NULL`) cover the access patterns. Functionally fine; doc's index list is two entries off.
- Doc lists the `source` index as "removed in the tuning migration" implicitly (does not appear in the index table). Inferred correctly from the post-tuning state but not called out as a deliberate decision. Worth one sentence in the doc explaining why (cardinality 2 → planner ignores).

### Open questions for AJ

1. **NullContract + cache-hit interaction.** Can a NullContract path emit `cache_hit = TRUE` events? A `null` contract still has a cache key, so presumably yes — but worth confirming that the four runtime command objects (`record_cache_hit`, `record_cache_miss_*`, `record_stuck_search_event`) do not short-circuit when the api_key has no contract. Affects the data-quality monitor design (see §5 below).
2. **"Contract period" semantics for `supe_operation_limit`.** Doc's period-to-date query uses `c.start_date` to `c.end_date` (full contract span). Is the cap evaluated against the full contract, or per billing-month / billing-period? Affects the operational rate-limit-headroom view.
3. **Index suppression intent.** Is suppressing the FK-auto indexes on `api_key_id` and `supe_search_id` deliberate (composite + partial-unique cover all reads), or a side-effect that just happens to work?

## Downstream data-team work (sequenced)

### 1. Verify Stitch pickup

Query `pc_stitch_db.information_schema.tables WHERE table_name ILIKE 'supe_%'` to confirm the 5 new tables are replicated. AJ said "test data seeded" so rows exist on the source side; warehouse pickup depends on Stitch's discovery cadence.

### 2. Source registration in dbt (post-Stitch-pickup)

- Add the 5 new tables to the existing Supe sources file in `context/dbt/models/staging/<supe_dir>/_sources.yml` (alphabetical insertion; complete file replacement per dbt-standards.md)
- Replication keys per `feedback_dbt_schema_test_consistency.md`:
  - `supe_usage_events` — append-only; `id` is fine
  - `supe_pricing_tables`, `supe_contract_terms`, `supe_usage_snapshots`, `supe_usage_rollup_runs` — rows update; use `updated_at`
- Schema tests: `not_null` + `unique` on PKs; `accepted_values` for the documented enums (`billable_status`, `operation_type`, `source`, `finish_reason`, `status` on rollup runs); `relationships` tests for the FKs that are NOT NULL on the event row (only `api_key_id` is NOT NULL — the rest are nullable by design)

### 3. Staging models (`stg_supe_*`)

- One staging model per source, 1:1 with source schema, materialization `view`
- For `supe_usage_snapshots` — derive `bucket_date AS DATE_FROM_PARTS(year, month, day)` so downstream models don't repeat the reconstruction
- For `supe_usage_events` — surface `is_billable_to_customer = billable_status IN ('billable', 'cached_billable')` and `is_failure = billable_status LIKE 'failed%'` to keep callers from re-deriving

### 4. Calibration artifacts (`/calibrate`)

- Once the tables have non-trivial volume (post-Amazon activation), produce calibration artifacts:
  - `<schema>__supe_usage_events.md` — event-grain, will likely cross the size threshold once Amazon ramps; block-and-calibrate-first per `.claude/rules/snowflake-mcp.md`
  - Smaller dim-grain tables get soft-warn promotion candidates
- Pre-Amazon launch the tables are tiny; calibration is low-value until volume arrives

### 5. Reciprocal — corrections + query adds for AJ's Notion doc

**Corrections (send back as PR-doc edits):**
- The gross-margin example query — see Finding 1 above. Replace with a limit-aware version once contract-period semantics are confirmed.
- The two doc-drift index entries on `supe_usage_events` (FK-auto indexes on `api_key_id` / `supe_search_id` are suppressed in the migration).

**Query adds AJ explicitly invited:**
- **Cohort lifetime cost-to-serve** — margin per contract over the full term (AJ has period-to-date)
- **Cost-per-request anomaly detection** — top-percentile flagging on `estimated_cost_cents` distribution; cost shocks usually = mis-priced model upgrades or runaway prompts
- **Rate-limit headroom × velocity** — period-to-date usage as % of `supe_operation_limit`, with days-remaining-in-period
- **Cache-hit rate segmented by request shape** — top-line is in the doc; segmentation drives cache-investment prioritization
- **Failure-class decomposition** — `failed_customer_fault` vs `failed_platform_fault` vs `finish_reason` breakdown, per contract
- **NullContract activity monitor** — count of events with `contract_id IS NULL` per api_key per week (data-quality monitor for AJ's `Supe::UsageMonitoringJob` to consume)

Send these to AJ as a single Slack thread or PR comment, NOT before — wait until the corrections and open questions are resolved.

## Files

- `README.md` — this file (status, context, AJ's verbatim message, downstream work plan)
- `CLAUDE.md` — directory chain to parent

(Discovery and validation queries will land in subdirectories once the tables exist in the warehouse.)

## Related context

- AJ Robertson is the engineering owner; this is an inbound dependency, not a data-team-driven build. Data-team work is reactive: review schema, register sources, build staging.
- Existing Supe references in Notion under "Supe Search Enterprise API": (a) `supe_searches` reference, (b) eval tables reference. New page is the third reference in that family.
- No memory or repo entry yet for "Supe enterprise API" or AJ Robertson's broader work — this task is the first formal data-team workspace touching it.
