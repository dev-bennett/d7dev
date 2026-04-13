{{
    config(
        materialized = 'table',
        on_schema_change = 'sync_all_columns'
    )
}}

/*
  ================================================================================
  dim_session_mqls.sql
  ================================================================================
  Description:
      Session-level MQL bridge table. Aggregates dim_mql_mapping to one row per
      Mixpanel session, joinable 1:1 to fct_sessions on session_id.

      Provides HubSpot-sourced MQL counts and flags attributed to the Mixpanel
      session that was active at the time of form submission. This replaces the
      fct_sessions.enterprise_form_submissions column as the source of truth for
      MQL counting in Looker.

  Sources:
      - dim_mql_mapping (tiered HubSpot-to-Mixpanel matching)

  Join Pattern:
      fct_sessions LEFT JOIN dim_session_mqls
          ON fct_sessions.session_id = dim_session_mqls.session_id

  Output:
      One row per session_id that has at least one matched HubSpot MQL.
      Sessions without MQLs are not represented (LEFT JOIN from fct_sessions
      yields NULLs, which Looker measures handle with COALESCE).
  ================================================================================
*/

with mql_detail as (
    select
        mixpanel_session_id as session_id
        ,mixpanel_distinct_id as distinct_id
        ,email
        ,SUBMISSION_TS
        ,form_page_type
        ,match_tier
        ,match_reason
        ,FORM_OBJECT_ID
    from {{ ref("dim_mql_mapping") }}
    where mixpanel_session_id is not null
)

select
    session_id

    -- Counts
    ,count(distinct FORM_OBJECT_ID)   as mql_form_submissions
    ,count(distinct email)            as mql_distinct_contacts

    -- Flags by form page type
    ,max(case when form_page_type = 'enterprise_landing' then 1 else 0 end) as has_enterprise_landing_mql
    ,max(case when form_page_type = 'brand_solutions' then 1 else 0 end)    as has_brand_solutions_mql
    ,max(case when form_page_type = 'agency_solutions' then 1 else 0 end)   as has_agency_solutions_mql
    ,max(case when form_page_type = 'enterprise_page' then 1 else 0 end)    as has_enterprise_page_mql

    -- Combined flag: session has any MQL
    ,1 as has_mql

    -- Match quality (best tier wins: tier1 > tier2 > tier3)
    ,min(match_tier) as best_match_tier

    -- Timing
    ,min(SUBMISSION_TS) as first_mql_submission_ts
    ,max(SUBMISSION_TS) as last_mql_submission_ts

from mql_detail
group by 1
