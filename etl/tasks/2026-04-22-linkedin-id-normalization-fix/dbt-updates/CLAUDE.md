# dbt updates — drop-in replacements

@../CLAUDE.md

Complete file replacements ready to promote into `SoundstripeEngineering/dbt-transformations`.

Filenames match the dbt model filenames so the mapping is one-to-one:

| file here | destination in dbt-transformations repo |
|---|---|
| `stg_fct_creatives.sql` | `models/staging/linkedin_ads/stg_fct_creatives.sql` (overwrite) |
| `stg_linkedin_ads_creative_content.sql` | `models/staging/linkedin_ads/stg_linkedin_ads_creative_content.sql` (overwrite) |
| `schema.yml` | `models/staging/linkedin_ads/schema.yml` (new file) |

See `../runbook.md` for the step-by-step implementation.
