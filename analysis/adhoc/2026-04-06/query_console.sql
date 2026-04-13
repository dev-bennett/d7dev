select *
from pc_stitch_db.mixpanel.export
where event = 'Played Song'
  and content_partner_slug = 'warner_chappell_production_music'
limit 25;

--claude start below here (next query would be called "q2"...)

-- q2: WCPM distinct song plays -- monthly from Oct 2025
-- Dedup: one play per song_id per distinct_id per day
-- CFO request for Travis re: WCPM songs listened to since inception
-- Strategy: identify WCPM song_ids via Jan+ slug data, then join all plays back to Oct
WITH wcpm_songs AS (
    SELECT DISTINCT SONG_ID
    FROM pc_stitch_db.mixpanel.export
    WHERE event = 'Played Song'
      AND content_partner_slug = 'warner_chappell_production_music'
      AND SONG_ID IS NOT NULL
)
,deduped_plays AS (
    SELECT DISTINCT
        DATE_TRUNC('day', EVENT_CREATED::TIMESTAMP) AS play_date
        ,a.DISTINCT_ID
        ,a.SONG_ID
    FROM pc_stitch_db.mixpanel.export a
    INNER JOIN wcpm_songs b ON a.SONG_ID = b.SONG_ID
    WHERE a.event = 'Played Song'
      AND a.SONG_ID IS NOT NULL
      AND EVENT_CREATED::TIMESTAMP >= '2025-10-01'
)
SELECT
    DATE_TRUNC('month', play_date) AS play_month
    ,COUNT(*) AS distinct_song_plays
FROM deduped_plays
GROUP BY 1
ORDER BY 1;

select date_trunc(week, event_ts::date) as week,
       count(*)
from soundstripe_prod.core.fct_events
where 1=1
  and ((event = 'MKT Submitted Enterprise Contact Form' and url ilike '%enterprise%')
           or (event = 'Submitted Form' and context = 'Enterprise Contact Form')
           or (event = 'Clicked Element' and context = 'Enterprise Contact Form'))
  and event_ts::date > '2025-12-31'
group by 1
order by 1;

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
    1;

--claude: this is the query that answers the question........... FYI
select
    date_trunc(month, a.EVENT_TS::date) as month
    ,count(a.*) as instances
from SOUNDSTRIPE_PROD.core.dim_song_activity a
    left join PC_STITCH_DB.SOUNDSTRIPE.SONGS b
        on a.SONG_ID = b.id
    left join PC_STITCH_DB.SOUNDSTRIPE.CONTENT_PARTNERS c
        on b.CONTENT_PARTNER_ID = c.ID
where a.event_ts::date > '2025-09-30'
  and a.event_type = 'plays'
  and c.name = 'Warner Chappell Production Music'
group by all
order by 1
