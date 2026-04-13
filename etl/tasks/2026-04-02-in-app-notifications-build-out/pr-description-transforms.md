## Summary

- Add `int_notification_content_pivoted` to `transformations/marketing/` -- pivots CMS EAV (field_values + fields) into one row per notification entry with title, message, url, tag as columns
- Add `dim_notification_content` to `marts/marketing/` -- notification content dimension with type classification and publication metadata
- Add `fct_notification_deliveries` to `marts/marketing/` -- incremental fact table at user x notification grain with read status, time-to-read, and enriched content from the dimension
- Add tests to `marts/marketing/schema.yml`: unique/not_null on PKs, accepted_values on notification_type, relationships test on cms_entry_id

## File Placement

```
models/
  transformations/marketing/
    int_notification_content_pivoted.sql
  marts/marketing/
    dim_notification_content.sql
    fct_notification_deliveries.sql
    schema.yml  (append to existing)
```

## Design Decisions

- **LEFT JOIN from deliveries to content dimension:** Some `user_notifications.cms_entry_id` values may reference non-notification content types. LEFT JOIN preserves all delivery records; `notification_type` will be NULL for non-notification entries, making them easy to filter or investigate.
- **3-day incremental lookback:** Accounts for late-arriving data and Stitch replication lag. Matches pattern used in HubSpot email events pipeline.
- **Pivot via conditional aggregation:** The CMS field_values table is EAV (entity-attribute-value). The intermediate model pivots using `MAX(CASE WHEN field_identifier = '...' THEN string_value END)` grouped by entry, which is the standard Snowflake-efficient approach for known field sets.
- **Separate dim vs fact:** Notification content changes rarely; delivery volume grows continuously. Separating them allows the dim to be a full-refresh table while the fact is incremental.

## DAG

```
stg_cms_entries ──┐
stg_cms_content_types ──┤── int_notification_content_pivoted ── dim_notification_content ──┐
stg_cms_field_values ──┤                                                                    ├── fct_notification_deliveries
stg_cms_fields ────────┘                                                                    │
stg_user_notifications ─────────────────────────────────────────────────────────────────────┘
```

## Test Plan

- [ ] `dbt run --select +fct_notification_deliveries` completes without errors
- [ ] `dbt test --select +fct_notification_deliveries` -- all schema tests pass
- [ ] Spot-check: pick a known `cms_entry_id` from sample data, verify its title/message in `dim_notification_content` matches raw field_values
- [ ] Verify `fct_notification_deliveries` row count approximates `SELECT COUNT(*) FROM pc_stitch_db.soundstripe.user_notifications`
- [ ] Verify `notification_type` is populated for the majority of rows (some NULLs expected for non-notification content types)
- [ ] Sanity: `is_read` rate between 0-100%, `hours_to_read` distribution looks reasonable (not all 0 or all NULL)
