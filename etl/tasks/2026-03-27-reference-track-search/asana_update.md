**Update -- 2026-03-28**

**Summary**

fct_events transform is complete and deployed. Added 7 new columns to surface Reference Track Search event properties landing in Snowflake via Stitch. Schema verified against production, backfill executed, validation passed.

**New columns added to fct_events**

- spotify_track_id -- Spotify track identifier (backend search events)
- spotify_id -- Spotify identifier (frontend modal and agent search events)
- ref_track_results_count -- number of matching tracks returned
- ref_track_title -- display title of the reference track
- ref_track_error_message -- error detail when search fails
- ref_track_signup_trigger -- what triggered the sign-up modal
- search_type -- distinguishes reference track searches in Executed Agent Search

**Schema decisions**

- results (Song ID + Score array): excluded, not present in Stitch export. Needs Stitch integration investigation.
- content_partners: excluded, column exists in Snowflake but completely unpopulated as of 2026-03-27.
- TRIGGER: Snowflake reserved word, aliased to ref_track_signup_trigger.
- input_value: excluded, not in Stitch export (frontend-only property).

**Artifacts**

- fct_events.sql -- transform with 7 new columns and reusable backfill_from var
- schema_check/ -- Snowflake verification queries and exported CSV results
- validation/ -- post-deploy validation queries and exported results
- backfill_runbook.md -- step-by-step backfill execution plan

**Future scope**

- fct_sessions_build: add ref_track_search_count session metric
- fct_sessions_product_engagement_build: add ref_track_searches, ref_track_errors metrics
- dim_mixpanel_feature_events: add Executed Reference Track Search to WHERE clause
- LookML: new dimensions/explores for reference track reporting
