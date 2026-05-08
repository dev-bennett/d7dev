{{
    config(
        materialized = 'table',
        on_schema_change = 'sync_all_columns',
        unique_key = 'form_object_id'
    )
}}

/*
  ================================================================================
  dim_mql_mapping.sql (v2 — tiered matching) — FIX 1: free-email exclusion
  ================================================================================
  Description:
      Maps HubSpot enterprise form submissions to Mixpanel sessions using a
      three-tier matching strategy. Starts from HubSpot as source of truth,
      then progressively widens the Mixpanel match criteria.

      Tier 1: Form event match — Mixpanel form event within ±120s on same URL,
              optionally with VID confirmation
      Tier 2: Page activity match — any Mixpanel event on the same URL within
              ±120s (page views, clicks — no form event required)
      Tier 3: Session proximity — any Mixpanel device that visited an enterprise-
              related page within ±30 min of the HubSpot submission

  Status:
      Base v2 model shipped in PR #718 (merged 2026-04-22, SHA 504f24d).
      THIS FILE adds variance-3 fix: excludes contacts in HubSpot list 4459
      (free-email domains) from the form population, mirroring HubSpot view
      19857810 filter 1. Looker MQL YTD drops from 758 → ~470.

      IMPORTANT: a separate task (etl/tasks/2026-04-07-mql-discrepancy-fix/)
      ALSO modifies this file to add four coverage fixes (pricing-page event,
      base_url normalization, tier-2 window 300s, /api URL pattern). If
      sequencing the two tasks, apply that follow-up first, then merge this
      free-email filter on top. This file does NOT include those fixes.

  Sources:
      - fct_events (Mixpanel events, post-staging)
      - fct_sessions
      - dim_session_mapping
      - hubspot_forms
      - stg_contacts_2
      - pc_stitch_db.SOUNDSTRIPE.USERS
      - hubspot_platform_data.v2_daily.list_memberships (NEW — list 4459 exclusion)
  ================================================================================
*/

{% set enterprise_url_patterns = [
    '%/music-licensing-for-enterprise%',
    '%/brand-solutions%',
    '%/agency-solutions%',
    '%/enterprise%'
] %}


-- FIX 1: Free-email contacts to exclude (HubSpot list 4459, ~1.4M members)
-- Mirrors HubSpot view 19857810 filter 1. Direct reference to HPD
-- (could be lifted to a dbt source on a future cleanup).
with free_email_contacts as
    (
        select distinct objectid as contact_id
        from hubspot_platform_data.v2_daily.list_memberships
        where listid = 4459
    )


,forms_submitted_hubspot as
    (
        select
            a.email
            ,a.SUBMISSION_TS
            ,a.PAGE_URL
            ,split_part(split_part(a.PAGE_URL, '?', 1), '//', 2) as base_url
            ,case
                when a.PAGE_URL ilike '%/music-licensing-for-enterprise%' then 'enterprise_landing'
                when a.PAGE_URL ilike '%/brand-solutions%' then 'brand_solutions'
                when a.PAGE_URL ilike '%/agency-solutions%' then 'agency_solutions'
                when a.PAGE_URL ilike '%/enterprise%' then 'enterprise_page'
                else 'other'
            end as form_page_type
            ,b.CANONICAL_VID
            ,a.FORM_OBJECT_ID
            ,a.FORM_ID
            ,a.FORM_NAME
            ,b.SOUNDSTRIPE_USER_ID
        from {{ ref("hubspot_forms") }} a
            left join {{ ref("stg_contacts_2") }} b
                on a.email = b.email
        where 1=1
            and FORM_NAME in
                (
                    'Enterprise (API Page)', 'Enterprise Multi-step Form', 'Enterprise Request Form'
                    ,'Enterprise Request Form (Hubspot)', 'Enterprise v2 - Updated'
                    ,'Meetings Link: ned-pruitt/enterprise-calendar-schedule-form'
                )
            -- FIX 1: exclude free-email domain contacts to match HubSpot view 19857810
            and b.CANONICAL_VID not in (select contact_id from free_email_contacts)
    )


-- ============================================================================
-- TIER 1: Form event match — Mixpanel form event on same URL within ±120s
-- ============================================================================

,form_events_mixpanel as
    (
        select
            a.EVENT_TS
            ,a.distinct_id
            ,a.__SDC_PRIMARY_KEY as sdc_primary_key
            ,a.url
            ,a.event
            ,a.context
            ,a.session_id as event_session_id
            ,split_part(split_part(a.url, '?', 1), '//', 2) as base_url
            ,c.SESSION_ID
            ,c.USER_ID as session_user_id
            ,d.HUBSPOT_CONTACT_VID
        from {{ ref("fct_events") }} a
            left join {{ ref("dim_session_mapping") }} b
                on a.session_id = b.session_id_events
            left join {{ ref("fct_sessions") }} c
                on b.session_id = c.session_id
            left join {{ source("soundstripe", "users") }} d
                on c.user_id::string = d.id::string
        where 1=1
            and (
                (a.event = 'Submitted Form' and lower(a.context) = 'enterprise contact form')
                or (a.event = 'MKT Submitted Enterprise Contact Form' and a.url ilike '%enterprise%')
                or (a.event = 'Clicked Element' and a.context = 'Enterprise Contact Form')
                or (a.event = 'Submitted Form' and a.url ilike '%/brand-solutions%')
                or (a.event = 'Submitted Form' and a.url ilike '%/agency-solutions%')
                or (a.event = 'CTA Form Submitted' and a.url ilike '%/enterprise%')
            )
    )

,tier1_vid_match as
    (
        select
            h.FORM_OBJECT_ID
            ,m.sdc_primary_key
            ,m.EVENT_TS as mixpanel_event_ts
            ,m.SESSION_ID as mixpanel_session_id
            ,m.session_user_id as mixpanel_user_id
            ,m.distinct_id as mixpanel_distinct_id
            ,m.event as mixpanel_event
            ,'tier1_form' as match_tier
            ,'vid_time_url' as match_reason
        from forms_submitted_hubspot h
            inner join form_events_mixpanel m
                on abs(datediff('seconds', m.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) < 120
                and h.base_url = m.base_url
                and h.CANONICAL_VID = m.HUBSPOT_CONTACT_VID
        qualify row_number() over(
            partition by h.FORM_OBJECT_ID
            order by abs(datediff('seconds', m.event_ts, h.SUBMISSION_TS))
        ) = 1
    )

,tier1_time_url_match as
    (
        select
            h.FORM_OBJECT_ID
            ,m.sdc_primary_key
            ,m.EVENT_TS as mixpanel_event_ts
            ,m.SESSION_ID as mixpanel_session_id
            ,m.session_user_id as mixpanel_user_id
            ,m.distinct_id as mixpanel_distinct_id
            ,m.event as mixpanel_event
            ,'tier1_form' as match_tier
            ,'time_url' as match_reason
        from forms_submitted_hubspot h
            inner join form_events_mixpanel m
                on abs(datediff('seconds', m.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) < 120
                and h.base_url = m.base_url
        where h.FORM_OBJECT_ID not in (select FORM_OBJECT_ID from tier1_vid_match)
        qualify row_number() over(
            partition by h.FORM_OBJECT_ID
            order by abs(datediff('seconds', m.event_ts, h.SUBMISSION_TS))
        ) = 1
    )

,tier1_combined as (
    select * from tier1_vid_match
    union all
    select * from tier1_time_url_match
)


-- ============================================================================
-- TIER 2: Page activity match — any event on same URL within ±120s
-- ============================================================================

,tier2_page_activity as
    (
        select
            h.FORM_OBJECT_ID
            ,a.__SDC_PRIMARY_KEY as sdc_primary_key
            ,a.EVENT_TS as mixpanel_event_ts
            ,c.SESSION_ID as mixpanel_session_id
            ,c.USER_ID as mixpanel_user_id
            ,a.distinct_id as mixpanel_distinct_id
            ,a.event as mixpanel_event
            ,'tier2_page' as match_tier
            ,'page_activity_time_url' as match_reason
        from forms_submitted_hubspot h
            inner join {{ ref("fct_events") }} a
                on abs(datediff('seconds', a.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) < 120
                and split_part(split_part(a.url, '?', 1), '//', 2) = h.base_url
            left join {{ ref("dim_session_mapping") }} b
                on a.session_id = b.session_id_events
            left join {{ ref("fct_sessions") }} c
                on b.session_id = c.session_id
        where h.FORM_OBJECT_ID not in (select FORM_OBJECT_ID from tier1_combined)
            and a.event in ('$mp_web_page_view', 'Viewed Page', 'Viewed Enterprise Contact Form',
                            'MKT Viewed Enterprise Contact Form', 'Clicked Element')
        qualify row_number() over(
            partition by h.FORM_OBJECT_ID
            order by abs(datediff('seconds', a.event_ts, h.SUBMISSION_TS))
        ) = 1
    )


-- ============================================================================
-- TIER 3: Session proximity — device on enterprise-related URL within ±30 min
-- ============================================================================

,tier3_session_proximity as
    (
        select
            h.FORM_OBJECT_ID
            ,a.__SDC_PRIMARY_KEY as sdc_primary_key
            ,a.EVENT_TS as mixpanel_event_ts
            ,c.SESSION_ID as mixpanel_session_id
            ,c.USER_ID as mixpanel_user_id
            ,a.distinct_id as mixpanel_distinct_id
            ,a.event as mixpanel_event
            ,'tier3_session' as match_tier
            ,'session_proximity' as match_reason
        from forms_submitted_hubspot h
            inner join {{ ref("fct_events") }} a
                on abs(datediff('minute', a.event_ts::timestamp, h.SUBMISSION_TS::timestamp)) < 30
            left join {{ ref("dim_session_mapping") }} b
                on a.session_id = b.session_id_events
            left join {{ ref("fct_sessions") }} c
                on b.session_id = c.session_id
        where h.FORM_OBJECT_ID not in (select FORM_OBJECT_ID from tier1_combined)
            and h.FORM_OBJECT_ID not in (select FORM_OBJECT_ID from tier2_page_activity)
            and (
                {% for pattern in enterprise_url_patterns %}
                a.url ilike '{{ pattern }}'{{ " or " if not loop.last }}
                {% endfor %}
            )
        qualify row_number() over(
            partition by h.FORM_OBJECT_ID
            order by abs(datediff('seconds', a.event_ts, h.SUBMISSION_TS))
        ) = 1
    )


-- ============================================================================
-- FINAL OUTPUT
-- ============================================================================

,all_matches as (
    select * from tier1_combined
    union all
    select * from tier2_page_activity
    union all
    select * from tier3_session_proximity
)

select
    h.email
    ,h.SUBMISSION_TS
    ,h.SUBMISSION_TS::date as submission_date
    ,h.form_page_type
    ,h.CANONICAL_VID as hubspot_uid
    ,h.FORM_OBJECT_ID
    ,h.FORM_ID
    ,h.FORM_NAME
    ,h.SOUNDSTRIPE_USER_ID
    ,h.PAGE_URL
    ,h.base_url
    ,m.sdc_primary_key
    ,m.mixpanel_event_ts
    ,m.mixpanel_session_id
    ,m.mixpanel_user_id
    ,m.mixpanel_distinct_id
    ,m.mixpanel_event
    ,coalesce(m.match_tier, 'unmatched') as match_tier
    ,coalesce(m.match_reason, 'no_match') as match_reason
from forms_submitted_hubspot h
    left join all_matches m
        on h.FORM_OBJECT_ID = m.FORM_OBJECT_ID
