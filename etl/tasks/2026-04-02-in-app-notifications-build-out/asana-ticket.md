# Asana Ticket: In-App Notifications Reporting Pipeline

## Ticket Title

Build In-App Notification Reporting Pipeline (Lifecycle Marketing Phase 1)

## Ticket Description

Build the end-to-end reporting infrastructure for in-app notifications to give Marketing visibility into notification delivery volume, read rates, and content performance. This is the first channel in the lifecycle marketing reporting system (in-app); email (HubSpot) models exist but are not yet unified.

**Scope:**
- Register 6 new source tables in dbt (user_notifications, cms_content_types, cms_entries, cms_field_values, cms_fields, cms_assets)
- Build dbt staging, intermediate, dimension, and fact models
- Build LookML explore and dashboard for Marketing self-service
- Investigate and resolve any data quality issues discovered during development

**Source tables:** All in pc_stitch_db.soundstripe, loaded via Stitch
**Target schema:** soundstripe_prod.marketing
**Stakeholder:** Marketing (lifecycle program)
**Upstream dependency:** None (greenfield)

---

## Update 1: Discovery & Source Registration

**Date:** 2026-04-02 (AM)

Completed initial discovery of the notification data model. The CMS uses an entity-attribute-value (EAV) structure across 5 tables, with user_notifications tracking delivery and read status per user.

**Completed:**
- Ran discovery queries (q1-q7) against all 6 source tables, exported sample data
- Mapped the CMS data model: cms_content_types -> cms_entries -> cms_field_values, with cms_fields defining the schema per type
- Identified 3 notification content types: genericNotification (ID 10), targetedNotification (ID 11), automatedNotification (ID 12)
- Added 6 source tables to src_soundstripe.yml in alphabetical order
- Built and promoted 6 staging models (stg_user_notifications, stg_cms_content_types, stg_cms_entries, stg_cms_field_values, stg_cms_fields, stg_cms_assets)

**PR:** Merged to main (dbt repo) -- sources + staging

---

## Update 2: Transform & Mart Models

**Date:** 2026-04-02 (AM)

Built the transformation and reporting layers.

**Completed:**
- int_notification_content_pivoted: pivots CMS EAV into one row per notification entry (title, message, url, tag as columns)
- dim_notification_content: clean content dimension with type metadata (table materialization)
- fct_notification_deliveries: incremental fact at user x notification grain with read status and hours_to_read
- schema.yml with tests for all 3 models (appended to existing marts/marketing/schema.yml)
- Models placed in transformations/marketing/ (intermediate) and marts/marketing/ (dim + fact)

**PR:** Merged to main (dbt repo) -- transforms + marts

---

## Update 3: Stitch Replication Key Fix

**Date:** 2026-04-02 (midday)

During baseline exploration, discovered that read rates for automated and targeted notifications collapsed to near-zero starting November 2025. Diagnosed root cause: Stitch replication key was set to `id` (captures inserts only), so read_at updates were never replicated to Snowflake.

**Investigation:**
- Weekly read rate analysis pinpointed the drop to the week of November 3, 2025
- Generic notifications (control group) unaffected at ~98% read rate throughout -- ruled out platform-wide tracking failure
- Raw source tables confirmed the same pattern -- not a dbt transform bug
- Sample of rare post-Nov reads confirmed the app IS writing read_at correctly -- Stitch just wasn't picking it up

**Resolution:**
- Changed Stitch replication key for user_notifications from `id` to `updated_at`
- Triggered historical re-sync to backfill missed read_at values
- Verified backfill in source tables: automated read rate recovered from 0.01% to 7.46% for Nov 2025+ period
- Manually rebuilt fct_notification_deliveries in soundstripe_prod.marketing (dbt Cloud dev targets soundstripe_dev, not prod)
- Granted SELECT to EMBEDDED_ANALYST role on rebuilt table

**Decision record:** knowledge/decisions/2026-04-02-user-notifications-stitch-replication-key.md

**Corrected baseline metrics (all-time):**
- Automated read rate: 16.3% (was 9.2% pre-fix)
- Targeted read rate: 6.3% (was 4.5% pre-fix)
- Generic read rate: 98.9% (unchanged)

---

## Update 4: LookML Dashboard Build & Promotion

**Date:** 2026-04-02 (PM)

Built and promoted the LookML dashboard for Marketing.

**Completed:**
- fct_notification_deliveries.view.lkml: 8 dimensions, 3 dimension groups, 7 measures (total deliveries, read/unread counts, read rate, distinct users, distinct notifications, avg hours to read), time-to-read bucketing with sort order
- dim_notification_content.view.lkml: content dimension with type, title, message, url, tag, publication status
- notification_deliveries explore added to General.model.lkml with group_label "Marketing" and 90-day default filter
- in_app_notification_performance.dashboard.lookml: 9-tile dashboard (4 scorecards, 2 time-series, 2 breakdowns, 1 content performance table)
- Implemented in Looker IDE, validated all tiles against baseline benchmarks
- Dashboard QA passed -- all tiles populated, numbers consistent with corrected baselines

**Dashboard tiles:**
1. Total Deliveries (scorecard)
2. Read Rate (scorecard)
3. Distinct Users Reached (scorecard)
4. Avg Hours to Read (scorecard)
5. Monthly Delivery Volume by Type (stacked area)
6. Monthly Read Rate by Type (line chart)
7. Read Rate by Tag (bar chart)
8. Time to Read Distribution (column chart)
9. Top Notifications by Delivery Volume (grid table)

**Filters:** Date Range (default 90 days), Notification Type, Tag

---

## Update 5: Infrastructure & Workspace Improvements

**Date:** 2026-04-02 (PM)

Several infrastructure improvements made alongside the core deliverable.

**Completed:**
- Connected LookML repo (SoundstripeEngineering/looker) as git submodule at context/lookml/ -- Phase 3 of cross-repo integration roadmap
- Restructured lookml/ workspace: reference/ (refreshable repo mirror) + tasks/ (dated task directories) -- mirrors ETL task pattern for scalability
- Created tracking domain knowledge base: overview.md (tracking architecture), event-taxonomy.md (observed events), event capture runbook
- Created event capture workflow runbook (knowledge/runbooks/event-capture-workflow.md) with JS interceptor scripts for browser event inspection
- Created initiatives/ directory for cross-workspace initiative tracking
- Added /preflight command for proactive environment and target verification before starting tasks
- Enhanced /evolve command with repo health audit phase
- Updated guardrails, dbt-standards, and lookml-standards rules with lessons learned
- Captured 15 feedback memories for future session continuity
