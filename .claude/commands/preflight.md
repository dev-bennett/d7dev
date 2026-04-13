Run a pre-flight check before starting a new task. If "$ARGUMENTS" specifies the task type and target, tailor the checks. Otherwise, run the general checklist.

**PURPOSE:** Prevent the most common friction patterns by verifying environment, target state, and existing patterns BEFORE writing any code or files.

**STEP 1 -- TASK CLASSIFICATION**

Classify the work into one or more workspace types:
- **ETL:** dbt models, staging, transforms, source definitions
- **LookML:** Views, explores, dashboards, model edits
- **Analysis:** Exploratory queries, reports, signal detection
- **Knowledge:** KB articles, data dictionary, decisions, runbooks

**STEP 2 -- ENVIRONMENT CHECK**

For ETL tasks:
- Confirm target database: `soundstripe_dev` (dbt Cloud dev) or `soundstripe_prod` (production)
- If production changes needed: confirm TRANSFORMER role access and GRANT plan
- Read the existing source yml to confirm format and ordering before proposing changes
- `ls` the target marts/ and transformations/ directories to confirm placement

For LookML tasks:
- Read an existing file in the target repo directory to confirm file extension and conventions
- Confirm promotion path: prepare in `lookml/tasks/`, user implements in Looker IDE
- Check `context/lookml/Models/General.model.lkml` for existing explores and include patterns
- Verify `view_name:` vs `from:` convention for explores

For Analysis tasks:
- Confirm which schemas/tables will be queried
- Check for existing work on the same topic in `etl/tasks/` and `analysis/`

**STEP 3 -- EXISTING PATTERN CHECK**

- Check `etl/tasks/` for prior work on the same models or sources
- Check `knowledge/` for existing domain knowledge, decisions, or data dictionary entries
- Check `initiatives/` for an active initiative this work falls under
- Read the relevant rule files for the workspace types involved

**STEP 4 -- DIRECTORY SETUP**

- Create task directories with CLAUDE.md BEFORE writing any task files
- Create subdirectories for each query set (never reuse labels in the same directory)
- If work spans 2+ workspaces, create or update an initiative file in `initiatives/`

**STEP 5 -- REPORT**

Report the pre-flight findings:
- Task classification and workspace(s) involved
- Environment confirmed (target DB, role, promotion path)
- Existing patterns found (prior work, KB articles, active initiatives)
- Directories created
- Any blockers or questions that need user input before proceeding

Keep the report concise. Flag anything that needs the user's decision.
