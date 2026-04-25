Execute SQL against Snowflake via MCP for "$ARGUMENTS":

Wraps `mcp__claude_ai_Snowflake__sql_exec_tool` in the three-pass discipline and governance from `.claude/rules/snowflake-mcp.md`. Use this for BUILD iteration, VERIFY spot-checks, and discovery — not as a substitute for file-first deliverable queries.

**PRE-EXECUTION:**
1. **Identify target tables.** Parse the question to list tables the query will touch
2. **Calibration check.** For each target table (first touch in this session only), apply the `.claude/rules/snowflake-mcp.md` "Calibration before query" rule:
   - Look up `knowledge/data-dictionary/calibration/<qualified_name>.md`
   - If current (date within 30d + schema_hash matches live) → proceed, session-cache
   - If missing/stale AND (row_count > 1M, fact-grain naming, raw/external schema, or 3+ joins in intended query) → **BLOCK.** Invoke `/calibrate <schema.table>` first, then retry
   - If missing/stale AND the table is small+dim+simple → soft-warn and proceed; flag at session end
   - Information-schema / query_history function-table calls are exempt
   - Already-verified-this-session tables are cached, no re-check
3. Check `knowledge/query-patterns/_index.md` for an existing canonical query. If one matches, adapt it rather than re-deriving
4. Check the current task directory (or most-recent `analysis/` / `etl/tasks/` working dir) for a labeled q## query covering the same ground — reuse per §13
5. If the query computes a rate: produce the §1 RATE block (RATE / NUMERATOR / DENOMINATOR / TYPE / NOT) before writing SQL
6. If the query defines a cohort driving intervention: produce the §12 ALIGNMENT CHECK before writing SQL
7. If the query computes a funnel step-rate: draft with explicit nesting (INNER JOIN step N population against step N-1 CTE) per `sql-snowflake.md` STEP NESTING AUDIT

**EXECUTION:**
8. Apply cost discipline from `.claude/rules/snowflake-mcp.md`:
   - `LIMIT 100` on row-returning queries against >1M-row tables
   - Date-scope event-grain tables
   - No `SELECT *` on fact tables (schema-peek `LIMIT 1` exempt)
9. Execute via `mcp__claude_ai_Snowflake__sql_exec_tool`
10. If the result exceeds ~100 rows, ~30 cols, or ~3000 cells: stop, write the query to a `.sql` file with a q## label, run from the file, export CSV — do not dump into the transcript

**POST-EXECUTION — Result Completeness Check (MANDATORY, before any interpretation):**

11. **Truncation-notice check.** Scan the tool response for `"Output has been saved to"` or `"tool-results/mcp-claude_ai_Snowflake-sql_exec_tool"`. If present → the in-context view is a warning, not data. Either read the saved file in full (chunked if needed) or re-scope to an aggregate. **Do not** interpret the warning as the answer
12. **LIMIT-saturation check.** If the query had `LIMIT N` and `rows_produced == N` → **assume capped.** Before any population claim, run an aggregate (`COUNT(*)`, `GROUP BY`, `COUNT(DISTINCT)`)
13. **Sanity-vs-first-touch check.** If the returned row count is unexpectedly small relative to the first-touch `information_schema.tables.row_count` + your filters, stop and investigate before proceeding
14. See `.claude/rules/snowflake-mcp.md` "Result completeness" for the full rule and forbidden patterns

**POST-EXECUTION — Capture:**

15. If the query was kept (cited, iterated on, or about to be re-run): write it to the task's `console.sql` or named query file with a labeled q## block. Reproducibility rule — after two ephemeral MCP runs, save
16. Type Audit (§1) for any kept rate query
17. Step Nesting Audit for any kept step-rate query
18. If the query surfaced a new gotcha, join pattern, or correction for a calibrated table: note it for appending to the table's calibration artifact (done at session close or via `/evolve`)
19. Stop after execution. Interpretation belongs to `/analyze` PASS 3 — do not auto-interpret unless explicitly asked

**ERROR HANDLING:**
- Read error text, diagnose root cause, rewrite — do not blindly retry
- If a DML statement errors with a permission error, that is the role doing its job; stop and surface — do not attempt a workaround

**PROMOTION:**
- If this is the second analysis using the same pattern, propose promotion to `knowledge/query-patterns/` after the task completes
