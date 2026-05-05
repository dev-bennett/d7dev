select *
from MANUAL_UPLOADS.PUBLIC.ARTIST_MONIKERS
where artist_name in(select artist_name
from MANUAL_UPLOADS.PUBLIC.ARTIST_MONIKERS
group by all
having count(1) > 1)

;

select count(distinct artist_name) as artists,
       count(artist_name),
       count(distinct parent_artist) as parent_artists,
       count(parent_artist)
from MANUAL_UPLOADS.PUBLIC.ARTIST_MONIKERS
group by all
order by 1,2;

select count(distinct id)
from pc_stitch_db.soundstripe.artists