-- Staging: CMS content type definitions
-- Source: pc_stitch_db.soundstripe.cms_content_types
-- Author: d7admin
-- Date: 2026-04-02

SELECT
    id AS content_type_id
    , identifier
    , name AS content_type_name
    , description
    , created_at
    , updated_at
FROM {{ source('soundstripe', 'cms_content_types') }}
