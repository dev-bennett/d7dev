view: dim_notification_content {
  sql_table_name: SOUNDSTRIPE_PROD.MARKETING.DIM_NOTIFICATION_CONTENT ;;

  dimension: cms_entry_id {
    type: number
    primary_key: yes
    hidden: yes
    sql: ${TABLE}.CMS_ENTRY_ID ;;
  }

  dimension: content_type_id {
    type: number
    hidden: yes
    sql: ${TABLE}.CONTENT_TYPE_ID ;;
  }

  dimension: notification_type {
    type: string
    description: "CMS content type identifier"
    sql: ${TABLE}.NOTIFICATION_TYPE ;;
  }

  dimension: notification_type_name {
    type: string
    description: "Human-readable content type name"
    sql: ${TABLE}.NOTIFICATION_TYPE_NAME ;;
  }

  dimension: title {
    type: string
    description: "Notification title text"
    sql: ${TABLE}.TITLE ;;
  }

  dimension: message {
    type: string
    description: "Notification message body text"
    sql: ${TABLE}.MESSAGE ;;
  }

  dimension: url {
    type: string
    description: "Destination URL for the notification CTA"
    sql: ${TABLE}.URL ;;
  }

  dimension: tag {
    type: string
    description: "Notification category tag"
    sql: ${TABLE}.TAG ;;
  }

  dimension: has_url {
    type: yesno
    description: "Whether the notification has a destination URL"
    sql: ${TABLE}.HAS_URL ;;
  }

  dimension: published {
    type: yesno
    description: "Whether the CMS entry is published"
    sql: ${TABLE}.PUBLISHED ;;
  }

  dimension_group: published {
    type: time
    timeframes: [raw, date, month, quarter, year]
    sql: ${TABLE}.PUBLISHED_AT ;;
    description: "When the CMS entry was published"
  }

  dimension_group: entry_created {
    type: time
    timeframes: [raw, date, month, quarter, year]
    sql: ${TABLE}.ENTRY_CREATED_AT ;;
    description: "When the CMS entry was created"
  }

  measure: total_entries {
    type: count
    description: "Total notification content entries"
    drill_fields: [title, notification_type_name, tag, published_date]
  }

  measure: published_entries {
    type: count
    description: "Total published notification entries"
    filters: [published: "yes"]
  }
}
