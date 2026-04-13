# Lifecycle Marketing: In-App Notifications

- **Status:** active
- **Started:** 2026-04-02
- **Owner:** d7admin
- **Phase:** Phase 1 complete (reporting pipeline + dashboard). Phase 2 pending (Mixpanel click enrichment).

## Objective

Build reporting infrastructure for in-app notifications as the first channel in a comprehensive lifecycle marketing system. Enables marketing to track notification delivery volume, read rates, and content performance.

## Artifacts

### ETL
- `etl/tasks/2026-04-02-in-app-notifications-build-out/` -- dbt staging, transforms, marts. Sources + staging merged to dbt repo. Transforms manually deployed to soundstripe_prod.marketing.
  - Discovery queries: `visitors.sql` + `q1-q7.csv`
  - Exploration: `exploration/` (initial, baseline, diagnostic, post-fix baseline subdirectories)
  - Transform drafts: `stg_*.sql`, `int_*.sql`, `dim_*.sql`, `fct_*.sql`, `schema.yml`

### LookML
- `lookml/tasks/2026-04-02-in-app-notifications-dashboard/` -- Views, explore, dashboard. Promoted via Looker IDE.
  - `lkml/views/fct_notification_deliveries.view.lkml`
  - `lkml/views/dim_notification_content.view.lkml`
  - `lkml/explores/notification_deliveries.explore.lkml`
  - `lkml/dashboards/in_app_notification_performance.dashboard.lookml`
  - QA screenshot: `In-App_Notification_Performance_2026-04-02T1356.pdf`

### Knowledge
- `knowledge/domains/tracking/overview.md` -- Tracking architecture (API endpoint, identity props, data flow)
- `knowledge/domains/tracking/event-taxonomy.md` -- Observed event catalog from browser capture
- `knowledge/domains/tracking/lookml-parking-lot.md` -- 14 LookML repo improvement items
- `knowledge/decisions/2026-04-02-user-notifications-stitch-replication-key.md` -- Stitch fix from `id` to `updated_at`
- `knowledge/runbooks/event-capture-workflow.md` -- Reusable browser event interception process

### Analysis
- `analysis/data-health/event-captures/2026-04-02-initial-capture.json` -- Raw browser event capture
- `analysis/data-health/2026-04-02-session-retrospective.md` -- Session retrospective

## Changelog

- 2026-04-02: Built full pipeline end-to-end. Discovered and fixed Stitch replication key issue. Established corrected baselines. Built and validated LookML dashboard. Connected LookML repo as submodule. Restructured lookml/ workspace.
