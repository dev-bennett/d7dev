-- Intermediate: Pivot CMS EAV structure into one row per notification entry
-- Joins entries → content_types (filter to notification types) → field_values → fields
-- Output: one row per cms_entry_id with title, message, url, tag as columns
-- Author: d7admin
-- Date: 2026-04-02

WITH notification_entries AS (
    SELECT
        e.cms_entry_id
        , e.content_type_id
        , ct.identifier AS notification_type
        , ct.content_type_name AS notification_type_name
        , e.published
        , e.published_at
        , e.created_at AS entry_created_at
    FROM {{ ref('stg_cms_entries') }} AS e
    INNER JOIN {{ ref('stg_cms_content_types') }} AS ct
        ON e.content_type_id = ct.content_type_id
    WHERE ct.identifier IN (
        'genericNotification'
        , 'targetedNotification'
        , 'automatedNotification'
    )
)

, field_values_with_identifier AS (
    SELECT
        fv.entry_id
        , f.field_identifier
        , fv.string_value
        , fv.boolean_value
        , fv.integer_value
    FROM {{ ref('stg_cms_field_values') }} AS fv
    INNER JOIN {{ ref('stg_cms_fields') }} AS f
        ON fv.field_id = f.field_id
    WHERE f.content_type_id IN (10, 11, 12)
)

SELECT
    ne.cms_entry_id
    , ne.content_type_id
    , ne.notification_type
    , ne.notification_type_name
    , ne.published
    , ne.published_at
    , ne.entry_created_at
    , MAX(CASE WHEN fvi.field_identifier = 'title' THEN fvi.string_value END) AS title
    , MAX(CASE WHEN fvi.field_identifier = 'message' THEN fvi.string_value END) AS message
    , MAX(CASE WHEN fvi.field_identifier = 'url' THEN fvi.string_value END) AS url
    , MAX(CASE WHEN fvi.field_identifier = 'tag' THEN fvi.string_value END) AS tag
FROM notification_entries AS ne
LEFT JOIN field_values_with_identifier AS fvi
    ON ne.cms_entry_id = fvi.entry_id
GROUP BY
    ne.cms_entry_id
    , ne.content_type_id
    , ne.notification_type
    , ne.notification_type_name
    , ne.published
    , ne.published_at
    , ne.entry_created_at
