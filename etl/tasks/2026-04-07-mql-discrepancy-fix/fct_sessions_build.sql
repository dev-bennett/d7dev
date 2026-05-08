{{
    config(
        materialized = 'incremental',
        on_schema_change = 'sync_all_columns',
        unique_key = 'session_id'
    )
}}

/*
  ================================================================================
  fct_sessions_build.sql — FOLLOW-UP TO PR #718 (drop-in replacement)
  ================================================================================
  Status:
      Base scope shipped in PR #718 (merged 2026-04-22, SHA 504f24d).
      THIS FILE applies one follow-up edit on top of HEAD:

      CHANGE B: backfill_from var added to the incremental block so future
                scope changes don't require a manual DELETE FROM <prod_table>
                dance to shift the watermark.

      ⚠ CHANGE A (enterprise_schedule_demo expansion to include
        Clicked Contact Sales / Enterprise Intent) was REVERTED 2026-05-07
        after a deployment showed it inflating mqls_schedule_demo by ~49x.
        The Clicked Contact Sales event is high-volume (1,997 events, 1,567
        distinct_ids YTD-2026 vs. 36/32 for the original signal). It belongs
        ONLY in dim_mql_mapping.form_events_mixpanel (HubSpot-anchored —
        Change 2B), where the join to HubSpot form submissions filters down
        to real MQLs. It does NOT belong in fct_sessions_build, which feeds
        a Looker measure (mqls_schedule_demo) with no HubSpot anchoring.

      Drop-in replacement for the dbt-Cloud editor on develop_dab.
      See implementation-guide.md for the full deployment runbook.
  ================================================================================
*/


with ordered_values as
(
    select
        *
        ,case when channel is null then 0 else 1 end as channel_present
        ,row_number() over(partition by session_id, channel_present order by event_ts asc) as row_id
    from {{ ref("fct_events") }}
    -- CHANGE B: backfill_from var added so historical reprocessing doesn't require manual prod-row deletes.
    -- Pattern matches fct_events.sql (line 112-118): branch the entire WHERE clause —
    -- DON'T try to coalesce a literal into the aggregate subquery. `select <literal> from {{ this }}`
    -- would return one row per existing row, causing "Single-row subquery returns more than one row".
    {% if is_incremental() %}
        {% if var('backfill_from', none) is not none %}
            where
                event_ts::date >= '{{ var("backfill_from") }}'::date
        {% else %}
            where
                event_ts::date >= (select dateadd('days', -2, coalesce(max(session_started_at), '1900-01-01')::date) from {{ this }} )
        {% endif %}
    {% endif %}

)

,session_consolidated as
(
    select
        SESSION_ID
        ,DISTINCT_ID
        ,max(USER_ID) as user_id
        ,max(case when channel_present = 1 and row_id = 1 then channel end) as entry_channel
        ,max(case when channel_present = 1 and row_id = 1 then utm_medium end) as entry_utm_medium
        ,max(case when channel_present = 1 and row_id = 1 then utm_source end) as entry_utm_source
        ,max(case when channel_present = 1 and row_id = 1 then utm_term end) as entry_utm_term
        ,max(case when channel_present = 1 and row_id = 1 then utm_campaign end) as entry_utm_campaign
        ,max(case when channel_present = 1 and row_id = 1 then utm_content end) as entry_utm_content
        ,max(case when channel_present = 1 and row_id = 1 then referring_domain end) as entry_referring_domain
        ,max(case when channel_present = 1 and row_id = 1 then referrer end) as entry_referrer
        ,min(event_ts) as session_started_at
        ,max(event_ts) as session_ended_at
        ,datediff('seconds', session_started_at, session_ended_at) as session_duration_seconds
        ,max(device) as device
        ,max(browser) as browser
        ,max(city) as city
        ,max(region) as region
        ,max(country) as country
        ,max(plan_id) as plan_id
        ,max(plan_name) as plan_name
        ,max(current_subscription_id) as current_subscription_id
        ,max(current_account_id) as current_account_id
        ,max(case when event_counter = 1 then url end) as landing_page_url
        ,max(case when event_counter = 1 then host end) as landing_page_host
        ,max(case when event_counter = 1 then path end) as landing_page_path
        ,max(case when event_counter = 1 then page_category end) as landing_page_category
        ,case when sum(case when event = 'Created Subscription' then 1 else 0  end) > 0 then 0
              when sum(case when current_subscription_id is not null then 1 else 0 end) > 0 then 1
              else 0 end as is_existing_subscriber
        ,max(case when event_counter = 1 then is_mobile_app end) as is_mobile_app

        -- Browsing data
        ,count(distinct concat(host, '/', path)) as pageviews
        ,case when pageviews <= 1 then 1 else 0 end as bounced_sessions

        ,max(case when event in ('$mp_web_page_view','Viewed Page') and host = 'app.soundstripe.com' then 1 else 0 end) as has_app_view
        ,max(case when event in ('$mp_web_page_view','Viewed Page') and host = 'www.soundstripe.com' then 1 else 0 end) as has_www_view

        -- Conversion data (base scope shipped in PR #718)
        ,sum(case when (event = 'Submitted Form' and lower(context) = 'enterprise contact form')
                      or (event = 'Submitted Form' and url ilike '%/brand-solutions%')
                      or (event = 'Submitted Form' and url ilike '%/agency-solutions%')
                      or (event = 'CTA Form Submitted' and url ilike '%/enterprise%')
                 then 1 else 0 end) as enterprise_form_submissions
        ,sum(case when event = 'Viewed Enterprise Contact Form' then 1
                  when event = '$mp_web_page_view' and url ilike '%soundstripe.com/music-licensing-for-enterprise%' then 1
                  when event = '$mp_web_page_view' and url ilike '%soundstripe.com/brand-solutions%' then 1
                  when event = '$mp_web_page_view' and url ilike '%soundstripe.com/agency-solutions%' then 1
                  else 0 end) as enterprise_form_view

        ,sum(case when event = 'MKT Submitted Enterprise Contact Form' and url ilike '%enterprise%' then 1 else 0 end) as enterprise_landing_form_submissions
        ,sum(case when event = 'MKT Viewed Enterprise Contact Form' and url ilike '%enterprise%' then 1 else 0 end) as enterprise_landing_form_views

        -- enterprise_schedule_demo: original definition (unchanged from HEAD).
        -- Do NOT add Clicked Contact Sales / Enterprise Intent here — that signal
        -- is 49x higher volume and inflates the Looker mqls_schedule_demo measure.
        -- That signal is captured in dim_mql_mapping.form_events_mixpanel instead.
        ,sum(case when event = 'Clicked Element' and context = 'Enterprise Contact Form' then 1 else 0 end) as enterprise_schedule_demo

        ,count(distinct case when event = 'Signed Up' then distinct_id end) as signed_up
        ,count(distinct case when event = 'Signed In' then distinct_id end) as signed_in
        ,count(distinct case when event = 'Created Subscription' then distinct_id end) as created_subscription
        ,count(distinct case when event = 'Cancelled Subscription' then distinct_id end) as cancelled_subscription
        ,sum(case when event = 'Purchased Product' then 1 end) as purchased_product_count

        ,sum(case when event = 'Licensed Song' and path::string in ('song_checkout','license_checkout', 'library/license_checkout') then 1 end) as single_song_purchase_count
        ,sum(case when event = 'Licensed Song' and path::string in ('song_checkout','license_checkout', 'library/license_checkout') then sale_price end) as single_song_purchase_amount

        ,sum(case when event = 'Licensed Sound Effect' and path::string = 'license_checkout' then 1 end) as sfx_purchase_count
        ,sum(case when event = 'Licensed Sound Effect' and path::string = 'license_checkout' then sale_price end) as sfx_purchase_amount

        ,sum(case when event = 'Licensed Song' and path::string = 'market_checkout' then 1 end) as market_purchase_count
        ,sum(case when event = 'Licensed Song' and path::string = 'market_checkout' then sale_price end) as market_purchase_amount

        -- Music data
        ,sum(case when event = 'Searched Songs' then 1 end) as searched_songs_count
        ,sum(case when event in ('Executed AI Search','Executed Cyanite Free Text Search','Executed Agent Search') then 1 else 0 end) as ai_searched_song_count
        ,sum(case when event = 'Played Song' then 1 end) as played_songs_count
        ,sum(case when event = 'Downloaded Song' then 1 end) as downloaded_songs_count
        ,sum(case when event = 'Searched Sound Effects' then 1 end) as searched_sound_effects_count
        ,sum(case when event = 'Downloaded Sound Effect' then 1 end) as downloaded_sound_effects_count
        ,sum(case when event = 'Played Sound Effect' then 1 end) as played_sound_effects_count

    from ordered_values a
    group by 1,2
)

select
    *
from session_consolidated
{% if is_incremental() %}
    where 1=1
        and session_started_at >= (select dateadd('days', -1, coalesce(max(session_started_at), '1900-01-01')::date) from {{ this }} )
{% endif %}
