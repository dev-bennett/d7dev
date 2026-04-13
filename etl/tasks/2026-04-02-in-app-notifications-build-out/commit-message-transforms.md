Add notification reporting pipeline (intermediate, dimension, fact)

Build the transformation layer for in-app notification reporting:
- int_notification_content_pivoted: pivots CMS EAV into one row per
  notification with title/message/url/tag columns
- dim_notification_content: clean content dimension with type metadata
- fct_notification_deliveries: incremental delivery fact at
  user x notification grain with read status and time-to-read

These models depend on the staging layer added in the prior commit
and produce a standalone reporting dataset for notification performance.
