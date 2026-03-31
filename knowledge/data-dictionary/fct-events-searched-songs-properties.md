# fct_events: Searched Songs Properties

- **Last updated:** 2026-03-30
- **Author:** d7admin
- **Source:** etl/tasks/2026-03-30-searched-songs-properties/

## Fields

### search_has_vocals

- **Definition:** Vocal filter selection applied during a song search. Indicates whether the user filtered by vocal type.
- **Calculation SQL:** `CASE WHEN HAS_VOCALS IN ('All', 'Vocals', 'Instrumental') THEN HAS_VOCALS ELSE NULL END AS search_has_vocals`
- **Source table:** `pc_stitch_db.mixpanel.export` via `core.fct_events`
- **Owner:** Data Engineering
- **Events:** Searched Songs
- **Data type:** TEXT, nullable
- **Known values:** "All", "Vocals", "Instrumental"
- **Notes:** The source column `HAS_VOCALS` carried boolean True/False values before 2026-03-25 (1.6M rows) and enum values after (All/Vocals/Instrumental). A CASE expression filters to only the enum values, NULLing out the old booleans. Prefixed with `search_` to disambiguate from content-level `has_vocals` in dim_songs. See decision record: knowledge/decisions/2026-03-30-searched-songs-properties-schema.md.

### search_result_count

- **Definition:** Number of search results returned for a Searched Songs event.
- **Calculation SQL:** `TRY_CAST(RESULT_COUNT AS INTEGER) AS search_result_count`
- **Source table:** `pc_stitch_db.mixpanel.export` via `core.fct_events`
- **Owner:** Data Engineering
- **Events:** Searched Songs
- **Data type:** INTEGER (via TRY_CAST), nullable
- **Notes:** Source column `RESULT_COUNT` is TEXT in Snowflake. TRY_CAST handles non-numeric values gracefully. Prefixed with `search_` to distinguish from `ref_track_results_count`.

### is_supe_search

- **Definition:** Whether the search was triggered from the Supe AI chat sidebar. Supe is a conversational AI feature that can fire search requests while chatting with the user.
- **Calculation SQL:** `TRY_CAST(SUPE AS BOOLEAN) AS is_supe_search`
- **Source table:** `pc_stitch_db.mixpanel.export` via `core.fct_events`
- **Owner:** Data Engineering
- **Events:** Searched Songs
- **Data type:** BOOLEAN, nullable
- **Notes:** This is a search origin flag, not a user subscription attribute. TRUE means the search was initiated by the Supe chat sidebar; FALSE or NULL means a standard UI search.
