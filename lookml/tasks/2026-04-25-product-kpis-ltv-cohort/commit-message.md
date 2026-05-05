Add fct_ltv_subscription_projections view + LTV by Cohort explore

Adds a subscription-grain view wrapping FINANCE.FCT_LTV_SUBSCRIPTION_PROJECTIONS
with plan_type + billing_period_unit cohort dimensions and a 1-yr LTV measure,
plus an explore for the Product KPIs dashboard. Powers two new tiles
(current 1-yr LTV by cohort, 1-yr LTV over time) requested by Meredith Knott
on Asana 1212712551977630.

The explore is default-filtered to self-serve (plan_type NOT IN ('enterprise',
'twitch-pro')) per the brief: "self-serve only, including Business, exclude
Twitch."

Reconciles within ~5% of fct_kpis_self_service.ltv_1_yr over a 24-12 month
matured-cohort window.
