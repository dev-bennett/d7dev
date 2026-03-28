# Search Domain Overview

- **Last updated:** 2026-03-28
- **Author:** d7admin

## Scope

The search domain covers user search behavior within the Soundstripe platform, including:
- **Reference Track Search:** Spotify-based similarity search (shipped 2026-02-18)
- **Agent Search:** General search with optional reference track mode

## Key Events

| Event | Source | First Seen | Description |
|-------|--------|------------|-------------|
| Executed Reference Track Search | Backend | 2026-02-18 | User submitted a Spotify track for reference-based search |
| Reference Track Search Sign Up Modal Opened | Frontend | 2026-02-18 | Non-subscriber encountered sign-up gate during RTS |
| Reference Track Search Error | Frontend + Backend | 2026-02-18 | Search failed (no Spotify match, track not analyzed, etc.) |
| Reference Track Search Closed | Frontend | 2026-02-18 | User closed the reference track search interface |
| Executed Agent Search | Frontend | Pre-existing | General search; now includes `search_type` and `spotify_id` when reference track mode |

## Data Model

- **Primary table:** `core.fct_events` (7 new columns added 2026-03-27)
- **Columns:** spotify_track_id, spotify_id, ref_track_results_count, ref_track_title, ref_track_error_message, ref_track_signup_trigger, search_type
- **Data dictionary:** knowledge/data-dictionary/fct-events-reference-track-search.md
- **Schema decisions:** knowledge/decisions/2026-03-28-reference-track-search-schema.md

## Downstream Models (Future Scope)

| Model | Needed Change |
|-------|---------------|
| fct_sessions_build | Add ref_track_search_count session metric |
| fct_sessions_product_engagement_build | Add ref_track_searches, ref_track_errors metrics |
| dim_mixpanel_feature_events | Add Executed Reference Track Search to WHERE clause |
| LookML | New dimensions/explores for reference track reporting |

## Open Questions

- `results` array (Song ID + Score) not in Stitch export -- needs investigation
- `content_partners` column unpopulated -- monitor for data flow
- `input_value` not in server-side export -- frontend-only?

## Related Work

- ETL task: etl/tasks/2026-03-27-reference-track-search/
- Analysis workspace: analysis/search/
