view: fct_ltv_subscription_projections {
  sql_table_name: "FINANCE"."FCT_LTV_SUBSCRIPTION_PROJECTIONS" ;;

  # ---- Primary key ----

  dimension: subscription_id {
    type: string
    primary_key: yes
    hidden: yes
    sql: ${TABLE}."SUBSCRIPTION_ID" ;;
  }

  # ---- Cohort dimensions ----

  dimension: plan_type {
    type: string
    group_label: "Cohort"
    description: "Subscription plan tier: business, creator, pro, pro-plus, twitch-pro, etc."
    sql: ${TABLE}."PLAN_TYPE" ;;
  }

  dimension: billing_period_unit {
    type: string
    group_label: "Cohort"
    description: "Billing cycle: month, quarter, or year."
    sql: ${TABLE}."BILLING_PERIOD_UNIT" ;;
  }

  dimension: plan_cohort {
    type: string
    group_label: "Cohort"
    label: "Plan + Billing"
    description: "Cohort label combining plan type and billing cycle (e.g., 'pro year', 'business month')."
    sql: ${TABLE}."PLAN_TYPE" || ' ' || ${TABLE}."BILLING_PERIOD_UNIT" ;;
  }

  dimension: is_self_serve {
    type: yesno
    group_label: "Cohort"
    description: "True for the four current self-serve plan tiers (business, creator, pro, pro-plus). False for enterprise, twitch-pro, and deprecated/partner plans (subaccounts, straynote-billing). Positive list — new plans default to NOT self-serve until added here."
    sql: ${TABLE}."PLAN_TYPE" IN ('business', 'creator', 'pro', 'pro-plus') ;;
  }

  dimension: is_twitch {
    type: yesno
    group_label: "Cohort"
    description: "True for Twitch-Pro subscriptions; excluded from self-serve LTV tiles by default."
    sql: ${TABLE}."PLAN_TYPE" = 'twitch-pro' ;;
  }

  # ---- Subscription attributes ----

  dimension: soundstripe_subscription_id {
    type: number
    hidden: yes
    sql: ${TABLE}."SOUNDSTRIPE_SUBSCRIPTION_ID" ;;
  }

  dimension: plan_detail {
    type: string
    group_label: "Subscription"
    description: "Free-text plan description from Chargebee (e.g., specific tier and pricing identifier)."
    sql: ${TABLE}."PLAN_DETAIL" ;;
  }

  dimension: current_contract_state {
    type: string
    group_label: "Subscription"
    description: "Current Chargebee contract state for the subscription (active, cancelled, etc.)."
    sql: ${TABLE}."CURRENT_CONTRACT_STATE" ;;
  }

  dimension: current_sub_mrr {
    type: number
    hidden: yes
    sql: ${TABLE}."CURRENT_SUB_MRR" ;;
  }

  dimension: value_type {
    type: string
    group_label: "Subscription"
    description: "'invoice payment' = actual paid revenue; 'projected payment' = model-based projection for in-flight cohorts."
    sql: ${TABLE}."VALUE_TYPE" ;;
  }

  dimension: months_into_subscription {
    type: number
    hidden: yes
    sql: ${TABLE}."MONTHS_INTO_SUBSCRIPTION" ;;
  }

  dimension: months_into_subscription_paid {
    type: number
    hidden: yes
    sql: ${TABLE}."MONTHS_INTO_SUBSCRIPTION_PAID" ;;
  }

  dimension: months_to_invoice {
    type: number
    hidden: yes
    sql: ${TABLE}."MONTHS_TO_INVOICE" ;;
  }

  dimension: total_amount_paid_per_row {
    type: number
    hidden: yes
    sql: ${TABLE}."TOTAL_AMOUNT_PAID" ;;
  }

  # ---- Acquisition attributes ----

  dimension: converting_session_id {
    type: string
    hidden: yes
    sql: ${TABLE}."CONVERTING_SESSION_ID" ;;
  }

  dimension: last_channel_non_direct {
    type: string
    group_label: "Acquisition"
    description: "Last non-direct marketing channel attributed to the converting session."
    sql: ${TABLE}."LAST_CHANNEL_NON_DIRECT" ;;
  }

  dimension: business_type_array {
    type: string
    group_label: "User"
    description: "Business types declared by the subscriber (concatenated; multi-value)."
    sql: ${TABLE}."BUSINESS_TYPE_ARRAY" ;;
  }

  dimension: project_types {
    type: string
    group_label: "User"
    description: "Project types declared by the subscriber (concatenated; multi-value)."
    sql: ${TABLE}."PROJECT_TYPES" ;;
  }

  dimension: user_types {
    type: string
    group_label: "User"
    description: "User types declared by the subscriber (concatenated; multi-value)."
    sql: ${TABLE}."USER_TYPES" ;;
  }

  # ---- Dimension groups ----

  dimension_group: sub_start {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    description: "Subscription start date (cohort signup date)."
    sql: ${TABLE}."SUB_START_DATE" ;;
  }

  dimension_group: sub_end {
    type: time
    timeframes: [raw, date, week, month, quarter, year]
    description: "Subscription end date (cancellation or current term end)."
    sql: ${TABLE}."SUB_END_DATE" ;;
  }

  # ---- Measures ----

  measure: subscription_count {
    group_label: "LTV"
    type: count_distinct
    description: "Distinct subscriptions in scope. Used as the denominator for per-subscription LTV."
    sql: ${TABLE}."SUBSCRIPTION_ID" ;;
    value_format_name: decimal_0
    drill_fields: [plan_type, billing_period_unit, sub_start_date, current_contract_state]
  }

  measure: ltv_1_yr_total {
    group_label: "LTV"
    label: "1-Yr LTV (Total)"
    type: sum
    description: "Sum of paid + projected revenue across the first 12 months per subscription. Sources actual invoice payments where available and the model's monthly projections for cohorts <12 months old; older cohorts are entirely actual."
    sql: ${TABLE}."TOTAL_AMOUNT_PAID" ;;
    filters: [months_into_subscription: "<=12"]
    value_format_name: usd
    drill_fields: [plan_type, billing_period_unit, value_type, sub_start_date]
  }

  measure: ltv_1_yr_per_subscription {
    group_label: "LTV"
    label: "1-Yr LTV / Subscription"
    type: number
    description: "Average 1-year LTV per subscription within the filtered cohort. Use this for headline cohort comparisons; ltv_1_yr_total is sensitive to cohort size."
    sql: ${ltv_1_yr_total} / NULLIF(${subscription_count}, 0) ;;
    value_format_name: usd
    drill_fields: [plan_type, billing_period_unit, sub_start_date]
  }
}
