{{ config(
    materialized='view'
) }}

/*
  ================================================================================
  fct_sessions_enriched.sql
  ================================================================================
  Description:
      Single source of truth for session-level data with reconciled MQL metrics.
      Combines all fct_sessions columns with HubSpot-sourced MQL data from
      dim_session_mqls, which achieves 100% HubSpot-to-Mixpanel-session
      attribution via tiered matching.

      This model replaces fct_sessions as the primary analytical and reporting
      surface for any query that involves MQL metrics. All non-MQL columns are
      passed through unchanged.

  Sources:
      - fct_sessions (all session-level data)
      - dim_session_mqls (HubSpot-sourced MQL flags matched to sessions)

  MQL Column Strategy:
      - Original Mixpanel-only MQL columns are preserved with _mixpanel suffix
        for backward compatibility and audit purposes
      - New HubSpot-sourced MQL columns use the original column names so
        downstream models and LookML measures work without changes
      - New columns added: has_mql, mql_form_submissions, mql_distinct_contacts,
        form-page-type flags, match tier, submission timestamps

  Join:
      LEFT JOIN dim_session_mqls on session_id (1:1)
      Sessions without MQLs get 0/NULL for all MQL columns.
  ================================================================================
*/

select
    -- ========================================================================
    -- All fct_sessions columns EXCEPT the MQL columns we're replacing
    -- ========================================================================
    s.distinct_id
    ,s.session_id
    ,s.LAST_CHANNEL_NON_DIRECT
    ,s.LAST_UTM_MEDIUM_NON_DIRECT
    ,s.LAST_UTM_SOURCE_NON_DIRECT
    ,s.LAST_UTM_TERM_NON_DIRECT
    ,s.LAST_UTM_CAMPAIGN_NON_DIRECT
    ,s.LAST_UTM_CONTENT_NON_DIRECT
    ,s.LAST_REFERRING_DOMAIN_NON_DIRECT
    ,s.LAST_REFERRER_NON_DIRECT
    ,s.marketing_test_ind
    ,s.channel
    ,s.referrer
    ,s.referring_domain
    ,s.utm_campaign
    ,s.utm_content
    ,s.utm_medium
    ,s.utm_source
    ,s.utm_term
    ,s.consolidated_sessions
    ,s.consolidated_distinct_ids
    ,s.city
    ,s.is_mobile_app
    ,s.user_id
    ,s.SESSION_STARTED_AT
    ,s.SESSION_ENDED_AT
    ,s.SESSION_DURATION_SECONDS
    ,s.session_counter
    ,s.device
    ,s.browser
    ,s.REGION
    ,s.COUNTRY
    ,s.PLAN_ID
    ,s.PLAN_NAME
    ,s.CURRENT_SUBSCRIPTION_ID
    ,s.CURRENT_ACCOUNT_ID
    ,s.LANDING_PAGE_URL
    ,s.LANDING_PAGE_HOST
    ,s.LANDING_PAGE_PATH
    ,s.LANDING_PAGE_CATEGORY
    ,s.pageviews
    ,s.bounced_sessions
    ,s.has_app_view
    ,s.has_www_view
    ,s.signed_up
    ,s.signed_in

    -- ========================================================================
    -- Reconciled MQL columns (HubSpot-sourced, tiered Mixpanel matching)
    -- These REPLACE the Mixpanel-only columns for reporting purposes
    -- ========================================================================

    -- Primary MQL flag: 1 if session has any matched HubSpot enterprise form submission
    ,coalesce(m.has_mql, 0)                         as has_mql

    -- Reconciled enterprise form submissions count (replaces enterprise_form_submissions)
    ,coalesce(m.mql_form_submissions, 0)             as enterprise_form_submissions
    ,coalesce(m.mql_distinct_contacts, 0)            as mql_distinct_contacts

    -- Page-type breakdown flags
    ,coalesce(m.has_enterprise_landing_mql, 0)       as has_enterprise_landing_mql
    ,coalesce(m.has_brand_solutions_mql, 0)          as has_brand_solutions_mql
    ,coalesce(m.has_agency_solutions_mql, 0)         as has_agency_solutions_mql
    ,coalesce(m.has_enterprise_page_mql, 0)          as has_enterprise_page_mql

    -- Reconciled landing form + schedule demo (preserve column names for downstream compat)
    -- These retain the Mixpanel-only values since dim_mql_mapping doesn't
    -- separate by these categories — the HubSpot form is the same form on all pages
    ,s.enterprise_landing_form_submissions
    ,s.enterprise_schedule_demo

    -- View metrics (Mixpanel-only, no HubSpot equivalent)
    ,s.enterprise_form_view
    ,s.enterprise_landing_form_views

    -- Match quality
    ,m.best_match_tier                               as mql_match_tier
    ,m.first_mql_submission_ts
    ,m.last_mql_submission_ts

    -- ========================================================================
    -- Original Mixpanel-only MQL column preserved for audit/comparison
    -- ========================================================================
    ,s.enterprise_form_submissions                   as enterprise_form_submissions_mixpanel

    -- ========================================================================
    -- Remaining fct_sessions columns (non-MQL)
    -- ========================================================================
    ,s.CREATED_SUBSCRIPTION
    ,s.CANCELLED_SUBSCRIPTION
    ,s.is_existing_subscriber
    ,s.subscriber_category
    ,s.PURCHASED_PRODUCT
    ,s.PURCHASED_PRODUCT_COUNT
    ,s.SINGLE_SONG_PURCHASE_COUNT
    ,s.SINGLE_SONG_PURCHASE
    ,s.SINGLE_SONG_PURCHASE_AMOUNT
    ,s.SFX_PURCHASE_COUNT
    ,s.SFX_PURCHASE
    ,s.SFX_PURCHASE_AMOUNT
    ,s.MARKET_PURCHASE_COUNT
    ,s.MARKET_PURCHASE
    ,s.MARKET_PURCHASE_AMOUNT
    ,s.SEARCHED_SONGS_COUNT
    ,s.ai_searched_song_count
    ,s.SEARCHED_SONGS
    ,s.PLAYED_SONGS_COUNT
    ,s.PLAYED_SONGS
    ,s.DOWNLOADED_SONGS_COUNT
    ,s.DOWNLOADED_SONGS
    ,s.SEARCHED_SOUND_EFFECTS_COUNT
    ,s.SEARCHED_SOUND_EFFECTS
    ,s.DOWNLOADED_SOUND_EFFECTS_COUNT
    ,s.DOWNLOADED_SOUND_EFFECTS
    ,s.played_sound_effects_count
    ,s.played_sound_effects

from {{ ref("fct_sessions") }} s
    left join {{ ref("dim_session_mqls") }} m
        on s.session_id = m.session_id
