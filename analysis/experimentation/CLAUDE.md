# Experimentation

@../CLAUDE.md

Analysis and planning for A/B testing, SEO experiments, and controlled experiments across the Soundstripe platform.

## Platform

- **Statsig** — primary experimentation platform, proxied via `ab.soundstripe.com` (Fastly)
- **Integration:** `statsig_stable_id` in Mixpanel events → fct_events → `_external_statsig` schema in Snowflake
- **Existing model:** `statsig_clickstream_events_etl_output` in `_external_statsig` schema

## Conventions

- Each initiative lives in a date-stamped folder: `YYYY-MM-DD-<slug>/`
- Technical assessments precede experiment launch — document what instrumentation is needed before building
- New Statsig-facing dbt models go in `context/dbt/models/marts/_external_statsig/`
- Experiment results and post-hoc analyses live in the initiative folder alongside the setup artifacts
