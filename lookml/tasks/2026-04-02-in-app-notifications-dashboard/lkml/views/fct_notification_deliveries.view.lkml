view: fct_notification_deliveries {
  sql_table_name: SOUNDSTRIPE_PROD.MARKETING.FCT_NOTIFICATION_DELIVERIES ;;

  # Primary key
  dimension: notification_delivery_id {
    type: number
    primary_key: yes
    hidden: yes
    sql: ${TABLE}.NOTIFICATION_DELIVERY_ID ;;
  }

  # Foreign keys
  dimension: user_id {
    type: number
    hidden: yes
    sql: ${TABLE}.USER_ID ;;
  }

  dimension: cms_entry_id {
    type: number
    hidden: yes
    sql: ${TABLE}.CMS_ENTRY_ID ;;
  }

  # Notification attributes
  dimension: notification_type {
    type: string
    group_label: "Notification"
    description: "CMS content type: automatedNotification, targetedNotification, or genericNotification"
    sql: ${TABLE}.NOTIFICATION_TYPE ;;
  }

  dimension: notification_type_name {
    type: string
    group_label: "Notification"
    description: "Human-readable notification type: Automated, Targeted, or Generic"
    sql: ${TABLE}.NOTIFICATION_TYPE_NAME ;;
  }

  dimension: title {
    type: string
    group_label: "Notification"
    description: "Notification title text"
    sql: ${TABLE}.TITLE ;;
  }

  dimension: message {
    type: string
    group_label: "Notification"
    description: "Notification message body"
    sql: ${TABLE}.MESSAGE ;;
  }

  dimension: url {
    type: string
    group_label: "Notification"
    description: "Destination URL for the notification CTA"
    sql: ${TABLE}.URL ;;
  }

  dimension: tag {
    type: string
    group_label: "Notification"
    description: "Notification category tag (New Music, Reminder, Announcement, Update, etc.)"
    sql: ${TABLE}.TAG ;;
  }

  # Read status
  dimension: is_read {
    type: yesno
    group_label: "Engagement"
    description: "Whether the user has read this notification"
    sql: ${TABLE}.IS_READ ;;
  }

  dimension: hours_to_read {
    type: number
    group_label: "Engagement"
    description: "Hours between delivery and read (NULL if unread)"
    sql: ${TABLE}.HOURS_TO_READ ;;
  }

  dimension: time_to_read_bucket {
    type: string
    group_label: "Engagement"
    description: "Bucketed time-to-read for distribution analysis"
    sql: CASE
        WHEN ${hours_to_read} IS NULL THEN 'Unread'
        WHEN ${hours_to_read} < 1 THEN '< 1 Hour'
        WHEN ${hours_to_read} < 6 THEN '1-6 Hours'
        WHEN ${hours_to_read} < 24 THEN '6-24 Hours'
        WHEN ${hours_to_read} < 72 THEN '1-3 Days'
        WHEN ${hours_to_read} < 168 THEN '3-7 Days'
        ELSE '7+ Days'
      END ;;
    order_by_field: time_to_read_bucket_sort
  }

  dimension: time_to_read_bucket_sort {
    type: number
    hidden: yes
    sql: CASE
        WHEN ${hours_to_read} IS NULL THEN 0
        WHEN ${hours_to_read} < 1 THEN 1
        WHEN ${hours_to_read} < 6 THEN 2
        WHEN ${hours_to_read} < 24 THEN 3
        WHEN ${hours_to_read} < 72 THEN 4
        WHEN ${hours_to_read} < 168 THEN 5
        ELSE 6
      END ;;
  }

  # Timestamps
  dimension_group: delivered {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.CREATED_AT ;;
    description: "When the notification was delivered to the user"
  }

  dimension_group: read {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    sql: ${TABLE}.READ_AT ;;
    description: "When the user read the notification (NULL if unread)"
  }

  # Measures
  measure: total_deliveries {
    type: count
    description: "Total notification deliveries"
    drill_fields: [notification_detail*]
  }

  measure: total_read {
    type: count
    description: "Total notifications read"
    filters: [is_read: "yes"]
    drill_fields: [notification_detail*]
  }

  measure: total_unread {
    type: count
    description: "Total notifications not yet read"
    filters: [is_read: "no"]
    drill_fields: [notification_detail*]
  }

  measure: read_rate {
    type: number
    description: "Percentage of delivered notifications that were read"
    sql: 1.0 * ${total_read} / NULLIF(${total_deliveries}, 0) ;;
    value_format_name: percent_2
  }

  measure: distinct_users {
    type: count_distinct
    description: "Distinct users who received notifications"
    sql: ${user_id} ;;
  }

  measure: distinct_notifications {
    type: count_distinct
    description: "Distinct notification content entries delivered"
    sql: ${cms_entry_id} ;;
  }

  measure: avg_hours_to_read {
    type: average
    description: "Average hours between delivery and read (read notifications only)"
    sql: ${hours_to_read} ;;
    filters: [is_read: "yes"]
    value_format_name: decimal_1
  }

  # Drill set
  set: notification_detail {
    fields: [
      notification_type_name,
      title,
      tag,
      delivered_date,
      is_read,
      hours_to_read
    ]
  }
}
