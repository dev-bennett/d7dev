-- Dimension: notification content catalog
-- One row per notification entry with pivoted content fields
-- Materialization: table
-- Author: d7admin
-- Date: 2026-04-02

SELECT
    cms_entry_id
    , content_type_id
    , notification_type
    , notification_type_name
    , title
    , message
    , url
    , tag
    , url IS NOT NULL AS has_url
    , published
    , published_at
    , entry_created_at
FROM {{ ref('int_notification_content_pivoted') }}
