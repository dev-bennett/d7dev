# Insert this block into Models/Finance.model.lkml (preferred) or Models/General.model.lkml.
# Append at the end of the file (or near other Finance/subscription explores).
# No additional include lines needed if the target model already has `include: "/**/*.view.lkml"`.

explore: fct_ltv_subscription_projections {
  label: "LTV by Cohort"
  group_label: "Finance"
  description: "Subscription-grain 1-yr LTV by plan_type + billing_period_unit cohort. Sourced from FINANCE.FCT_LTV_SUBSCRIPTION_PROJECTIONS (unions actuals + projections). Default-filtered to self-serve, excluding Twitch."

  always_filter: {
    filters: [fct_ltv_subscription_projections.is_self_serve: "yes",
              fct_ltv_subscription_projections.is_twitch: "no"]
  }
}
