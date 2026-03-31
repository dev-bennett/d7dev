# Add Searched Songs Properties to fct_events

- **Status:** in-progress
- **Date:** 2026-03-30
- **PR:** pending
- **Models touched:** `fct_events` (marts/core), `dim_mixpanel_feature_events` (marts/core)
- **Source:** Engineering PR added Has Vocals, Result Count, and Supe properties to the Mixpanel "Searched Songs" event for Music team search insights

## Context

Devon is working with the Music team to enable understanding of customer search behavior and search results. Engineering shipped three new/updated properties on the "Searched Songs" Mixpanel event:

| Property | Stitch Column | Type | Description |
|----------|--------------|------|-------------|
| Has Vocals | `HAS_VOCALS` | string | Vocal filter selection: "All" / "Vocals" / "Instrumental" |
| Result Count | `RESULT_COUNT` | integer | Number of search results returned |
| Supe | `SUPE` | boolean | Search triggered from Supe AI chat sidebar |

**Backfill from:** 2026-03-25 (one day before go-live of 2026-03-26)

### Schema check results (2026-03-30)

All 3 columns confirmed in `pc_stitch_db.mixpanel.export` (all TEXT type):
- `HAS_VOCALS`: Pre-3/25 values are boolean True/False (~1.6M rows); post-3/25 are enum All/Vocals/Instrumental (~236K rows). CASE expression NULLs out old booleans.
- `RESULT_COUNT` and `SUPE`: Net-new, populating at ~90% rate since 2026-03-26.
- SUPE source is TEXT ("True"/"False"), cast to BOOLEAN via TRY_CAST.
- Schema decisions: knowledge/decisions/2026-03-30-searched-songs-properties-schema.md

### fct_events columns

| Source Column | fct_events Alias | Type | Transform |
|--------------|-----------------|------|-----------|
| `HAS_VOCALS` | `search_has_vocals` | VARCHAR | CASE: only keep All/Vocals/Instrumental; NULL out old True/False |
| `RESULT_COUNT` | `search_result_count` | INTEGER | TRY_CAST from TEXT |
| `SUPE` | `is_supe_search` | BOOLEAN | TRY_CAST from TEXT |

### Downstream impact (future scope)

| Model | Future change needed |
|-------|---------------------|
| fct_sessions_build | Add search filter/result metrics per session |
| dim_mixpanel_feature_events | Surface Result Count and Supe alongside existing filter_json |
| LookML | New dimensions for search filter reporting |

## Files

- `schema_check/schema_check.sql` -- Stitch verification queries (columns exist, sample data, population rates)
- `fct_events.sql` -- Draft fct_events with 3 new columns
- `validation/validation.sql` -- Post-deploy validation queries
- `backfill_runbook.md` -- Backfill execution steps
