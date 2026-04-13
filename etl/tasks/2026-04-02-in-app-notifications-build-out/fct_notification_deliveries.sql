-- Fact: notification deliveries
-- One row per notification delivered to a user, enriched with content and type
-- Materialization: incremental (unique_key: notification_delivery_id)
-- Author: d7admin
-- Date: 2026-04-02

{{
    config(
        materialized='incremental',
        unique_key='notification_delivery_id'
    )
}}

SELECT
    un.notification_delivery_id
    , un.user_id
    , un.cms_entry_id
    , nc.notification_type
    , nc.notification_type_name
    , nc.title
    , nc.message
    , nc.url
    , nc.tag
    , un.created_at
    , un.read_at
    , un.is_read
    , DATEDIFF('hour', un.created_at, un.read_at) AS hours_to_read
FROM {{ ref('stg_user_notifications') }} AS un
LEFT JOIN {{ ref('dim_notification_content') }} AS nc
    ON un.cms_entry_id = nc.cms_entry_id

{% if is_incremental() %}
WHERE un.created_at >= (
    SELECT DATEADD('day', -3, MAX(created_at))
    FROM {{ this }}
)
{% endif %}
