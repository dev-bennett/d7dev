# Explore definition for in-app notification performance
# PROMOTION TARGET: Append to Models/General.model.lkml (after the ad_content_performance explore)
#
# No new includes needed -- General.model.lkml already has:
#   include: "/**/*.view.lkml"
#   include: "/dashboards/*.dashboard.lookml"

explore: notification_deliveries {
  label: "In-App Notification Deliveries"
  group_label: "Marketing"
  description: "Notification delivery performance: volume, read rates, and content engagement by type and tag. Covers automated, targeted, and generic in-app notifications."

  view_name: fct_notification_deliveries

  always_filter: {
    filters: [fct_notification_deliveries.delivered_date: "90 days"]
  }

  join: dim_notification_content {
    type: left_outer
    relationship: many_to_one
    sql_on: ${fct_notification_deliveries.cms_entry_id} = ${dim_notification_content.cms_entry_id} ;;
  }
}
