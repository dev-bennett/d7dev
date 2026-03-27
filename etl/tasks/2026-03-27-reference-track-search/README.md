# Add Reference Track Search Events to fct_events

- **Status:** in-progress
- **Date:** 2026-03-27
- **PR:** pending
- **Models touched:** `fct_events` (marts/core)
- **Source:** Engineering shipped Spotify-based Reference Track Search feature; new Mixpanel events need to surface in fct_events for downstream analysis

## Context

Six new Mixpanel events fire for the Reference Track Search feature. The Stitch export integration has been updated to include new event properties (Spotify Track ID, Results Count, Content Partners, Results array, etc.). The events already flow through fct_events but their specific properties are not yet selected as columns.

This task adds the new property columns to `fct_events` and provides a backfill strategy to populate them for events that landed before the model change.

### New events (live since 2026-02-18)

| Event | Source | Key Properties |
|-------|--------|---------------|
| Executed Reference Track Search | Backend | spotify_track_id, results_count, track_title_display |
| Reference Track Search Sign Up Modal Opened | Frontend | spotify_id, trigger |
| Reference Track Search Error | Frontend + Backend | spotify_id, error_message, track_title_display |
| Reference Track Search Closed | Frontend | spotify_id |
| Executed Agent Search (existing, new props) | Frontend | search_type, spotify_id |

### Schema decisions (2026-03-27)

- **RESULTS (array of Song ID + Score):** NOT in Stitch export. Needs investigation -- may require Stitch integration update or custom connector config.
- **CONTENT_PARTNERS:** Column exists in Snowflake but is unpopulated as of 2026-03-27. Excluded until data flows.
- **INPUT_VALUE:** Not present in Stitch export. Frontend-only property that may not propagate to Mixpanel's server-side export.
- **TRIGGER:** Exists as unquoted column. Must be quoted (`"TRIGGER"`) in SQL -- Snowflake reserved word. Multiple other `*_TRIGGER` columns exist for unrelated features.

### Downstream impact (future scope)

| Model | Future change needed |
|-------|---------------------|
| fct_sessions_build | Add ref_track_search_count session metric |
| fct_sessions_product_engagement_build | Add ref_track_searches, ref_track_errors metrics |
| dim_mixpanel_feature_events | Add Executed Reference Track Search to WHERE clause |
| LookML | New dimensions/explores for reference track reporting |

## Files

- `fct_events.sql` -- Draft modified fct_events with 7 new columns + backfill var
- `schema_check/` -- Snowflake verification queries + exported CSV results
- `validation.sql` -- Post-deploy queries to confirm columns are populated correctly
- `backfill_runbook.md` -- Step-by-step backfill execution plan
