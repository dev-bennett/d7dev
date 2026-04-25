---
table: _external_statsig.exposures
last_calibrated: 2026-04-24
schema_hash: 1110ae4a2730d45fa0bf27e703f6b9f5cb128fa71efc364a74bc0c6a32d6be7d
dbt_model: none
row_count: 1208280
bytes_gib: 0.10
col_count: 7
---

# _external_statsig.exposures — Calibration

## Purpose (business meaning)

Raw Statsig experiment exposure events — one row per (user, experiment, assignment) exposure. This is the canonical source of truth for "who saw what variant, when" in Statsig-driven experiments. External-source table (no dbt model); landed into Snowflake by Statsig's native export.

## Lineage

- **dbt model:** none (raw external source from Statsig)
- **Upstream source:** Statsig export pipeline (not Stitch)
- **Materialization:** external table — managed by Statsig, not by dbt
- **Incremental watermark behavior:** append-only by Statsig. No warehouse-side incremental logic on this table directly; downstream consumers (`marketing.stg_exposures`, `_external_statsig.statsig_clickstream_events_etl_output`) apply their own filters

## Columns (all 7)

| Column | Type | Source | Description | Known nulls / gotchas |
|---|---|---|---|---|
| `EXPERIMENT_ID` | TEXT | Statsig | Canonical experiment name (e.g. `wcpm_pricing_test`) | Always populated |
| `GROUP_ID` | TEXT | Statsig | Variant ID (opaque) | Always populated |
| `GROUP_NAME` | TEXT | Statsig | Human-readable variant (e.g. `control`, `test`) | Prefer this over `GROUP_ID` for readability |
| `USER_ID` | TEXT | Statsig SDK | Authenticated user ID | **NULL for pre-identity exposures** — filter `WHERE user_id IS NOT NULL` before joining to user-grain tables |
| `STABLE_ID` | TEXT | Statsig SDK | Statsig stable identifier (pre-identity) | Post-consolidation sprawl — multiple STABLE_IDs per user_id is common after March 2026 |
| `TIMESTAMP` | TIMESTAMP_NTZ | Statsig SDK | Exposure event time | Primary time axis; date-scope for cost |
| `USER_DIMENSIONS` | VARIANT | Statsig SDK | Semi-structured user properties at exposure time | Query with `USER_DIMENSIONS:<key>` or `LATERAL FLATTEN` |

## Canonical joins

| To table | On | Cardinality | Notes |
|---|---|---|---|
| `core.fct_events` | `exposures.stable_id = fct_events.statsig_stable_id` + `user_id` agreement | N:M (sprawl) | **Post-consolidation stable_id sprawl** (2026-03+) breaks strict 1:1. Use first-exposure-per-user-per-experiment pattern below |
| `core.dim_users` | `exposures.user_id = dim_users.id` | M:1 | Straightforward when `user_id IS NOT NULL` |

## Grain & identity

- **Grain:** one row per exposure event (a user can be re-exposed multiple times in the same experiment)
- **No primary key** — rows are not deduplicated
- **Distinct-user column for Pulse replication:** `user_id`. Use `STABLE_ID` only when `user_id` is NULL and Statsig stable_id behavior is the desired identity

## Typical usage patterns

- **First-exposure-per-(user_id, experiment_id) — the canonical cohort:**
  ```sql
  ROW_NUMBER() OVER (PARTITION BY user_id, experiment_id ORDER BY timestamp ASC) = 1
  ```
  See `knowledge/query-patterns/statsig_exposure_cohort.sql`.
- **Date scoping:** default 30–90 day windows. Rows/day ≈ 40K (1.2M rows over ~30 days). Very cheap (P50 <1s, bytes <100 MB)
- **Common filters:** `experiment_id = '<slug>'`, `timestamp >= :start`, `user_id IS NOT NULL`

## Known pitfalls

- **1:1 mapping exclusion from Pulse (OPEN)** — Statsig Pulse enforces 1:1 (user_id ↔ stable_id). Post-consolidation stable_id sprawl means a single `user_id` can be associated with multiple `stable_id`s; Pulse drops ~13.5% of exposed `user_ids` from `wcpm_pricing_test` as a result. See `project_wcpm_1to1_mapping_exclusion.md`.
- **Statsig late-arrival drop in downstream ETL (OPEN)** — `statsig_clickstream_events_etl_output` incremental predicate drops `fct_events` rows with `event_ts` older than its watermark. This affects the CLICKSTREAM table, not this EXPOSURES table directly. If replicating Pulse, use `_external_statsig.exposures` for first-exposure and `fct_events` (bridged) for downstream metrics — NOT `statsig_clickstream_events_etl_output`. See `project_statsig_model_late_arrival_open.md`.
- **`user_id IS NULL` exposures** — pre-identify exposures land with NULL user_id. Filter them out explicitly if the analysis is user-grain. Do not silently collapse them into `stable_id`-level analysis without stating the choice
- **Re-exposure inflation** — a user can be exposed multiple times in a single experiment; always deduplicate by first-exposure (or by the question's chosen exposure rule) before counting

## Cost profile

- **Date-scoped filters (30 days):** elapsed <1s, bytes <50 MB — essentially free
- **Full table scans:** also cheap (1.2M rows × ~90 bytes = ~100 MB)
- **`USER_DIMENSIONS` flattening:** can be expensive if the VARIANT is large; check sample first

## Prior analyses referencing this table

- `analysis/experimentation/2026-04-18-wcpm-test-audit/` — source of the 1:1 mapping exclusion finding
- `knowledge/domains/experimentation/identifier-mapping-and-exclusions.md` — canonical documentation of the identity logic
- `knowledge/query-patterns/statsig_exposure_cohort.sql` — the canonical cohort pull

## LookML semantics

No primary LookML view on this raw table — analytics typically go through `marketing.stg_exposures` or the Statsig-reported Pulse dashboards. For first-exposure cohort pulls, use `knowledge/query-patterns/statsig_exposure_cohort.sql` directly.
