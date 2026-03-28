# fct_events: Reference Track Search Columns

- **Last updated:** 2026-03-28
- **Author:** d7admin
- **Source:** etl/tasks/2026-03-27-reference-track-search/

## Fields

### spotify_track_id

- **Definition:** Spotify's unique identifier for the reference track used in a search. 22-character alphanumeric string assigned by Spotify.
- **Calculation SQL:** `spotify_track_id` (direct select from source)
- **Source table:** `pc_stitch_db.mixpanel.export` via `core.fct_events`
- **Owner:** Data Engineering
- **Events:** Executed Reference Track Search, Reference Track Search Error
- **Data type:** TEXT, nullable
- **Notes:** Present when a user submits a Spotify track for reference-based search. NULL for non-RTS events.

### spotify_id

- **Definition:** Spotify identifier present on frontend-initiated reference track search events. Distinct from spotify_track_id -- appears on modal and agent search events rather than backend execution events.
- **Calculation SQL:** `spotify_id` (direct select from source)
- **Source table:** `pc_stitch_db.mixpanel.export` via `core.fct_events`
- **Owner:** Data Engineering
- **Events:** Reference Track Search Sign Up Modal Opened, Reference Track Search Closed, Executed Agent Search
- **Data type:** TEXT, nullable

### ref_track_results_count

- **Definition:** Number of matching tracks returned by a reference track search execution. Cast to integer from source text.
- **Calculation SQL:** `TRY_CAST(results_count AS INTEGER) AS ref_track_results_count`
- **Source table:** `pc_stitch_db.mixpanel.export` via `core.fct_events`
- **Owner:** Data Engineering
- **Events:** Executed Reference Track Search
- **Data type:** INTEGER (via TRY_CAST), nullable
- **Notes:** Source column `results_count` is TEXT in Snowflake. TRY_CAST handles non-numeric values gracefully.

### ref_track_title

- **Definition:** Display title of the reference track, typically in "Artist - Title" format.
- **Calculation SQL:** `track_title_display AS ref_track_title`
- **Source table:** `pc_stitch_db.mixpanel.export` via `core.fct_events`
- **Owner:** Data Engineering
- **Events:** Executed Reference Track Search, Reference Track Search Error
- **Data type:** TEXT, nullable

### ref_track_error_message

- **Definition:** Error message when a reference track search fails. Known values: "No Spotify match", "Track not analyzed".
- **Calculation SQL:** `error_message AS ref_track_error_message`
- **Source table:** `pc_stitch_db.mixpanel.export` via `core.fct_events`
- **Owner:** Data Engineering
- **Events:** Reference Track Search Error
- **Data type:** TEXT, nullable

### ref_track_signup_trigger

- **Definition:** What triggered the sign-up modal during reference track search. Known values: "URL Param", "Form Submit".
- **Calculation SQL:** `"TRIGGER" AS ref_track_signup_trigger`
- **Source table:** `pc_stitch_db.mixpanel.export` via `core.fct_events`
- **Owner:** Data Engineering
- **Events:** Reference Track Search Sign Up Modal Opened
- **Data type:** TEXT, nullable
- **Notes:** Source column is `TRIGGER`, a Snowflake reserved word requiring quoting. Alias disambiguates from unrelated `*_TRIGGER` columns (DOWNGRADE_TRIGGER, REACTIVATION_TRIGGER, SUBSCRIBE_TRIGGER, SIGN_UP_TRIGGER, UPGRADE_TRIGGER, UPSELL_TRIGGER).

### search_type

- **Definition:** Type of search executed in the Agent Search event. Value "reference_track" indicates the search was initiated via the reference track feature.
- **Calculation SQL:** `search_type` (direct select from source)
- **Source table:** `pc_stitch_db.mixpanel.export` via `core.fct_events`
- **Owner:** Data Engineering
- **Events:** Executed Agent Search
- **Data type:** TEXT, nullable
- **Notes:** New optional property on a pre-existing event. Only populated when search_type is non-null.
