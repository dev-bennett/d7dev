{{
    config(
        materialized='table',
    )
}}

-- Phase A scope: Chargebee-billed enterprise customers — covers ~483
-- active HubSpot Companies (≈48% of the ~1,004 won enterprise customer
-- base in dim_enterprise_deals). Non-Chargebee enterprise customers
-- (~225 won companies, 22% of won enterprise) are handled by Phase B
-- (identity bridge — separate work).
--
-- Output grain: one row per HubSpot company_id. Engagement counters are
-- summed across all (chargebee_customer_id, chargebee_subscription_id)
-- combinations associated with the company in dim_enterprise_deals.

with activity as (
    select
        CUSTOMER_ID
        ,SUBSCRIPTION_ID
        ,user_id
        ,event
        ,event_ts
    from {{ref( "subscriber_activity" )}}
    where 1=1
        and PLAN_TYPE = 'enterprise'
        and event_ts::date between dateadd('days', -61, current_date) and dateadd('days', -1, current_date)
)

,deal_company_lookup as (
    -- Distinct (chargebee_customer_id, companyid) pairs from the deal mart.
    -- A single chargebee_customer can map to multiple companyids (max 17,
    -- avg 1.32). The Polytomic sync upserts the same engagement counters
    -- onto each associated company — see verify/ for the fan-out audit.
    select distinct
        chargebee_customer_id
        ,companyid
    from {{ref( "dim_enterprise_deals" )}}
    where chargebee_customer_id is not null
      and companyid is not null
)

,activity_with_company as (
    select
        d.companyid
        ,a.CUSTOMER_ID    as chargebee_customer_id
        ,a.SUBSCRIPTION_ID as chargebee_subscription_id
        ,a.user_id
        ,a.event
        ,a.event_ts
    from activity a
        inner join deal_company_lookup d
            on a.CUSTOMER_ID::string = d.chargebee_customer_id::string
)

select
    companyid
    ,count(distinct user_id) as active_users
    ,count(distinct chargebee_customer_id) as chargebee_customer_count
    ,count(distinct chargebee_subscription_id) as chargebee_subscription_count

    ,sum(case when event = 'session' and datediff('days', event_ts::date, current_date) >= 32 then 1 else 0 end) as sessions_prior_30
    ,sum(case when event in ('sale', 'download') and datediff('days', event_ts::date, current_date) >= 32 then 1 else 0 end) as song_downloads_prior_30
    ,sum(case when event = 'project create' and datediff('days', event_ts::date, current_date) >= 32 then 1 else 0 end) as projects_created_prior_30

    ,sum(case when event = 'session' and datediff('days', event_ts::date, current_date) <= 31 then 1 else 0 end) as sessions_last_30
    ,sum(case when event in ('sale', 'download') and datediff('days', event_ts::date, current_date) <= 31 then 1 else 0 end) as song_downloads_last_30
    ,sum(case when event = 'project create' and datediff('days', event_ts::date, current_date) <= 31 then 1 else 0 end) as projects_created_last_30
from activity_with_company
group by companyid
