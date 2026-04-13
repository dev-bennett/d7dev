-- Staging: user notification delivery records
-- Source: pc_stitch_db.soundstripe.user_notifications
-- Author: d7admin
-- Date: 2026-04-02

SELECT
    id AS notification_delivery_id
    , user_id
    , cms_entry_id
    , created_at
    , read_at
    , updated_at
    , read_at IS NOT NULL AS is_read
FROM {{ source('soundstripe', 'user_notifications') }}
