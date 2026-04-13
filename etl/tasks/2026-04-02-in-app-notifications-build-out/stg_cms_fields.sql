-- Staging: CMS field schema definitions
-- Source: pc_stitch_db.soundstripe.cms_fields
-- Author: d7admin
-- Date: 2026-04-02

SELECT
    id AS field_id
    , content_type_id
    , identifier AS field_identifier
    , name AS field_name
    , field_type
    , required
    , help_text
    , validations
    , position
    , appearance
    , created_at
    , updated_at
FROM {{ source('soundstripe', 'cms_fields') }}
