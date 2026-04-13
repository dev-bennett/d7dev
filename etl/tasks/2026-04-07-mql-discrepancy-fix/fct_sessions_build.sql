-- =============================================================================
-- fct_sessions_build.sql — Enterprise Form Event Matching (lines 66-74)
-- =============================================================================
-- CHANGE: Expand enterprise_form_submissions to capture:
--   1. Submitted Form / Enterprise Contact Form (existing — /music-licensing-for-enterprise)
--   2. Submitted Form with empty context on /brand-solutions and /agency-solutions
--   3. CTA Form Submitted on /enterprise path
--
-- CHANGE: Expand enterprise_form_view to include /brand-solutions and /agency-solutions
--
-- CONTEXT: The Enterprise v2 - Updated HubSpot form was deployed to new marketing
-- landing pages where the Mixpanel event fires with empty context instead of
-- 'Enterprise Contact Form'. CTA Form Submitted is a new event name on /enterprise.
-- See analysis/data-health/2026-04-07-mql-discrepancy/findings.md
-- =============================================================================

        -- Conversion data (REPLACE lines 67-74 in fct_sessions_build.sql)

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

        ,sum(case when event = 'Clicked Element' and context = 'Enterprise Contact Form' then 1 else 0 end) as enterprise_schedule_demo
