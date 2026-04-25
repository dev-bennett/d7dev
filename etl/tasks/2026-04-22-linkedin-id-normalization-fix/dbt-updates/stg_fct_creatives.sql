select
    campaign_id, -- foreign key
    created_at::date as created_date,
    split_part(id, ':', -1) as creative_id, -- primary key (numeric tail of the LinkedIn URN)
    intended_status as creative_status,
    is_serving,
    serving_hold_reasons
from {{ source("linkedin_ads", "creatives") }}
