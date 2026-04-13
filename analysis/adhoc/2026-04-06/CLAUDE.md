# 2026-04-06 Ad Hoc: WCPM Song Plays

CFO request: how many WCPM songs are being listened to on the platform since inception, monthly + aggregate from Oct.

## Data Source
- `pc_stitch_db.mixpanel.export` -- Played Song events filtered by `content_partner_slug = 'warner_chappell_production_music'`

## Deduplication
- Raw events fire per waveform click, overrepresenting plays
- Deduplicate at: distinct `song_id` per `distinct_id` per date

@../CLAUDE.md
