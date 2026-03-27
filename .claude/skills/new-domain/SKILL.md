---
name: new-domain
description: Scaffold a complete analytical domain with analysis workspace, knowledge base, LookML stubs, and ETL stubs
---

# Analytical Domain Scaffolding

Create a full analytical surface for a new business domain.

## Steps

1. Accept domain name and brief description from the user
2. Create `analysis/<domain>/`:
   - `README.md` -- domain overview, key questions, stakeholders, data sources
3. Create `knowledge/domains/<domain>/`:
   - `overview.md` -- domain context, business importance, key relationships
   - `metrics.md` -- canonical metric definitions (name, formula, source, owner)
4. Scan `context/dbt/` for models related to this domain:
   - If found: list relevant models and their columns
   - Stub `lookml/views/<model>.view.lkml` for key models
5. Stub `etl/quality/<domain>-quality.sql` for domain data quality checks
6. Stage all new files (specific names, not `git add .`)
7. Report:
   - Created files
   - Identified data sources from context/
   - Gaps (missing models, undefined metrics, no Looker coverage)
   - Recommended next steps (analyses to run, views to build, KB to fill)
