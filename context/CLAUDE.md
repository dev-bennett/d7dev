# Context -- Ingested Reference Materials

READ-ONLY repository snapshots and reference materials.

## Structure

- `context/dbt/` -- dbt repo (git submodule: SoundstripeEngineering/dbt-transformations)
- `context/lookml/` -- LookML repo (git submodule: SoundstripeEngineering/looker)

## Rules

- NEVER modify files in context/ -- these are read-only references
- To work with these files, create copies in the appropriate workspace (lookml/, etl/)
- Pull latest dbt: `git submodule update --remote context/dbt`
- Pull latest LookML: `git submodule update --remote context/lookml`

## Cross-Repo Integration Roadmap

**Phase 1:** Air-gapped compressed snapshots, manual ingestion
**Phase 2:** Git submodule for dbt repo
**Phase 3 (current -- dbt + LookML):** Git submodules for both repos; API-based sync (dbt Cloud API, Looker API) for live state pending
**Phase 4:** CI/CD integration -- changes in this repo trigger validation in source repos
