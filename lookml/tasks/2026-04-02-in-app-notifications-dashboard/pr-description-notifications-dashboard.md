## Summary

- Add `fct_notification_deliveries` view to `views/General/` -- fact view with delivery, read status, time-to-read bucketing, and 7 measures (total deliveries, read/unread counts, read rate, distinct users, distinct notifications, avg hours to read)
- Add `dim_notification_content` view to `views/General/` -- dimension view for notification content metadata (type, title, message, url, tag, publication status)
- Add `notification_deliveries` explore to `General.model.lkml` -- joins fact to dim with `group_label: "Marketing"` and 90-day default filter
- Add `in_app_notification_performance` LookML dashboard to `dashboards/` -- 9 tiles: 4 scorecards, 2 time-series, 2 breakdowns, 1 content performance table

## Underlying Data

- Fact table: `SOUNDSTRIPE_PROD.MARKETING.FCT_NOTIFICATION_DELIVERIES` (incremental, ~3.2M rows)
- Dimension table: `SOUNDSTRIPE_PROD.MARKETING.DIM_NOTIFICATION_CONTENT` (~1.8M entries)
- dbt models promoted in prior PRs to SoundstripeEngineering/dbt-transformations

## Dashboard Layout

```
Row 1: [Total Deliveries] [Read Rate] [Distinct Users] [Avg Hours to Read]
Row 2: [Monthly Delivery Volume by Type (area)] [Monthly Read Rate by Type (line)]
Row 3: [Read Rate by Tag (bar)]                 [Time to Read Distribution (column)]
Row 4: [Top Notifications Table (grid) -- title, type, tag, deliveries, reads, rate, avg hours]
```

Filters: Date Range (default 90 days), Notification Type, Tag

## Test Plan

- [ ] LookML validation passes with no errors
- [ ] Explore `notification_deliveries` returns data when queried
- [ ] Dashboard loads with all 9 tiles populated
- [ ] Scorecard values are non-zero and consistent with baseline benchmarks
- [ ] Notification type filter correctly segments automated/targeted/generic
- [ ] Tag filter shows: New Music, Reminder, Announcement, Update
- [ ] Date range filter updates all tiles
- [ ] Content performance table shows top notifications sorted by delivery volume
