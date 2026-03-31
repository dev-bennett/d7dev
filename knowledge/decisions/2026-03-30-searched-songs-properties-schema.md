# Searched Songs Properties: Schema Decisions

- **Last updated:** 2026-03-30
- **Author:** d7admin
- **Status:** accepted
- **Source:** etl/tasks/2026-03-30-searched-songs-properties/

## Context

Engineering shipped three new properties on the Mixpanel "Searched Songs" event (Has Vocals, Result Count, Supe). Schema check against `pc_stitch_db.mixpanel.export` revealed data type and format considerations requiring decisions before adding columns to fct_events.

## Decision 1: Filter HAS_VOCALS to enum values only

- **Decision:** Use a CASE expression to only keep values matching the new enum set (All, Vocals, Instrumental). Map old boolean True/False values to NULL.
- **Rationale:** HAS_VOCALS carried boolean True/False values before 2026-03-25 (~1.6M rows). These represent a different semantic ("has vocals filter applied?") than the new enum ("which vocal filter?"). Mixing formats would confuse analysts and break downstream filters/grouping.
- **Consequences:** Pre-2026-03-25 Searched Songs events will have NULL for search_has_vocals. The old boolean semantics are not preserved in fct_events -- if needed, query the source table directly.
- **Status:** Accepted.

## Decision 2: Cast SUPE from TEXT to BOOLEAN

- **Decision:** Use `TRY_CAST(SUPE AS BOOLEAN)` to convert the source TEXT column ("True"/"False") to native BOOLEAN.
- **Rationale:** Stitch stores all Mixpanel properties as TEXT. The Supe property is semantically boolean. TRY_CAST handles edge cases (unexpected values become NULL).
- **Consequences:** Downstream queries can use standard boolean comparisons (`WHERE is_supe_search = TRUE`) rather than string matching.
- **Status:** Accepted.

## Decision 3: Cast RESULT_COUNT from TEXT to INTEGER

- **Decision:** Use `TRY_CAST(RESULT_COUNT AS INTEGER)` to convert the source TEXT column to native INTEGER.
- **Rationale:** Same as SUPE -- Stitch stores as TEXT, but the property is semantically numeric. Sample data confirms integer values (range: 0 to 30,000+).
- **Consequences:** Downstream queries can use numeric aggregations (AVG, MIN, MAX) directly.
- **Status:** Accepted.

## Schema Check Results Summary

- All 3 columns present in Stitch export (HAS_VOCALS, RESULT_COUNT, SUPE) -- all TEXT type
- ~90% population rate for RESULT_COUNT and SUPE on Searched Songs events since 2026-03-26
- Data flowing since 2026-03-25 (one day before stated go-live)
- Full results: etl/tasks/2026-03-30-searched-songs-properties/schema_check/
