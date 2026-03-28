# Reference Track Search: Schema Decisions

- **Last updated:** 2026-03-28
- **Author:** d7admin
- **Status:** accepted
- **Source:** etl/tasks/2026-03-27-reference-track-search/

## Context

Engineering shipped a Spotify-based Reference Track Search feature generating six new Mixpanel events (live since 2026-02-18). The Stitch export integration was updated to include new event properties. Several properties required schema decisions before adding columns to fct_events.

## Decision 1: Exclude `results` array

- **Decision:** Do not add the `results` column (array of Song ID + Score objects) to fct_events.
- **Rationale:** The column is not present in the Stitch export as of 2026-03-27. May require a Stitch integration update or custom connector configuration to surface.
- **Consequences:** Reference track search result detail (which songs matched, similarity scores) is not available for analysis. Requires separate investigation into Stitch configuration.
- **Status:** Accepted. Revisit when Stitch export is updated.

## Decision 2: Exclude `content_partners`

- **Decision:** Do not add the `content_partners` column to fct_events.
- **Rationale:** The column exists in Snowflake (confirmed via schema check, data type TEXT) but is completely unpopulated as of 2026-03-27. Adding an always-NULL column provides no analytical value.
- **Consequences:** If content_partners begins populating in the future, a follow-up ETL task is needed to add it.
- **Status:** Accepted. Monitor for data population.

## Decision 3: Quote `TRIGGER` as reserved word

- **Decision:** Reference the source column as `"TRIGGER"` (quoted identifier) and alias it to `ref_track_signup_trigger` in fct_events.
- **Rationale:** `TRIGGER` is a Snowflake reserved word. Unquoted use causes SQL compilation errors. The alias disambiguates from multiple unrelated `*_TRIGGER` columns (DOWNGRADE_TRIGGER, REACTIVATION_TRIGGER, SUBSCRIBE_TRIGGER, SIGN_UP_TRIGGER, UPGRADE_TRIGGER, UPSELL_TRIGGER).
- **Consequences:** All downstream SQL referencing this field must use the aliased name `ref_track_signup_trigger`, not the source name.
- **Status:** Accepted.

## Decision 4: Exclude `input_value`

- **Decision:** Do not add `input_value` to fct_events.
- **Rationale:** Not present in the Stitch export. Appears to be a frontend-only property that does not propagate to Mixpanel's server-side export.
- **Consequences:** The raw user input (what text/URL the user pasted) is not available for analysis via fct_events. Would need frontend logging or Mixpanel raw export access.
- **Status:** Accepted.
