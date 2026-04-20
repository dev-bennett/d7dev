Run validations across the project:

1. **Python tests** (if $ARGUMENTS is empty or contains "python"):
   - Run: `pytest $ARGUMENTS -v --tb=short 2>&1`
   - Analyze failures, suggest fixes

2. **SQL validation** (if $ARGUMENTS is empty or contains "sql"):
   - Check all .sql files in etl/ for:
     - Syntax issues (common patterns)
     - Missing header comments
     - Hardcoded table names (should use ref/source patterns)

3. **LookML validation** (if $ARGUMENTS is empty or contains "lookml"):
   - Check all .lkml files in lookml/ for:
     - Required fields (type on dimensions, descriptions on explores/measures)
     - Naming convention adherence
     - Orphaned views (no explore references them)

4. **Knowledge base integrity** (if $ARGUMENTS is empty or contains "kb"):
   - Check for broken cross-references in knowledge/
   - Check that metric definitions in data-dictionary/ are consistent with LookML

5. **Permission audit** (if $ARGUMENTS is empty or contains "audit"):
   - Run: `python scripts/audit_command_permissions.py --check`
   - Enforces the zero-prompt contract: every tool call any `.claude/commands/*.md` instructs must be covered by the effective allowlist (union of project, project-local, and user settings). Non-zero exit means a new command reference was added without a matching allowlist entry.
   - On failure, report file and pattern; suggest the entry to add to `.claude/settings.json`.

Report results in sections. For each issue, provide file path and specific fix.
