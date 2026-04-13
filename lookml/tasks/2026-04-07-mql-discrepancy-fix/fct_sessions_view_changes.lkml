# ============================================================================
# fct_sessions.view.lkml — Changes for MQL Reconciliation
# ============================================================================
# This file documents the changes needed to the existing fct_sessions view
# to point at fct_sessions_enriched and use the reconciled MQL columns.
#
# CHANGE 1: Update sql_table_name (line 2)
# CHANGE 2: Add new MQL dimensions and measures (insert after line 496)
# CHANGE 3: Hide/relabel old MQL measures (lines 464-558)
# ============================================================================


# ===========================================================================
# CHANGE 1: Update sql_table_name
# ===========================================================================
# Replace:
#   sql_table_name: soundstripe_prod."CORE".FCT_SESSIONS ;;
# With:
#   sql_table_name: soundstripe_prod."CORE".FCT_SESSIONS_ENRICHED ;;
#
# NOTE: fct_sessions_enriched must be deployed to the CORE schema in
# soundstripe_prod. The dbt model should specify schema: core or be placed
# in models/marts/core/.


# ===========================================================================
# CHANGE 2: Add new MQL dimensions and measures
# Insert after the existing enterprise_schedule_demo measure (line ~496)
# ===========================================================================

  # --- Reconciled MQL Dimensions (HubSpot-Sourced) --------------------------

  dimension: has_mql {
    group_label: "MQL (Reconciled)"
    type: yesno
    sql: ${TABLE}."HAS_MQL" = 1 ;;
    description: "Session has at least one HubSpot enterprise form submission matched to this Mixpanel session via tiered reconciliation"
  }

  dimension: has_enterprise_landing_mql {
    group_label: "MQL (Reconciled)"
    type: yesno
    sql: ${TABLE}."HAS_ENTERPRISE_LANDING_MQL" = 1 ;;
    description: "MQL from /music-licensing-for-enterprise"
  }

  dimension: has_brand_solutions_mql {
    group_label: "MQL (Reconciled)"
    type: yesno
    sql: ${TABLE}."HAS_BRAND_SOLUTIONS_MQL" = 1 ;;
    description: "MQL from /brand-solutions"
  }

  dimension: has_agency_solutions_mql {
    group_label: "MQL (Reconciled)"
    type: yesno
    sql: ${TABLE}."HAS_AGENCY_SOLUTIONS_MQL" = 1 ;;
    description: "MQL from /agency-solutions"
  }

  dimension: has_enterprise_page_mql {
    group_label: "MQL (Reconciled)"
    type: yesno
    sql: ${TABLE}."HAS_ENTERPRISE_PAGE_MQL" = 1 ;;
    description: "MQL from /enterprise CTA form"
  }

  dimension: mql_match_tier {
    group_label: "MQL (Reconciled)"
    type: string
    sql: ${TABLE}."MQL_MATCH_TIER" ;;
    description: "Match confidence: tier1_form (direct event) > tier2_page (page view) > tier3_session (proximity)"
  }

  dimension: mql_distinct_contacts {
    group_label: "MQL (Reconciled)"
    type: number
    hidden: yes
    sql: ${TABLE}."MQL_DISTINCT_CONTACTS" ;;
  }

  dimension: enterprise_form_submissions_mixpanel {
    group_label: "MQL (Reconciled)"
    label: "Enterprise Form Submissions (Mixpanel Only)"
    type: number
    hidden: yes
    sql: ${TABLE}."ENTERPRISE_FORM_SUBMISSIONS_MIXPANEL" ;;
    description: "Original Mixpanel-only enterprise form submission count. Use the reconciled MQL measures instead."
  }

  # --- Reconciled MQL Measures ----------------------------------------------

  measure: mqls_reconciled {
    group_label: "MQL (Reconciled)"
    label: "MQLs"
    type: count_distinct
    sql: case when ${has_mql} then ${TABLE}.distinct_id end ;;
    value_format: "#,##0"
    description: "Distinct visitors with at least one HubSpot enterprise form submission matched to a Mixpanel session. Source of truth for MQL volume."
    drill_fields: [last_channel_non_direct]
  }

  measure: mqls_enterprise_landing_reconciled {
    group_label: "MQL (Reconciled)"
    label: "MQLs - Enterprise Landing"
    type: count_distinct
    sql: case when ${has_enterprise_landing_mql} then ${TABLE}.distinct_id end ;;
    value_format: "#,##0"
    description: "MQLs from /music-licensing-for-enterprise"
    drill_fields: [last_channel_non_direct]
  }

  measure: mqls_brand_solutions_reconciled {
    group_label: "MQL (Reconciled)"
    label: "MQLs - Brand Solutions"
    type: count_distinct
    sql: case when ${has_brand_solutions_mql} then ${TABLE}.distinct_id end ;;
    value_format: "#,##0"
    description: "MQLs from /brand-solutions"
    drill_fields: [last_channel_non_direct]
  }

  measure: mqls_agency_solutions_reconciled {
    group_label: "MQL (Reconciled)"
    label: "MQLs - Agency Solutions"
    type: count_distinct
    sql: case when ${has_agency_solutions_mql} then ${TABLE}.distinct_id end ;;
    value_format: "#,##0"
    description: "MQLs from /agency-solutions"
    drill_fields: [last_channel_non_direct]
  }

  measure: mql_assumed_1yr_revenue_reconciled {
    group_label: "MQL (Reconciled)"
    label: "MQL Assumed 1yr Revenue"
    type: number
    sql: ${mqls_reconciled} * .05 * 6000 ;;
    value_format: "$#,##0"
    description: "Assumed 1 Yr MQL value: 5% MQL to deal won conversion rate * $6,000 1 year revenue"
  }

  measure: total_mql_form_submissions {
    group_label: "MQL (Reconciled)"
    type: sum
    sql: ${TABLE}."ENTERPRISE_FORM_SUBMISSIONS" ;;
    value_format: "#,##0"
    description: "Total HubSpot enterprise form submissions matched to sessions (reconciled count)"
  }


# ===========================================================================
# CHANGE 3: Hide old Mixpanel-only MQL measures
# Add hidden: yes to these existing measures (lines 464-558):
#   - mqls_pricing_page (line 464)
#   - mqls_enterprise_page (line 477)
#   - mqls_schedule_demo (line 490)
#   - mql_pricing_page (line 539)
#   - mqls (line 545)
#   - mql_assumed_1yr_revenue (line 553)
#
# Or relabel them with "(Mixpanel Only)" suffix for audit access.
# ===========================================================================
