LookML development workflow for "$ARGUMENTS":

Supported actions (first word of $ARGUMENTS):
- "view <name>" -- create/modify a view file
- "explore <name>" -- create/modify an explore
- "dashboard <name>" -- create/modify a dashboard
- "validate" -- check all .lkml files for syntax issues
- "audit" -- compare lookml/ workspace against context/lookml/ snapshot

Workflow:
1. Check context/lookml/ for existing patterns and conventions
2. Check knowledge/data-dictionary/ for field definitions
3. Check context/dbt/ for the underlying data models
4. For views: create in lookml/views/<name>.view.lkml
5. For explores: create in lookml/explores/<name>.explore.lkml
6. For dashboards: create in lookml/dashboards/<name>.dashboard.lkml
7. For models: create in lookml/models/<name>.model.lkml
8. Create/update data tests in lookml/tests/
9. Stage all created/modified files
10. Report what was created and flag any inconsistencies with existing snapshot

Always cross-reference the dbt snapshot to ensure LookML views align with source tables.
