# In-App Notifications Performance Dashboard

- **Status:** promoted (implemented in Looker IDE, pending PR merge)
- **Date:** 2026-04-02
- **PR:** --
- **Explore:** notification_deliveries (General.model.lkml)
- **Views:** fct_notification_deliveries, dim_notification_content
- **Dashboard:** in_app_notification_performance
- **Source:** Lifecycle marketing initiative -- phase 1 reporting

## Context

LookML dashboard providing marketing with in-app notification delivery tracking and read rate performance insights. Covers automated, targeted, and generic notification types. Built on top of the dbt notification reporting pipeline (fct_notification_deliveries + dim_notification_content in soundstripe_prod.marketing).

## QA Status

- Dashboard screenshot captured and validated against baseline benchmarks
- All 9 tiles populated, numbers consistent with post-fix exploration queries
- See `In-App_Notification_Performance_2026-04-02T1356.pdf`
