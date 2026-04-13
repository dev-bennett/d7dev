Add notification and CMS source tables to soundstripe schema

Register user_notifications, cms_content_types, cms_entries,
cms_field_values, cms_fields, and cms_assets as dbt sources.
These tables power the in-app notification system and are needed
for the upcoming notification reporting pipeline (phase 1 of
lifecycle marketing).
