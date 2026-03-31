Create a new analytical domain scaffold for "$ARGUMENTS":

1. Create `analysis/$ARGUMENTS/` with:
   - `README.md` -- domain overview, key questions, stakeholders

2. Create `knowledge/domains/$ARGUMENTS/` with:
   - `overview.md` -- domain context, key metrics, data sources
   - `metrics.md` -- canonical metric definitions for this domain

3. Check `context/dbt/` for models related to this domain:
   - If found: list relevant models and their columns
   - Stub `lookml/views/<model>.view.lkml` for key models

4. Stub `etl/quality/$ARGUMENTS-quality.sql` for domain data quality checks

5. Update `knowledge/data-dictionary/` with any new metric definitions

6. Stage all new files with specific file names

7. Report:
   - What was created
   - What data sources were identified from context/
   - What gaps exist (missing models, undefined metrics)
   - Suggested next steps

8. Check if this domain is part of an active roadmapping initiative:
   - Scan analysis/*/CLAUDE.md for references to $ARGUMENTS
   - If found: link the new domain scaffold to the parent initiative
   - If not: note that `/roadmap $ARGUMENTS` can be used to initiate roadmapping

This creates the full analytical surface for a business domain.
Think of it as: "I need to start understanding and measuring $ARGUMENTS."
