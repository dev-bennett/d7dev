# In-App Notifications Build-Out

- **Status:** sources + staging promoted; intermediate/marts pending
- **Date:** 2026-04-02
- **PR:** merged to main (dbt repo)
- **Models touched:** stg_user_notifications, stg_cms_content_types, stg_cms_entries, stg_cms_field_values, stg_cms_fields, stg_cms_assets, int_notification_content_pivoted, dim_notification_content, fct_notification_deliveries
- **Source:** Lifecycle marketing initiative -- phase 1 reporting pipeline

## Context

Building the foundational dbt staging layer for in-app notifications. Six source tables in `pc_stitch_db.soundstripe` need staging models before intermediate/mart layers can be built. This is the first step toward a comprehensive lifecycle marketing reporting system that will eventually unify in-app, email (HubSpot), and future channels.

## Data Model

```
cms_content_types (3 notification types: generic=10, targeted=11, automated=12)
    ├── cms_fields (field schema per type)
    └── cms_entries (individual content items)
            ├── cms_field_values (EAV: entry_id + field_id → value)
            └── user_notifications (delivery: cms_entry_id + user_id)
cms_assets (media/CSV targeting lists)
```

## Files

- `visitors.sql` -- Discovery queries (q1-q7) for all source tables
- `q1.csv` - `q7.csv` -- Sample results from discovery queries
- `stg_user_notifications.sql` -- Staging: notification delivery records
- `stg_cms_content_types.sql` -- Staging: content type definitions
- `stg_cms_entries.sql` -- Staging: content entries
- `stg_cms_field_values.sql` -- Staging: EAV field values
- `stg_cms_fields.sql` -- Staging: field schema definitions
- `stg_cms_assets.sql` -- Staging: media and targeting assets
- `src_soundstripe_additions.yml` -- Source definitions (promoted)
- `int_notification_content_pivoted.sql` -- Pivot CMS EAV to one row per notification
- `dim_notification_content.sql` -- Notification content dimension
- `fct_notification_deliveries.sql` -- Delivery fact (incremental, user x notification grain)
- `schema.yml` -- Schema tests for intermediate/dimension/fact
- `commit-message.md` -- Commit message for sources + staging PR (promoted)
- `pr-description.md` -- PR description for sources + staging PR (promoted)
- `commit-message-transforms.md` -- Commit message for transforms PR
- `pr-description-transforms.md` -- PR description for transforms PR
