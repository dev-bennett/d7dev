## Summary

- Register 6 new source tables in `src_soundstripe.yml` for the in-app notification and CMS system: `user_notifications`, `cms_content_types`, `cms_entries`, `cms_field_values`, `cms_fields`, `cms_assets`
- Tables inserted in alphabetical order consistent with existing file convention
- No model changes -- source definitions only

## Context

Phase 1 of building a notification reporting pipeline to support lifecycle marketing. These source declarations unblock staging models (`stg_user_notifications`, `stg_cms_*`) that will follow in a subsequent PR.

The CMS tables store notification content (titles, messages, URLs, targeting CSVs) in an EAV structure. `user_notifications` tracks delivery and read status per user. Together they enable reporting on what notifications were sent, to whom, and engagement rates.

## Test Plan

- [ ] `dbt compile` succeeds with no errors
- [ ] `dbt ls --select source:soundstripe.user_notifications source:soundstripe.cms_content_types source:soundstripe.cms_entries source:soundstripe.cms_field_values source:soundstripe.cms_fields source:soundstripe.cms_assets` returns all 6 sources
- [ ] No changes to existing models or sources
