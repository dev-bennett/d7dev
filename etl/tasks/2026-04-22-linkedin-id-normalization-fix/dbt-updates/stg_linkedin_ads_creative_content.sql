select
    split_part(id, ':', -1) as creative_id,
    campaign_id,
    name as creative_name,
    content:reference::string as content_reference_urn,
    is_test,
    intended_status as creative_status,
    is_serving,
    created_at::date as created_date,
    last_modified_at::date as last_modified_date,
    review:status::string as review_status
from {{ source("linkedin_ads", "creatives") }}
