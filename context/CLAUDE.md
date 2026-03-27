# Context -- Ingested Reference Materials

READ-ONLY repository snapshots and reference materials.

## Structure

- `context/dbt/` -- dbt repository snapshot
- `context/lookml/` -- LookML repository snapshot
- Each subdirectory has a MANIFEST.md with ingestion metadata

## Rules

- NEVER modify files in context/ after ingestion
- To work with these files, create copies in the appropriate workspace (lookml/, etl/)
- Check MANIFEST.md for snapshot freshness before relying on content
- Re-ingest when repos have significant changes: `/ingest <repo-type>`

## Cross-Repo Integration Roadmap

**Phase 1 (current):** Air-gapped compressed snapshots, manual ingestion
**Phase 2:** Git submodules pointing to dbt and LookML repos
**Phase 3:** API-based sync (dbt Cloud API, Looker API) for live state
**Phase 4:** CI/CD integration -- changes in this repo trigger validation in source repos

The air-gap approach is intentional during development to maintain independence
and prevent accidental coupling. Each phase should be adopted deliberately.
