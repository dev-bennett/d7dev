with hubspot_forms as
         (SELECT a.email AS hubspot_forms_email
          FROM soundstripe_prod.hubspot.hubspot_forms a
                   LEFT JOIN soundstripe_prod.staging.stg_contacts_2 AS b ON (a.email) = (b.email)
          WHERE (((date_trunc('week', a.submission_ts)) >= ((TO_TIMESTAMP('2026-03-30'))) AND
                  (date_trunc('week', a.submission_ts)) < ((DATEADD('day', 1, TO_TIMESTAMP('2026-03-30'))))))
            AND (a."FORM_NAME") IN ('Enterprise (API Page)', 'Enterprise Multi-step Form', 'Enterprise Request Form',
                                    'Enterprise Request Form (Hubspot)', 'Enterprise v2 - Updated')
            AND (((a."SUBMISSION_TS") >= ((DATEADD('day', -175, DATE_TRUNC('week', CURRENT_DATE())))) AND
                  (a."SUBMISSION_TS") <
                  ((DATEADD('day', 182, DATEADD('day', -175, DATE_TRUNC('week', CURRENT_DATE())))))))
            AND (case when b.became_mql is not null then true else false end)
          GROUP BY 1)

select *
from hubspot_forms
;

SELECT
    (TO_CHAR(TO_DATE(date_trunc('week', fct_sessions.session_started_at) ), 'YYYY-MM-DD')) AS "fct_sessions.dynamic_session_started",
    count(distinct case when fct_sessions."ENTERPRISE_LANDING_FORM_SUBMISSIONS" > 0 then fct_sessions.distinct_id end)  AS "fct_sessions.mqls_enterprise_page",
    count(distinct case when fct_sessions."ENTERPRISE_FORM_SUBMISSIONS" > 0 then fct_sessions.distinct_id end)  AS "fct_sessions.mqls_pricing_page",
    count(distinct case when fct_sessions."ENTERPRISE_SCHEDULE_DEMO" > 0 then fct_sessions.distinct_id end)  AS "fct_sessions.mqls_schedule_demo"
FROM soundstripe_prod."CORE".FCT_SESSIONS  AS fct_sessions
WHERE ((( fct_sessions.session_started_at  ) >= ((DATEADD('day', -175, DATE_TRUNC('week', CURRENT_DATE())))) AND ( fct_sessions.session_started_at  ) < ((DATEADD('day', 182, DATEADD('day', -175, DATE_TRUNC('week', CURRENT_DATE())))))))
GROUP BY
    (TO_DATE(date_trunc('week', fct_sessions.session_started_at) ))
ORDER BY
    1
;

/*
  ================================================================================
  MQL_mapping.sql
  ================================================================================
  Description:
      Maps enterprise form submissions between HubSpot and Mixpanel to create a
      unified view of Marketing Qualified Lead (MQL) activity. Matches records
      using timestamp proximity, URL, and HubSpot contact ID.

  Sources:
      - SOUNDSTRIPE_PROD.core.FCT_EVENTS (Mixpanel events)
      - SOUNDSTRIPE_PROD.core.FCT_SESSIONS
      - SOUNDSTRIPE_PROD.core.DIM_SESSION_MAPPING
      - SOUNDSTRIPE_PROD.HUBSPOT.HUBSPOT_FORMS
      - SOUNDSTRIPE_PROD.STAGING.STG_CONTACTS_2
      - pc_stitch_db.SOUNDSTRIPE.USERS

  Logic:
      1. form_submissions_mixpanel - Extracts enterprise form events from Mixpanel
      2. forms_submitted_hubspot - Extracts enterprise form submissions from HubSpot
      3. user_match - Matches HubSpot to Mixpanel by VID, URL, and time (<40 sec)
      4. unmatched_mixpanel - Identifies Mixpanel events with no HubSpot match
      5. Final output - Combines matches with a secondary time/URL match (<20 sec)
         and deduplicates by FORM_OBJECT_ID

  Output:
      One row per HubSpot form submission with associated Mixpanel session data
      when a match is found.
  ================================================================================
  */

with form_submissions_mixpanel as
    (
        select
            a.EVENT_TS
            ,c.USER_ID
            ,d.HUBSPOT_CONTACT_VID
            ,a.__SDC_PRIMARY_KEY as sdc_primary_key
            ,a.url
            ,d.email
            ,c.SESSION_ID
            ,split_part(split_part(a.url, '?', 1), '//', 2) as base_url
            ,case when a.event = 'Submitted Form' and lower(context) = 'enterprise contact form' then 1 else 0 end as enterprise_form_submissions
            ,case when a.event = 'MKT Submitted Enterprise Contact Form' and a.url ilike '%enterprise%' then 1 else 0 end as enterprise_landing_form_submissions
            ,case when a.event = 'Clicked Element' and a.context = 'Enterprise Contact Form' then 1 else 0 end as enterprise_schedule_demo
        from SOUNDSTRIPE_DEV.core.fct_events a
              left join SOUNDSTRIPE_DEV.core.dim_session_mapping b
                  on a.session_id = b.session_id_events
              left join SOUNDSTRIPE_DEV.core.fct_sessions c
                  on b.session_id = c.session_id
              left join pc_stitch_db.soundstripe.users d
                  on c.user_id::string = d.id::string
        where 1=1
            and
                (
                    (a.event = 'Submitted Form' and lower(context) = 'enterprise contact form')
                    or (a.event = 'MKT Submitted Enterprise Contact Form' and a.url ilike '%enterprise%')
                    or (a.event = 'Clicked Element' and a.context = 'Enterprise Contact Form')
                )
    )

,forms_submitted_hubspot as
    (
        select
            a.email
            ,a.SUBMISSION_TS
            ,case when a.PAGE_URL ilike '%//www.soundstripe%' then 'enterprise_form_submission_or_demo'
                 when a.PAGE_URL ilike '%//app.soundstripe%' then 'enterprise_landing_form_submission'
                 else 'other' end as type
            ,b.CANONICAL_VID
            ,a.FORM_OBJECT_ID
            ,a.FORM_ID
            ,a.FORM_NAME
            ,b.SOUNDSTRIPE_USER_ID
            ,a.PAGE_URL
            ,split_part(split_part(a.PAGE_URL, '?', 1), '//', 2) as base_url
        from soundstripe_prod.hubspot.hubspot_forms a
            left join SOUNDSTRIPE_DEV.staging.stg_contacts_2 b
                on a.email = b.email
        where 1=1
            and FORM_NAME in
                (
                    'Enterprise (API Page)', 'Enterprise Multi-step Form', 'Enterprise Request Form'
                    ,'Enterprise Request Form (Hubspot)', 'Enterprise v2 - Updated', 'Meetings Link: ned-pruitt/enterprise-calendar-schedule-form'
                )
    )

,user_match as
(
select
    a.*
    ,b.sdc_primary_key
    ,b.EVENT_TS as mixpanel_event_ts
    ,b.SESSION_ID as mixpanel_session_id
    ,b.USER_ID as mixpanel_user_id
    ,case when b.EVENT_TS is not null then 'hubspot uid time and url match' end as match_reason
from forms_submitted_hubspot a
    left join form_submissions_mixpanel b
        on abs(datediff('seconds', b.event_ts::timestamp, a.SUBMISSION_TS::timestamp)) < 40
        and a.base_url = b.base_url
        and a.CANONICAL_VID = b.HUBSPOT_CONTACT_VID
)

,unmatched_mixpanel as
(
    select
        a.*
    from form_submissions_mixpanel a
        left join user_match b
            on a.sdc_primary_key = b.sdc_primary_key
    where b.sdc_primary_key is null
)

select
    a.email
    ,a.SUBMISSION_TS
    ,a.SUBMISSION_TS::date as submission_date
    ,a.type
    ,a.CANONICAL_VID as hubspot_uid
    ,a.FORM_OBJECT_ID
    ,a.FORM_ID
    ,a.FORM_NAME
    ,a.SOUNDSTRIPE_USER_ID
    ,a.PAGE_URL
    ,split_part(split_part(a.PAGE_URL, '?', 1), '//', 2) as base_url
    ,row_number() over(partition by b.sdc_primary_key order by abs(datediff('seconds', b.event_ts::timestamp, a.SUBMISSION_TS::timestamp))) as mixpanel_event_dedupe_order
    ,coalesce(a.sdc_primary_key, case when mixpanel_event_dedupe_order = 1 then b.sdc_primary_key end) as sdc_primary_key
    ,coalesce(a.mixpanel_event_ts, case when mixpanel_event_dedupe_order = 1 then b.EVENT_TS end) as mixpanel_event_ts
    ,coalesce(a.mixpanel_session_id, case when mixpanel_event_dedupe_order = 1 then b.session_id end) as mixpanel_session_id
    ,coalesce(a.mixpanel_user_id, case when mixpanel_event_dedupe_order = 1 then b.user_id end) as mixpanel_user_id
    ,nvl(a.match_reason, case when b.sdc_primary_key is not null and mixpanel_event_dedupe_order = 1 then 'time and url match' else 'no match' end) as match_reason
from user_match a
    left join unmatched_mixpanel b
         on abs(datediff('seconds', b.event_ts::timestamp, a.SUBMISSION_TS::timestamp)) < 10
        and a.base_url = b.base_url
where 1=1
qualify row_number() over(partition by a.FORM_OBJECT_ID order by abs(datediff('seconds', b.event_ts::timestamp, a.SUBMISSION_TS::timestamp)) asc) = 1
;