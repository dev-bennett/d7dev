# Q2: Raw Mixpanel Event Audit

@../CLAUDE.md

Query raw `pc_stitch_db.mixpanel.export` for all enterprise-related events. Surface event name and context taxonomy changes over the 9-week window. Goal: identify new event names/context values the pipeline doesn't match.

## Table References

- `pc_stitch_db.mixpanel.export` -- Raw Mixpanel event stream (Stitch-ingested)
