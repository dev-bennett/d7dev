--q1
select session_started_at::date as date,
       count(distinct case when last_channel_non_direct = 'Direct' then session_id end) as direct_sessions,
       count(distinct case when nvl(last_channel_non_direct,'null check') != 'Direct' then session_id end) as other_sessions
from soundstripe_prod.core.fct_sessions
where session_started_at::date > '2026-03-31'
group by 1
order by 1;

--q2
select session_started_at::date as date,
       count(distinct session_id) as sessions
from soundstripe_prod.core.fct_sessions
where session_started_at::date > '2026-03-31'
group by 1
order by 1;

--q3: direct sessions by landing_page_host -- baseline (4/1-4/13) vs spike days
--    tests domain-consolidation fallout and source-shift hypotheses
select nvl(landing_page_host, '(null)') as landing_page_host,
       count(distinct case when session_started_at::date between '2026-04-01' and '2026-04-13'
                           then session_id end) as baseline_1_13,
       count(distinct case when session_started_at::date = '2026-04-14' then session_id end) as d0414,
       count(distinct case when session_started_at::date = '2026-04-15' then session_id end) as d0415,
       count(distinct case when session_started_at::date = '2026-04-16' then session_id end) as d0416
from soundstripe_prod.core.fct_sessions
where session_started_at::date between '2026-04-01' and '2026-04-16'
  and last_channel_non_direct = 'Direct'
group by 1
order by d0416 desc nulls last
limit 25;

--q4: per-date quality+device mix for Direct sessions
--    tests bot hypothesis (bounce, duration, first-session share, device concentration)
select session_started_at::date as date,
       count(distinct session_id) as direct_sessions,
       sum(bounced_sessions) as bounced,
       round(sum(bounced_sessions) * 100.0 / nullif(count(distinct session_id), 0), 1) as bounce_pct,
       round(avg(session_duration_seconds), 0) as avg_duration_sec,
       count(distinct case when session_counter = 1 then session_id end) as first_ever_sessions,
       round(count(distinct case when session_counter = 1 then session_id end) * 100.0
             / nullif(count(distinct session_id), 0), 1) as first_ever_pct,
       count(distinct case when is_mobile_app = true then session_id end) as mobile_app,
       count(distinct case when device = 'Desktop' then session_id end) as desktop,
       count(distinct case when device = 'Mobile' then session_id end) as mobile_web,
       count(distinct case when device = 'Tablet' then session_id end) as tablet,
       count(distinct case when nvl(device, '(null)') not in ('Desktop','Mobile','Tablet') then session_id end) as device_other_or_null
from soundstripe_prod.core.fct_sessions
where session_started_at::date > '2026-03-31'
  and last_channel_non_direct = 'Direct'
group by 1
order by 1;

--q5: direct sessions by country -- baseline vs spike days, top 20 by 4/16
--    tests geographic concentration (bot farm / regional event)
select nvl(country, '(null)') as country,
       count(distinct case when session_started_at::date between '2026-04-01' and '2026-04-13'
                           then session_id end) as baseline_1_13,
       count(distinct case when session_started_at::date = '2026-04-14' then session_id end) as d0414,
       count(distinct case when session_started_at::date = '2026-04-15' then session_id end) as d0415,
       count(distinct case when session_started_at::date = '2026-04-16' then session_id end) as d0416
from soundstripe_prod.core.fct_sessions
where session_started_at::date between '2026-04-01' and '2026-04-16'
  and last_channel_non_direct = 'Direct'
group by 1
order by d0416 desc nulls last
limit 20;

--q6: top direct-session landing paths during spike window (4/14-4/16)
--    identifies which URLs are absorbing the incremental direct traffic
select nvl(landing_page_host, '(null)') as landing_page_host,
       nvl(landing_page_path, '(null)') as landing_page_path,
       count(distinct session_id) as direct_sessions_spike,
       sum(bounced_sessions) as bounced,
       round(sum(bounced_sessions) * 100.0 / nullif(count(distinct session_id), 0), 1) as bounce_pct,
       round(avg(session_duration_seconds), 0) as avg_dur_sec
from soundstripe_prod.core.fct_sessions
where session_started_at::date between '2026-04-14' and '2026-04-16'
  and last_channel_non_direct = 'Direct'
group by 1, 2
order by direct_sessions_spike desc
limit 30;

--q7: direct sessions by browser -- baseline vs spike
--    tests bot hypothesis from UA angle (one UA dominating)
select nvl(browser, '(null)') as browser,
       count(distinct case when session_started_at::date between '2026-04-01' and '2026-04-13'
                           then session_id end) as baseline_1_13,
       count(distinct case when session_started_at::date = '2026-04-14' then session_id end) as d0414,
       count(distinct case when session_started_at::date = '2026-04-15' then session_id end) as d0415,
       count(distinct case when session_started_at::date = '2026-04-16' then session_id end) as d0416
from soundstripe_prod.core.fct_sessions
where session_started_at::date between '2026-04-01' and '2026-04-16'
  and last_channel_non_direct = 'Direct'
group by 1
order by d0416 desc nulls last
limit 20;

--q8: landing-event composition for spike-window Direct sessions, joined via dim_session_mapping
--    fct_events.session_id (raw md5) -> dim_session_mapping.session_id_events
--    dim_session_mapping.session_id -> fct_sessions.session_id (primary/consolidated)
select
    nvl(a.referrer, '(null)')                          as referrer,
    nvl(a.referring_domain, '(null)')                  as referring_domain,
    nvl(a.event_host, '(null)')                        as event_host,
    nvl(a.event, '(null)')                             as event,
    nvl(a.utm_source, '(null)')                        as utm_source,
    nvl(a.utm_medium, '(null)')                        as utm_medium,
    nvl(a.utm_campaign, '(null)')                      as utm_campaign,
    nvl(a.country, '(null)')                           as country,
    count(distinct c.session_id)                       as direct_sessions,
    count(distinct a.distinct_id)                      as distinct_ids,
    count(distinct a.statsig_stable_id)                as statsig_stable_ids
from soundstripe_prod.core.fct_events a
    inner join soundstripe_prod.core.dim_session_mapping b
        on a.session_id = b.session_id_events
    inner join soundstripe_prod.core.fct_sessions c
        on b.session_id = c.session_id
where c.session_started_at::date between '2026-04-14' and '2026-04-16'
  and c.last_channel_non_direct = 'Direct'
  and a.event_counter = 1
group by 1, 2, 3, 4, 5, 6, 7, 8
order by direct_sessions desc
limit 50;

--q9: 50 raw landing events (SG/VN/CN) on 4/16 for Direct sessions, joined via dim_session_mapping
--    first-principles inspection; parameters blob exposes query-string signatures
select
    c.session_id                                       as primary_session_id,
    a.session_id                                       as raw_session_id,
    a.event_ts,
    a.event,
    a.url,
    a.referrer,
    a.referring_domain,
    a.event_host,
    a.parameters::string                               as parameters,
    a.country,
    a.region,
    a.city,
    a.browser,
    a.is_mobile_app,
    a.statsig_stable_id,
    a.distinct_id
from soundstripe_prod.core.fct_events a
    inner join soundstripe_prod.core.dim_session_mapping b
        on a.session_id = b.session_id_events
    inner join soundstripe_prod.core.fct_sessions c
        on b.session_id = c.session_id
where c.session_started_at::date = '2026-04-16'
  and c.last_channel_non_direct = 'Direct'
  and a.event_counter = 1
  and c.country in ('SG', 'VN', 'CN')
order by a.event_ts desc
limit 50;

--q10: schema check on pc_stitch_db.mixpanel.export -- inventory of IP, UA, SDK-lib,
--     OS, and screen columns that fct_events drops during transformation
select column_name, data_type
from pc_stitch_db.information_schema.columns
where table_schema = 'MIXPANEL'
  and table_name = 'EXPORT'
  and (
        column_name ilike '%ip%'
     or column_name ilike '%user_agent%'
     or column_name ilike '%_lib%'
     or column_name ilike '%screen%'
     or column_name ilike 'mp_reserved_os%'
     or column_name ilike '%initial_referrer%'
     or column_name ilike '%language%'
     or column_name ilike '%timezone%'
  )
order by column_name;

--q11: raw-source fingerprint -- mp_lib + OS + UA pattern for the spike population
--     (APAC countries, $mp_web_page_view, no referrer). Goal: identify the scraper
--     signature for a CDN/security block. mp_reserved_initial_referrer null-share
--     measures the "fresh cookie per hit" behavior.
select
    coalesce(mp_lib, '(null)')                                 as mp_lib,
    coalesce(mp_reserved_lib_version, '(null)')                as lib_version,
    coalesce(mp_reserved_os, '(null)')                         as os,
    coalesce(mp_reserved_user_agent, '(null)')                 as mp_user_agent,
    coalesce(user_agent, '(null)')                             as ss_user_agent,
    mp_country_code                                            as country,
    count(*)                                                   as events,
    count(distinct distinct_id)                                as distinct_ids,
    count(distinct user_ip)                                    as unique_ips,
    sum(case when mp_reserved_initial_referrer is null then 1 else 0 end) as null_initial_referrer_events
from pc_stitch_db.mixpanel.export
where time::date between '2026-04-14' and '2026-04-16'
  and mp_country_code in ('CN', 'SG', 'VN', 'HK', 'JP')
  and event = '$mp_web_page_view'
  and mp_reserved_referring_domain is null
  and mp_reserved_referrer is null
group by 1, 2, 3, 4, 5, 6
order by events desc
limit 50;

--q12: raw-source IP concentration -- how many unique IPs drive the spike, and
--     how lopsided is the per-IP event volume? High events/IP = small datacenter
--     fleet; low events/IP = residential-proxy botnet.
select
    user_ip,
    mp_country_code                                            as country,
    count(*)                                                   as events,
    count(distinct distinct_id)                                as distinct_ids,
    count(distinct time::date)                                 as active_days,
    min(time::timestamp)                                       as first_event_ts,
    max(time::timestamp)                                       as last_event_ts
from pc_stitch_db.mixpanel.export
where time::date between '2026-04-14' and '2026-04-16'
  and mp_country_code in ('CN', 'SG', 'VN', 'HK', 'JP')
  and event = '$mp_web_page_view'
  and mp_reserved_referring_domain is null
  and mp_reserved_referrer is null
group by 1, 2
order by events desc
limit 50;

--q13: control comparison -- is user_ip / user_agent null because of project-level
--     PII scrubbing (would be null for all events) or because spike events are
--     server-side API calls that omit these fields? Compare populate rates across
--     three populations in the same 3-day window.
with populations as (
    select
        case when mp_country_code in ('CN','SG','VN','HK','JP')
                  and mp_reserved_referring_domain is null
                  and mp_reserved_referrer is null
                  and event = '$mp_web_page_view'
             then 'spike_apac_direct'
             when mp_country_code = 'US'
                  and mp_reserved_referring_domain is not null
             then 'us_referred_control'
             when mp_country_code = 'US'
                  and mp_reserved_referring_domain is null
                  and mp_reserved_referrer is null
                  and event = '$mp_web_page_view'
             then 'us_direct_control'
             else 'other' end                             as population,
        user_ip,
        user_agent,
        mp_reserved_user_agent,
        mp_reserved_initial_referrer,
        distinct_id
    from pc_stitch_db.mixpanel.export
    where time::date between '2026-04-14' and '2026-04-16'
)
select
    population,
    count(*)                                            as events,
    count(distinct distinct_id)                         as distinct_ids,
    count(user_ip)                                      as non_null_user_ip,
    count(user_agent)                                   as non_null_user_agent,
    count(mp_reserved_user_agent)                       as non_null_mp_user_agent,
    count(mp_reserved_initial_referrer)                 as non_null_initial_referrer,
    count(distinct mp_reserved_initial_referrer)        as distinct_initial_referrer_vals
from populations
where population != 'other'
group by 1
order by events desc;

--q14: enumeration test -- scrapers visit each asset URL ~1 time (coverage), real
--     users repeat pages (browsing). Events-per-unique-path ratio should be near 1
--     for the scraper population and materially higher for both US control populations.
with populations as (
    select
        case when mp_country_code in ('CN','SG','VN','HK','JP')
                  and mp_reserved_referring_domain is null
                  and mp_reserved_referrer is null
                  and event = '$mp_web_page_view'
             then 'spike_apac_direct'
             when mp_country_code = 'US'
                  and mp_reserved_referring_domain is not null
             then 'us_referred_control'
             when mp_country_code = 'US'
                  and mp_reserved_referring_domain is null
                  and mp_reserved_referrer is null
                  and event = '$mp_web_page_view'
             then 'us_direct_control'
             else 'other' end                        as population,
        parse_url(coalesce(current_url, mp_reserved_current_url, url)):path::string as path
    from pc_stitch_db.mixpanel.export
    where time::date between '2026-04-14' and '2026-04-16'
)
select
    population,
    case when path ilike 'library/sound-effects/%' then 'sound-effects/{id}'
         when path ilike 'library/songs/%'         then 'songs/{id}'
         else 'other'                              end     as asset_type,
    count(*)                                               as events,
    count(distinct path)                                   as unique_paths,
    round(count(*) * 1.0 / nullif(count(distinct path), 0), 2) as events_per_path
from populations
where population != 'other'
  and (path ilike 'library/sound-effects/%' or path ilike 'library/songs/%')
group by 1, 2
order by 1, 2;

--q15: per-section distribution + coverage substantiation across populations.
--     (a) DISTRIBUTION: share of each population's events by library section (less
--         granular than path, what a dashboard consumer would see).
--     (b) SUBSTANTIATION: unique_paths per section and top-10 path concentration
--         -- real users cluster on popular assets (high top10 share); systematic
--         coverage spreads across many paths (low top10 share, high unique_paths).
with populations as (
    select
        case when mp_country_code in ('CN','SG','VN','HK','JP')
                  and mp_reserved_referring_domain is null
                  and mp_reserved_referrer is null
                  and event = '$mp_web_page_view'
             then 'spike_apac_direct'
             when mp_country_code = 'US'
                  and mp_reserved_referring_domain is not null
             then 'us_referred_control'
             when mp_country_code = 'US'
                  and mp_reserved_referring_domain is null
                  and mp_reserved_referrer is null
                  and event = '$mp_web_page_view'
             then 'us_direct_control'
             else 'other' end                                          as population,
        parse_url(coalesce(current_url, mp_reserved_current_url, url)):path::string as path
    from pc_stitch_db.mixpanel.export
    where time::date between '2026-04-14' and '2026-04-16'
),
sectioned as (
    select
        population,
        path,
        case when path ilike 'library/sound-effects/%'      then 'library/sound-effects/{id}'
             when path ilike 'library/songs/%'              then 'library/songs/{id}'
             when path ilike 'library/royalty-free-music%'  then 'library/royalty-free-music*'
             when path ilike 'library/video%'               then 'library/video*'
             when path ilike 'library/playlists%'           then 'library/playlists*'
             when path ilike 'library/sound-effects'        then 'library/sound-effects (root)'
             when path in ('library', 'library/')           then 'library (root)'
             when path ilike 'library/pricing%'             then 'library/pricing*'
             when path ilike 'library/sign_in%'
               or path ilike 'library/signup%'              then 'library/auth*'
             when path ilike 'library/%'                    then 'library/other'
             when path ilike 'blogs%'                       then 'blogs*'
             when path = '' or path is null                 then '(homepage)'
             else 'non-library' end                                    as section
    from populations
    where population != 'other'
),
path_events as (
    select population, section, path, count(*) as events
    from sectioned
    group by 1, 2, 3
),
with_rank as (
    select
        population, section, path, events,
        row_number() over(partition by population, section order by events desc) as rn
    from path_events
),
section_totals as (
    select
        population,
        section,
        count(*)                                as unique_paths,
        sum(events)                             as section_events,
        sum(iff(rn <= 10, events, 0))           as top10_events
    from with_rank
    group by 1, 2
),
pop_totals as (
    select population, sum(section_events) as pop_events
    from section_totals
    group by 1
)
select
    s.population,
    s.section,
    s.section_events                                                     as events,
    round(s.section_events * 100.0 / nullif(p.pop_events, 0), 1)         as pct_of_pop,
    s.unique_paths,
    round(s.section_events * 1.0 / nullif(s.unique_paths, 0), 2)         as events_per_path,
    s.top10_events,
    round(s.top10_events * 100.0 / nullif(s.section_events, 0), 1)       as top10_share_pct
from section_totals s
    inner join pop_totals p on s.population = p.population
order by s.population, events desc;