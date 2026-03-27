# Context -- Ingested Reference Materials

READ-ONLY repository snapshots and reference materials.

## Structure

- `context/dbt/` -- dbt repo (git submodule: SoundstripeEngineering/dbt-transformations)
- `context/lookml/` -- LookML repository snapshot (air-gapped)

## Rules

- NEVER modify files in context/ -- these are read-only references
- To work with these files, create copies in the appropriate workspace (lookml/, etl/)
- Pull latest dbt: `git submodule update --remote context/dbt`

## Cross-Repo Integration Roadmap

**Phase 1:** Air-gapped compressed snapshots, manual ingestion
**Phase 2 (current -- dbt):** Git submodule for dbt repo; LookML still air-gapped
**Phase 3:** Git submodule for LookML; API-based sync (dbt Cloud API, Looker API) for live state
**Phase 4:** CI/CD integration -- changes in this repo trigger validation in source repos
