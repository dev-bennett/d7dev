-- Staging: CMS media assets and targeting lists
-- Source: pc_stitch_db.soundstripe.cms_assets
-- Author: d7admin
-- Date: 2026-04-02
-- Note: content_type renamed to mime_type to avoid collision with CMS content_type concept

SELECT
    id AS asset_id
    , title
    , description
    , file
    , content_type AS mime_type
    , published
    , created_at
    , updated_at
FROM {{ source('soundstripe', 'cms_assets') }}
