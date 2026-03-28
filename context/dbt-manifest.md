# dbt Context Manifest

- **Source repo:** SoundstripeEngineering/dbt-transformations
- **Ingestion method:** Git submodule (live tracking `main`)
- **Last updated:** 2026-03-28
- **Staleness threshold:** 7 days
- **Update command:** `git submodule update --remote context/dbt`

## Key Models

| Model | Layer | Description |
|-------|-------|-------------|
| fct_events | marts/core | Core event fact table (Mixpanel source) |
| fct_sessions_build | marts/core | Session-level aggregation |
| fct_sessions_product_engagement_build | marts/core | Product engagement metrics per session |
| dim_mixpanel_feature_events | marts/core | Feature event dimension |

## Notes

- Development branch: `develop_dab`
- Submodule configured in `.gitmodules`
- See context/CLAUDE.md for cross-repo integration roadmap
