Analytical project health dashboard for d7dev:

1. **Git status**: `git status` -- uncommitted changes, branch
2. **Context freshness**:
   - Check context/dbt/MANIFEST.md and context/lookml/MANIFEST.md for ingestion dates
   - Flag if snapshots are >30 days old or missing
3. **Analysis inventory**:
   - Count analyses by domain in analysis/
   - List recent analyses (last 5 by date)
4. **LookML workspace**:
   - Count views, explores, dashboards in lookml/
   - Note any files without corresponding data tests
5. **ETL workspace**:
   - Count transforms and quality checks in etl/
   - List uncovered tables (in context but no quality checks)
6. **Knowledge base**:
   - Count articles by section in knowledge/
   - Flag any articles not updated in >90 days
7. **Scripts & tests**:
   - Count Python files in scripts/ and test files in tests/
   - Flag scripts without corresponding tests
8. **Domain coverage matrix**:
   - For each domain in analysis/: does it have KB articles? LookML views? ETL coverage?
9. **Active initiatives**:
   - Scan analysis/*/CLAUDE.md for roadmapping status fields
   - List each initiative with: domain, current roadmap step (1-7), owner, last updated
   - Flag stalled initiatives (no update in >30 days)

Present as a concise dashboard. Flag gaps and recommend priorities.
