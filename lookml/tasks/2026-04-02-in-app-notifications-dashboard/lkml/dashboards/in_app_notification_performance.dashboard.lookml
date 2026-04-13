- dashboard: in_app_notification_performance
  title: "In-App Notification Performance"
  layout: newspaper
  preferred_viewer: dashboards-next
  description: "Delivery volume, read rates, and content performance for in-app notifications. Covers automated, targeted, and generic notification types."

  filters:
    - name: date_range
      title: "Date Range"
      type: field_filter
      explore: notification_deliveries
      field: fct_notification_deliveries.delivered_date
      default_value: "90 days"

    - name: notification_type
      title: "Notification Type"
      type: field_filter
      explore: notification_deliveries
      field: fct_notification_deliveries.notification_type_name

    - name: tag
      title: "Tag"
      type: field_filter
      explore: notification_deliveries
      field: fct_notification_deliveries.tag

  elements:
    # Row 1: Scorecards
    - title: "Total Deliveries"
      name: total_deliveries
      explore: notification_deliveries
      type: single_value
      fields: [fct_notification_deliveries.total_deliveries]
      filters:
        fct_notification_deliveries.delivered_date: ""
      listen:
        date_range: fct_notification_deliveries.delivered_date
        notification_type: fct_notification_deliveries.notification_type_name
        tag: fct_notification_deliveries.tag
      row: 0
      col: 0
      width: 6
      height: 4

    - title: "Read Rate"
      name: read_rate
      explore: notification_deliveries
      type: single_value
      fields: [fct_notification_deliveries.read_rate]
      filters:
        fct_notification_deliveries.delivered_date: ""
      listen:
        date_range: fct_notification_deliveries.delivered_date
        notification_type: fct_notification_deliveries.notification_type_name
        tag: fct_notification_deliveries.tag
      row: 0
      col: 6
      width: 6
      height: 4

    - title: "Distinct Users Reached"
      name: distinct_users
      explore: notification_deliveries
      type: single_value
      fields: [fct_notification_deliveries.distinct_users]
      filters:
        fct_notification_deliveries.delivered_date: ""
      listen:
        date_range: fct_notification_deliveries.delivered_date
        notification_type: fct_notification_deliveries.notification_type_name
        tag: fct_notification_deliveries.tag
      row: 0
      col: 12
      width: 6
      height: 4

    - title: "Avg Hours to Read"
      name: avg_hours_to_read
      explore: notification_deliveries
      type: single_value
      fields: [fct_notification_deliveries.avg_hours_to_read]
      filters:
        fct_notification_deliveries.delivered_date: ""
      listen:
        date_range: fct_notification_deliveries.delivered_date
        notification_type: fct_notification_deliveries.notification_type_name
        tag: fct_notification_deliveries.tag
      row: 0
      col: 18
      width: 6
      height: 4

    # Row 2: Time series
    - title: "Monthly Delivery Volume by Type"
      name: delivery_volume_over_time
      explore: notification_deliveries
      type: looker_area
      fields: [fct_notification_deliveries.delivered_month, fct_notification_deliveries.notification_type_name, fct_notification_deliveries.total_deliveries]
      pivots: [fct_notification_deliveries.notification_type_name]
      filters:
        fct_notification_deliveries.delivered_date: ""
      sorts: [fct_notification_deliveries.delivered_month]
      listen:
        date_range: fct_notification_deliveries.delivered_date
        notification_type: fct_notification_deliveries.notification_type_name
        tag: fct_notification_deliveries.tag
      row: 4
      col: 0
      width: 12
      height: 8

    - title: "Monthly Read Rate by Type"
      name: read_rate_over_time
      explore: notification_deliveries
      type: looker_line
      fields: [fct_notification_deliveries.delivered_month, fct_notification_deliveries.notification_type_name, fct_notification_deliveries.read_rate]
      pivots: [fct_notification_deliveries.notification_type_name]
      filters:
        fct_notification_deliveries.delivered_date: ""
      sorts: [fct_notification_deliveries.delivered_month]
      listen:
        date_range: fct_notification_deliveries.delivered_date
        notification_type: fct_notification_deliveries.notification_type_name
        tag: fct_notification_deliveries.tag
      row: 4
      col: 12
      width: 12
      height: 8

    # Row 3: Breakdowns
    - title: "Read Rate by Tag"
      name: read_rate_by_tag
      explore: notification_deliveries
      type: looker_bar
      fields: [fct_notification_deliveries.tag, fct_notification_deliveries.total_deliveries, fct_notification_deliveries.read_rate]
      filters:
        fct_notification_deliveries.delivered_date: ""
        fct_notification_deliveries.notification_type: "-NULL"
      sorts: [fct_notification_deliveries.total_deliveries desc]
      listen:
        date_range: fct_notification_deliveries.delivered_date
        notification_type: fct_notification_deliveries.notification_type_name
        tag: fct_notification_deliveries.tag
      row: 12
      col: 0
      width: 12
      height: 8

    - title: "Time to Read Distribution"
      name: time_to_read_distribution
      explore: notification_deliveries
      type: looker_column
      fields: [fct_notification_deliveries.time_to_read_bucket, fct_notification_deliveries.total_deliveries]
      filters:
        fct_notification_deliveries.delivered_date: ""
      sorts: [fct_notification_deliveries.time_to_read_bucket_sort]
      listen:
        date_range: fct_notification_deliveries.delivered_date
        notification_type: fct_notification_deliveries.notification_type_name
        tag: fct_notification_deliveries.tag
      row: 12
      col: 12
      width: 12
      height: 8

    # Row 4: Content performance table
    - title: "Top Notifications by Delivery Volume"
      name: top_notifications
      explore: notification_deliveries
      type: looker_grid
      fields: [fct_notification_deliveries.title, fct_notification_deliveries.notification_type_name, fct_notification_deliveries.tag, fct_notification_deliveries.total_deliveries, fct_notification_deliveries.total_read, fct_notification_deliveries.read_rate, fct_notification_deliveries.avg_hours_to_read]
      filters:
        fct_notification_deliveries.delivered_date: ""
        fct_notification_deliveries.notification_type: "-NULL"
      sorts: [fct_notification_deliveries.total_deliveries desc]
      limit: 25
      listen:
        date_range: fct_notification_deliveries.delivered_date
        notification_type: fct_notification_deliveries.notification_type_name
        tag: fct_notification_deliveries.tag
      row: 20
      col: 0
      width: 24
      height: 10
