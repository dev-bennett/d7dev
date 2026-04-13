-- Staging: CMS content entries
-- Source: pc_stitch_db.soundstripe.cms_entries
-- Author: d7admin
-- Date: 2026-04-02

SELECT
    id AS cms_entry_id
    , content_type_id
    , published
    , published_at
    , publish_at
    , created_at
    , updated_at
FROM {{ source('soundstripe', 'cms_entries') }}
