# Snowflake MCP Execution Rules

Direct Snowflake execution is available via `mcp__claude_ai_Snowflake__sql_exec_tool`. Role is `EMBEDDED_ANALYST` (SELECT only), default warehouse is `DATA_SCIENCE`, account is `QZ67029`. The warehouse enforces read-only — DML will error. Governance below is about cost, context, reproducibility, and discipline, which the warehouse does NOT enforce.

## MCP vs. file — when to use which

**MCP is appropriate for:**
- §7 BUILD iteration — drafting and testing SQL before it lands in a deliverable
- §7 VERIFY spot-checks — one-row sanity checks, Identity Checks (§5), Type Audit verification
- Schema discovery — column existence, row counts, min/max dates, distinct value counts
- Prior-investigation sanity checks during §0 context-gathering
- Smoke-testing canonical queries from `knowledge/query-patterns/`

**MCP is NOT the final artifact for:**
- Any query whose result is kept, cited, or delivered
- Any query the user or future-you would need to re-run
- Any query producing a chart, CSV, or stakeholder-facing number

Kept queries go to a `.sql` file in the task directory with a labeled q## block. The file is the deliverable. MCP is the engine.

## Reproducibility rule — "twice = save"

After running a query via MCP twice, write it to the task's `console.sql` (or named query file) with a labeled q## block before the third run. Two iterations is the ephemeral limit. This preserves the audit trail without forcing a file up front for throwaway checks.

## Calibration before query

The first time a table is touched by MCP in a session, check whether a calibration artifact exists at `knowledge/data-dictionary/calibration/<qualified_name>.md` (double-underscore separator between schema parts and table: `core__fct_events.md`, `pc_stitch_db__mixpanel__export.md`). There is no hard-coded "required" list — the rule applies to **any table**, with the response tier based on table properties discovered at first touch.

**Currency check.** An artifact is *current* if `last_calibrated` is within 30 days AND its `schema_hash` frontmatter matches the live hash from:

```sql
SELECT SHA2(LISTAGG(column_name, '|') WITHIN GROUP (ORDER BY column_name), 256)
FROM <db>.information_schema.columns
WHERE table_schema = UPPER('<schema>') AND table_name = UPPER('<table>')
```

**First-touch decision.** Do a quick lookup in `information_schema.tables` (row_count, bytes) once per first-touch table, then:

| Signal | Response |
|---|---|
| Artifact current | Proceed. Session-cache for the rest of the session |
| Artifact missing/stale AND (row_count > 1M OR fact-grain naming `fct_*` / `*events*` OR raw/external schema like `_external_*` or `pc_stitch_db.*` OR 3+ joins in the intended query) | **Block.** Invoke `/calibrate <schema.table>` (or `--refresh`) first, then proceed |
| Artifact missing/stale AND the table is small (row_count < 100K) AND dim-grain naming (`dim_*`) AND the query is a simple aggregate / single-table | **Soft-warn.** Note the gap in chat, proceed. Surface at session end as a promotion candidate |
| Fan-out red flag at any time (a single JOIN unexpectedly multiplies rows, a "rate" with no clear denominator) | **Block.** Stop and calibrate the problematic table before retrying |

**Exempt (no calibration check needed):**
- `information_schema.*` queries
- `TABLE(information_schema.query_history_by_user(...))` and similar function-table calls
- The calibration subagent's own `information_schema.columns` / `information_schema.tables` discovery queries
- Tables already verified this session (session cache)

**Why this rule exists.** Bad queries (fan-out, wrong grain, missing columns, wrong denominator) burn warehouse credits and produce wrong findings. The calibration artifact grounds the next query in dbt lineage, LookML semantics, known pitfalls, and cost profile before a single byte is scanned. The mechanism is universal, not a narrow whitelist — every table is a candidate, every artifact pays off across sessions.

## Cost discipline

Cost-risk on X-Small is dominated by **runaway patterns** (iterating 20× on a broken join, accidentally unbounded scans) rather than individual queries. A date-scoped aggregate on `fct_events` is <$0.01; a full-table scan is ~$0.03. Governance focuses on the runaway patterns.

- **Date-scope event-grain tables.** Every query against `fct_events`, `fct_sessions`, `pc_stitch_db.mixpanel.export`, `_external_statsig.exposures`, or any event-grain table needs a bounding predicate (usually date). **Exception:** cardinality / all-time questions are legitimate — flag them explicitly ("all-time on purpose because [X]")
- **`LIMIT 100` default on row-returning queries against large tables (>1M rows).** Applies to `fct_events` (1.29B rows), `fct_sessions` (42M), `pc_stitch_db.mixpanel.export`, `_external_statsig.exposures` (1.2M). Not required on dimension-sized tables (`dim_daily_kpis` at 3,752 rows, `dim_session_mapping`, etc.) — pull the whole thing when the whole thing is the answer
- **No `SELECT *` in row-returning queries against fact tables.** Enumerate columns. **Exception:** `SELECT * FROM tbl LIMIT 1` for schema-peek is allowed — often faster than `information_schema.columns` and shows a real row
- **Query runtime ceiling.** If a query exceeds ~2 minutes on X-Small, it's the wrong channel — stop, and either narrow scope or promote to a dbt model. EMBEDDED_ANALYST has USAGE on exactly one warehouse (`DATA_SCIENCE`); there is no heavier tier to escalate to

## Result-set handling (context discipline)

- Route to file + CSV when the expected result exceeds any of: **~100 rows**, **~30 columns**, or **~3,000 cells** (rows × cols). The column bound protects `SELECT *` on 70+-col fact tables; the row and cell bounds catch long distributions and accidental unfiltered pulls
- Above ~200 rows, ask whether the unit of answer is right. Time series, distinct-value lists, and full distributions are legitimate at higher row counts — those belong in a file + CSV, not the transcript. If the answer is really a top-N or summary, re-scope
- Consolidate multi-angle checks with `UNION ALL` + discriminator column (per `feedback_one_sql_file_per_query_set`)
- The MCP tool has its own output cap (~111K chars) that auto-routes overflow to a file. That is a floor, not the target — route proactively per the thresholds above rather than hitting the tool's cap

## Result completeness — never fabricate from a capped sample

**This is the highest-severity failure mode in MCP workflows.** A capped or rerouted result can look like a normal response in-context while representing an unknown fraction of the true population. Reasoning downstream from a capped sample as if it were complete produces fabricated findings that look grounded.

### Three ways a result can be partial without visibly saying so

1. **Self-imposed `LIMIT`.** A query with `LIMIT N` that returns exactly N rows is almost certainly capped. The population is ≥ N, and potentially orders of magnitude larger. Nothing in the result payload distinguishes "100 rows total" from "100 of 10M." Mental model: `LIMIT` is a HIDDEN filter that tells you nothing about the population
2. **MCP tool auto-reroute (~111K chars).** Overflow lands in `/Users/dev/.claude/projects/<session-id>/tool-results/mcp-claude_ai_Snowflake-sql_exec_tool-<ts>.txt`. The in-context response contains **only** the reroute warning — **no data**. Signature: message contains `"Output has been saved to"` + `tool-results/mcp-claude_ai_Snowflake-sql_exec_tool`. Mental model: your in-context view of the result is EMPTY, not partial
3. **Snowflake session result-size cap.** Large result sets can be truncated server-side. Rare at typical sizes but possible above ~10K–100K rows depending on payload width

### Mandatory post-execution completeness check

Before building any claim, interpretation, or downstream query on a result, run this check explicitly:

1. **Truncation-notice check.** Scan the tool response for `"Output has been saved to"` / `"tool-results"` / `"Use offset and limit parameters"`. If present, the in-context result is a reroute warning, not data. **Required action:** either read the file chunk-by-chunk until 100% is covered, or re-scope the query to an aggregate that fits inline. **Do not** proceed with interpretation on the warning text
2. **LIMIT-saturation check.** If the executed query contained `LIMIT N`, check `rows_produced` vs `N`:
   - `rows_produced < N`: result is the full population (or at least the full filtered population). Safe
   - `rows_produced == N`: **assume capped.** Do not make population claims. Follow up with an aggregate (`COUNT(*)`, `GROUP BY`, `COUNT(DISTINCT)`) before any "top", "only", "all", "no" claim
3. **Sanity-vs-first-touch check.** Compare the returned row count against the first-touch `information_schema.tables.row_count` filtered by any predicates you applied. If the result is an order of magnitude smaller than expected and no `LIMIT` / predicate explains it, stop and investigate — a silent truncation or a wrong filter is likely

### Forbidden patterns (you are making a claim you cannot support)

- Citing counts, percentages, top-N, or "only", "all", "every", "no X exists" based on a `LIMIT`-capped result
- Summarizing "what's in the data" after a reroute warning without having read the saved file
- Characterizing a distribution from a row-sample rather than an aggregate
- Claiming "X is more common than Y" when the result is any row-returning query (should be `COUNT GROUP BY` with full coverage)
- Asserting absence ("no rows for X") from a filtered query without a separate unfiltered count verifying the filter didn't silently drop the population

### Aggregate-first principle

For any question of the form "how many / how common / what are the top / which are the distinct / does X exist":
- Draft the **aggregate** query first (`COUNT`, `COUNT DISTINCT`, `GROUP BY` with `QUALIFY` / `ORDER BY` for top-N). Aggregate queries answer the population question with full coverage and small results
- Only after the aggregate is answered, consider a row-sample query as an illustration or spot-check. Cite the row-sample only as "example rows from the population of X", never as the population itself
- This is an inversion of the naive "select some rows, then summarize" pattern. The aggregate IS the summary, with no truncation risk

### When in doubt

Rerun as an aggregate. A `COUNT(*)` / `COUNT(DISTINCT x)` / `GROUP BY x ORDER BY COUNT(*) DESC` is cheap, complete, and cannot be silently truncated into a misleading answer the way a `LIMIT`-capped row-sample can.

## MCP tool constraints

- **No multi-statement calls.** `USE WAREHOUSE X; SELECT ...;` in a single MCP call errors with `000006`. One statement per call
- **No session state persistence across calls.** Session variables, temp tables, and `USE` directives don't carry between MCP invocations — each call starts clean
- **No parameter binding.** Placeholder-style (`:start_date`) does not bind automatically; substitute literal values before executing, or wrap in a CTE that defines the constant

## Query efficiency (§13) under MCP

Before executing:
1. Check `knowledge/query-patterns/_index.md` for a canonical equivalent
2. Check the current task directory's existing `.sql` files for a matching labeled query
3. If found, use/adapt the existing query. Do not re-derive

Do not run the same query twice in a session. Save the result (in chat or file) and reference it.

## Read-only assertion

EMBEDDED_ANALYST is SELECT-only. DML statements (`INSERT`, `UPDATE`, `DELETE`, `MERGE`, `CREATE`, `DROP`, `ALTER`, `TRUNCATE`) will fail at the warehouse. If one is drafted, that is a bug — stop and surface it to the user instead of executing.

## Error protocol

If a query errors:
1. Read the error text
2. Diagnose the root cause (missing column, bad join, type mismatch, permission scope)
3. Rewrite the query — do not blindly retry
4. Per guardrails, if the same approach fails twice with different symptoms, the approach is wrong — simplify fundamentally

## Promotion to query KB

When a pattern has been used across ≥2 analyses, promote it to `knowledge/query-patterns/` with a header block citing the prior analyses. Do not promote on first use — the second use is the signal.
