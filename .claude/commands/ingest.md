Ingest a repo snapshot into context/:

Usage: /ingest <repo-type>
Where <repo-type> is: dbt, lookml, or a custom name.

1. Ask user for the path to the compressed archive (.tar.gz, .zip)
2. Determine target directory: context/<repo-type>/
3. If target already has content:
   - Note the existing snapshot date (from context/<repo-type>/MANIFEST.md)
   - Confirm replacement with user
4. Clear the target directory (preserve .gitkeep)
5. Extract archive into context/<repo-type>/
6. Create/update context/<repo-type>/MANIFEST.md with:
   - Ingestion date and time
   - Source archive name
   - File count and directory structure summary
   - Key files identified (for dbt: dbt_project.yml, models/; for lookml: *.model.lkml)
7. Run a quick inventory:
   - For dbt: count models by layer, list sources, list tests
   - For lookml: count views, explores, dashboards, models
8. Stage all new files in context/<repo-type>/
9. Report summary

IMPORTANT: context/ contents are READ-ONLY reference material after ingestion.
Do not modify ingested files -- create working copies in the appropriate workspace.
