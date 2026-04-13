# Promotion Guide: In-App Notification Performance Dashboard

## Overview

4 files to add to the Looker repo (SoundstripeEngineering/looker). No existing files are modified except `General.model.lkml` which gets one new explore appended.

## Step-by-Step

### Step 1: Create View Files

Create these two files in `views/General/`:

**File:** `views/General/fct_notification_deliveries.view.lkml`
- Source: `lookml/views/fct_notification_deliveries.view.lkml`
- Copy the full contents as-is

**File:** `views/General/dim_notification_content.view.lkml`
- Source: `lookml/views/dim_notification_content.view.lkml`
- Copy the full contents as-is

No include changes needed -- `General.model.lkml` already has `include: "/**/*.view.lkml"` which auto-discovers views in all subdirectories.

### Step 2: Create Dashboard File

**File:** `dashboards/in_app_notification_performance.dashboard.lookml`
- Source: `lookml/dashboards/in_app_notification_performance.dashboard.lookml`
- Copy the full contents as-is
- Note the extension is `.dashboard.lookml` (not `.lkml`)

No include changes needed -- `General.model.lkml` already has `include: "/dashboards/*.dashboard.lookml"`.

### Step 3: Add Explore to General.model.lkml

Open `Models/General.model.lkml` and append the following at the end of the file (after the last explore definition, which is currently `ad_content_performance`):

```lookml
explore: notification_deliveries {
  label: "In-App Notification Deliveries"
  group_label: "Marketing"
  description: "Notification delivery performance: volume, read rates, and content engagement by type and tag. Covers automated, targeted, and generic in-app notifications."

  from: fct_notification_deliveries

  always_filter: {
    filters: [fct_notification_deliveries.delivered_date: "90 days"]
  }

  join: dim_notification_content {
    type: left_outer
    relationship: many_to_one
    sql_on: ${fct_notification_deliveries.cms_entry_id} = ${dim_notification_content.cms_entry_id} ;;
  }
}
```

Source reference: `lookml/explores/notification_deliveries.explore.lkml`

### Step 4: Validate in Looker IDE

1. Open your Looker development branch
2. Validate the project -- should show no LookML errors
3. Test the explore: navigate to Explore > In-App Notification Deliveries
4. Run a simple query: `notification_type_name` + `total_deliveries` + `read_rate`
5. Open the dashboard: In-App Notification Performance
6. Verify scorecard values against baselines below

### Step 5: Commit and PR

Use the commit message and PR description from:
- `lookml/commit-message-notifications-dashboard.md`
- `lookml/pr-description-notifications-dashboard.md`

## Validation Baselines (from post-fix exploration)

Use these to confirm the dashboard is reading correct data:

| Metric | Expected Value (all-time) |
|--------|--------------------------|
| Total deliveries | ~3.22M |
| Automated read rate | ~16.3% |
| Targeted read rate | ~6.3% |
| Generic read rate | ~98.9% |
| Distinct users | ~554K |
| Top notification by volume | "You asked, we listened!" ~293K deliveries |
| New Music tag read rate | ~17.8% |
| Reminder tag read rate | ~4.7% |

Note: Dashboard defaults to 90-day filter, so numbers will be a subset of these all-time figures.

## File Map

| Source (lookml/ workspace) | Target (Looker repo) |
|---------------------------|---------------------|
| `lookml/views/fct_notification_deliveries.view.lkml` | `views/General/fct_notification_deliveries.view.lkml` |
| `lookml/views/dim_notification_content.view.lkml` | `views/General/dim_notification_content.view.lkml` |
| `lookml/dashboards/in_app_notification_performance.dashboard.lookml` | `dashboards/in_app_notification_performance.dashboard.lookml` |
| `lookml/explores/notification_deliveries.explore.lkml` | Append contents to `Models/General.model.lkml` |
