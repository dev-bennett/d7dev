-- Staging: CMS field values (EAV structure)
-- Source: pc_stitch_db.soundstripe.cms_field_values
-- Author: d7admin
-- Date: 2026-04-02
-- Note: Stitch flattens the polymorphic VALUE column into typed VALUE__* columns

SELECT
    id AS field_value_id
    , entry_id
    , field_id
    , value__st AS string_value
    , value__bo AS boolean_value
    , value__it AS integer_value
    , value__de AS decimal_value
    , value__va AS variant_value
    , created_at
    , updated_at
FROM {{ source('soundstripe', 'cms_field_values') }}
