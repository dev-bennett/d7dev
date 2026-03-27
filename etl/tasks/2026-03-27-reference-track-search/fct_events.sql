
{{
    config(
        materialized='incremental',
        on_schema_change='sync_all_columns',
        unique_key = '__sdc_primary_key'
    )
}}


with time_limited_events as
    (
        select
            distinct_id
            ,__sdc_primary_key
            ,event
            ,song_id
            ,SOUND_EFFECT_ID
            ,sale_price
            ,purchase_price
            ,current_subscription_id
            ,current_account_id
            ,user_id as original_mp_user_id
            ,url as original_mp_url
            ,plan_id as original_mp_plan_id
            ,plan_name as original_mp_plan_name
            ,referrer as original_mp_referrer
            ,coalesce(user_id, mp_reserved_user_id, mp_reserved_distinct_id_before_identity) as user_id
            ,time::timestamp as event_ts
            ,coalesce(current_url, mp_reserved_current_url, url) as url    -- Coalesce URLs from www and app environments
            ,parse_url(coalesce(current_url, mp_reserved_current_url, url)) as parsed_url
            ,parsed_url:path::string as path
            ,parsed_url:host::string as host
            ,parsed_url:parameters as parameters
            -- Store UTM parameters with _session suffix because Mixpanel also tracks UTM parameters
            ,parameters:utm_medium::string as utm_medium
            ,parameters:utm_source::string as utm_source
            ,parameters:utm_campaign::string as utm_campaign
            ,parameters:utm_content::string as utm_content
            ,parameters:utm_term::string as utm_term
            ,mp_reserved_referring_domain as referring_domain
            ,mp_reserved_referrer as referrer
            ,mp_reserved_device as device
            ,mp_reserved_browser as browser
            ,mp_reserved_city as city
            ,mp_reserved_region as region
            ,mp_country_code as country
            ,coalesce(current_plan_id, plan_id) as plan_id    -- Coalesce plan values from www and app environments
            ,coalesce(current_plan_name, plan_name) as plan_name
            ,mobile_app as is_mobile_app
            ,context
            ,event_host
            ,lower(trim(query)) as search_term
            ,tags as filter_term
            ,playlists
            ,song_file_format
            ,playlist_id
            ,playlist_name
            ,project_name
            ,songs_similar_to
            ,play_duration
            ,artist_name
            ,artist_id
            ,song_title
            ,song_version_id
            ,play_completed
            ,datediff(minutes, lag(time) over (partition by distinct_id order by time, _SDC_RECEIVED_AT asc), time) as inactivity_minutes
            ,case when inactivity_minutes is null or inactivity_minutes >= 30 then 1 else 0 end as is_new_session
            ,statsig_stable_id
            -- Reference Track Search properties (added 2026-03-27)
            -- Schema verified via etl/tasks/2026-03-27-reference-track-search/schema_check/
            -- NOT INCLUDED: results (Song ID + Score array) -- not in Stitch export, investigate separately
            -- NOT INCLUDED: content_partners -- column exists but unpopulated as of 2026-03-27
            ,spotify_track_id                                   -- Executed Reference Track Search, Reference Track Search Error
            ,spotify_id                                         -- Sign Up Modal Opened, Closed, Executed Agent Search
            ,TRY_CAST(results_count AS INTEGER) AS ref_track_results_count  -- Executed Reference Track Search
            ,track_title_display AS ref_track_title             -- Executed Reference Track Search, Reference Track Search Error
            ,error_message AS ref_track_error_message           -- Reference Track Search Error
            ,"TRIGGER" AS ref_track_signup_trigger              -- Sign Up Modal Opened (quoted: Snowflake reserved word)
            ,search_type                                        -- Executed Agent Search (new optional property)
        from {{source("mixpanel", "export")}}
        -- Remove API events
        where
            event not in ('Called API Endpoint', '$identify', '$create_alias','$mp_session_record', '$mp_page_leave', '$mp_dead_click')
            and nvl(parse_url(coalesce(current_url, mp_reserved_current_url, url)):path::string, 'null check') != 'new/stylesheets'
            and nvl(parse_url(coalesce(current_url, mp_reserved_current_url, url)):host::string, 'null check') not in ('app-web.soundstripe.com',
                                                         '104.131.162.177',
                                                         '167.99.56.159',
                                                         '64.225.61.248',
                                                         '164.90.133.75',
                                                         '64.225.52.87',
                                                         '167.99.122.73',
                                                         '167.99.53.168',
                                                         '174.138.95.128',
                                                         'nxcpower.com',
                                                         'www.nxcpower.com')

            --this filter removes external (non-site user) events from event stream
            and lower(nvl(event_source, 'null check')) not in ('twitch','adobe express')

            /* this filter removes project-overtake related events for the period of time where distinct_ids
               were not properly reconciled between react and overtake resulting in duplicate/anonymous sessions */
            and not (time::date < '2025-07-27' and lower(nvl(event_source, 'null check')) = 'web')

----------------- THIS IS THE DRIVER OF INCREMENTALITY LOGIC IN THE CODE -----------------
    {% if is_incremental() %}
        {% if var('backfill_from', none) is not none %}
            and event_ts >= '{{ var("backfill_from") }}'::timestamp
        {% else %}
            and event_ts >= (select dateadd('days', -1, coalesce(max(event_ts), '1900-01-01')::date) from {{ this }} )
        {% endif %}
    {% endif %}

        qualify row_number() over(partition by DISTINCT_ID, time, event, coalesce(song_id::string, SOUND_EFFECT_ID::string, 'no_song_id') order by _SDC_RECEIVED_AT asc) = 1
    )

,session_boundaries as
    (
        select
            distinct_id
            ,event_ts as session_start_ts
            ,nvl(dateadd('seconds', -1, lead(event_ts) over(partition by distinct_id order by event_ts asc)), '2099-12-31')::timestamp as next_session_ts
            ,md5(distinct_id::string ||'|'|| session_start_ts::string) as session_id
        from time_limited_events
        where 1=1
            and is_new_session = 1
            and distinct_id is not null
    )

select
    b.session_id
    ,a.* exclude (sale_price, purchase_price)
    ,case when a.path in ('pricing', 'checkout', 'signup', 'sign_in') then a.path
            when a.host = 'www.soundstripe.com' then
            case when (a.path = '' or a.path in ('homepage-music-search', 'home-v4')) then 'homepage'
                    when lower(a.path) like 'blogs%' then 'blog'
                    when lower(a.path) like 'enterprise%' then 'enterprise'
                    else 'mkt other' end
            when a.host = 'app.soundstripe.com' then
            case when a.path = '' then 'dashboard'
                    when lower(a.path) like any ('sfx%', 'sound-effects%') then 'sfx'
                    when lower(a.path) like 'video%' then 'video'
                    when lower(a.path) like any ('music%', 'royalty-free-music%') then 'music'
                    when lower(a.path) like 'songs%' then 'songs'
                    when lower(a.path) like 'artists%' then 'artists'
                    when lower(a.path) like 'playlist%' then 'playlists'
                    when lower(a.path) like 'account%' then 'account'
                    when lower(a.path) like 'my_media/favorites%' then 'favorites'
                    else 'app other' end else null end as page_category
    ,CASE
                    /*
                    CHANNEL ATTRIBUTION LOGIC
                    The following case statement determines the marketing channel for each event
                    using a hierarchical approach in this order:
                    1. Paid Channels (Search > Social > Content)
                    2. Owned Channels (Email > Affiliate)
                    3. Organic Channels (Search > Social > Referral)

                    Key principles:
                    - UTM parameters take precedence over referring domains
                    - Paid channel attribution requires explicit UTM parameters
                    - Social channels are identified by both platform domains and UTM patterns
                    - Organic channels are determined by referrer patterns when paid parameters absent
                    */

                    -- Paid Search Attribution
                    -- Requires: CPC/PPC medium AND recognized search engine source
                    -- Excludes: Display campaigns (checked via campaign name)
                    WHEN LOWER(utm_medium) IN ('cpc', 'ppc') AND
                            (coalesce(lower(referring_domain), LOWER(utm_source)) LIKE ANY (
                                '%google%', '%googleads%', '%adwords%',
                                '%bing%', '%bingads%',
                                '%yahoo%', '%yahoosearch%',
                                '%duckduckgo%', 'ddg%',
                                '%yandex%', '%yandexdirect%'
                            ) OR lower(utm_source) like any ('%goo%','%bin%','b','g')) AND NOT
                            lower(nvl(utm_campaign, 'null check')) like any ('[dis]%', '%display%') AND
                            lower(nvl(c.advertising_channel_type, 'null check')) != 'video'
                    THEN 'Paid Search'

                    -- Paid Social Attribution
                    -- Matches on: Explicit paid_social/paid_video medium OR
                    -- Social platform source with campaign parameter
                    WHEN lower(utm_medium) = 'paid_video' or
                         lower(c.advertising_channel_type) = 'video' or
                         LOWER(utm_medium) = 'paid_social' OR
                            (LOWER(utm_medium) = 'social' AND utm_campaign IS NOT NULL) OR
                            (LOWER(utm_source) LIKE ANY (
                                '%facebook%', '%fb.%', '%fb.com%', 'fb', 'fbads',
                                '%instagram%', '%ig.%', 'insta', 'ig',
                                '%linkedin%', '%lnkd.in%', 'li', 'liadv',
                                '%twitter%', '%x.com%', 't.co', 'tw',
                                '%tiktok%', 'tt', 'ttads',
                                '%youtube%', 'yt', 'ytads',
                                '%reddit%', 'rd', 'rdads'
                            ) and utm_campaign is not null
                              and lower(nvl(utm_campaign, 'null check')) != 'comments')
                    THEN 'Paid Social'

                    -- Paid Content Attribution
                    -- Includes: Sponsored content, podcasts, content partnerships
                    -- Also captures display campaigns from paid search
                    WHEN LOWER(utm_medium) IN ('paid_content', 'podcast', 'sponsored') OR
                            LOWER(referring_domain) LIKE ANY (
                                '%anchor.fm%', '%spotify%/episode%',
                                '%substack%', '%medium.com%', '%nofilmschool%'
                            ) OR
                            (lower(utm_medium) in ('ppc','cpc') AND
                             lower(utm_campaign) like any ('[dis]%', '%display%'))
                    THEN 'Paid Content'

                    -- Email Channel Attribution
                    -- Captures: Newsletter campaigns and email client referrals
                    -- Matches both UTM parameters and email platform domains
                    WHEN LOWER(utm_medium) like '%email%' OR
                            LOWER(referring_domain) LIKE ANY (
                                '%mail.google%', '%outlook.live%', '%yahoo.mail%',
                                '%mailchimp%', '%klaviyo%', '%sendgrid%'
                            ) OR
                            LOWER(utm_content) IN ('ema', 'email-1')
                    THEN 'Email'

                    -- Affiliate Channel Attribution
                    -- Identifies traffic from partnership and referral programs
                    -- Checks: FPR parameter, affiliate networks, explicit UTM tagging
                    WHEN is_null_value(parameters:fpr) IS NOT NULL OR
                            LOWER(referring_domain) LIKE ANY (
                                '%shareasale%', '%commission-junction%', '%cj.com%',
                                '%impact.com%', '%partnerstack%'
                            ) OR
                            LOWER(utm_medium) = 'affiliate' OR
                            LOWER(utm_source) = 'growsumo'
                    THEN 'Affiliate'

                    -- Organic Search Attribution
                    -- Captures search engine traffic without paid parameters
                    -- Identifies both major and emerging search engines
                    WHEN LOWER(coalesce(referrer,referring_domain)) LIKE ANY (
                                '%google%', '%bing%', '%yahoo%',
                                '%duckduckgo%', '%ddg.gg%',
                                '%yandex%', '%baidu%',
                                '%ecosia%', '%perplexity%',
                                '%qwant%', '%brave%'
                            )
                    THEN 'Organic Search'

                    -- Organic Social Attribution
                    -- Captures social traffic without paid parameters
                    -- Checks both direct referrals and organic social UTMs
                    -- Excludes internal domain referrals
                    WHEN ((LOWER(coalesce(referrer,referring_domain)) LIKE ANY (
                            '%facebook%', 'fb.com',
                            '%instagram%', '%linkedin%', '%lnkd.in%',
                            '%twitter%', 'x.com', 't.co', 'li',
                            '%tiktok%', '%youtube%', 'yt', 'fb',
                            '%reddit%', '%telegram%', 't.me','%twitch%'
                    ) AND NOT lower(nvl(utm_medium, 'null check')) LIKE ANY ('ppc','cpc')) OR
                    LOWER(utm_source) LIKE ANY (
                                '%facebook%', '%fb.%', '%fb.com%', 'fb', 'fbads',
                                '%instagram%', '%ig.%', 'insta', 'ig',
                                '%linkedin%', '%lnkd.in%', 'li', 'liadv',
                                '%twitter%', '%x.com%', 't.co', 'tw',
                                '%tiktok%', 'tt', 'ttads',
                                '%youtube%', 'yt', 'ytads',
                                '%reddit%', 'rd', 'rdads','%twitch%'
                            ) OR
                    LOWER(utm_medium) IN ('organic-social', 'organic social') OR
                    LOWER(utm_medium) = 'utm_medium_session=bio%20link') AND
                    lower(referring_domain) != 'www.soundstripe.com'
                    THEN 'Organic Social'

                    -- Fallback Paid Search Attribution
                    -- Captures remaining CPC/PPC traffic not caught in primary paid search logic
                    WHEN lower(utm_medium) in ('cpc','ppc')
                    THEN 'Paid Search'

                    -- Referral Attribution
                    -- Implements manual capture of 'app.hubspot.com' referrer traffic for landing pages missing utm params
                    -- As well as possible Soundstripe/other blog sources
                    WHEN lower(referrer) like any ('https://app.hubspot.com/','%blog%','%adobe%')
                    THEN 'Referral'
                    -- Captures all remaining external referrals
                    -- Excludes internal tools and payment systems
                    WHEN coalesce(referring_domain, referrer) IS NOT NULL AND
                            NOT LOWER(nvl(coalesce(referring_domain, referrer), 'null check')) LIKE ANY (
                                '%soundstripe%',
                                '%hubspot%',
                                '%asana%',
                                '%paypal%')
                    THEN 'Referral'
                    END AS channel
    ,try_to_number(a.sale_price::string) / 100 as sale_price
    ,try_to_number(a.purchase_price::string) / 100 as purchase_price
    ,case when nvl(a.plan_id, 'None') != 'None' and a.event != 'Created Subscription' then 1 else 0 end as is_existing_subscriber
    ,row_number() over (partition by b.session_id order by a.event_ts) as event_counter
from time_limited_events a
    left join session_boundaries b
        on a.distinct_id = b.distinct_id
        and a.event_ts between b.session_start_ts and b.next_session_ts
    left join {{source("google_ads", "campaigns")}} c
        on a.utm_campaign = c.id::string
where 1=1
