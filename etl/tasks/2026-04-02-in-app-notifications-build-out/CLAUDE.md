# In-App Notifications Build-Out

@../CLAUDE.md

ETL task for building the dbt reporting pipeline for in-app notifications (phase 1 of lifecycle marketing system).

## Source Tables

All in `pc_stitch_db.soundstripe`:
- `user_notifications` -- delivery records (user + notification + read status)
- `cms_content_types` -- 17 content types (3 notification: generic, targeted, automated)
- `cms_entries` -- individual content items linked to content_types
- `cms_field_values` -- EAV field values (entry_id + field_id → value)
- `cms_fields` -- field schema definitions per content type
- `cms_assets` -- media files and CSV targeting lists

## Conventions

- Transform drafts named to match dbt target model (e.g., `stg_user_notifications.sql`)
- Discovery queries and results in `visitors.sql` + `q1-q7.csv`
