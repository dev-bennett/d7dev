# Snowflake MCP Governance

- **Date:** 2026-04-24
- **Status:** Active
- **Author:** d7admin

## Context

Direct Snowflake execution is now available via `mcp__claude_ai_Snowflake__sql_exec_tool`. Previously all SQL round-trips were file-based: Claude wrote a `.sql` file, the user executed it in the IDE and exported a CSV, Claude read the CSV. MCP collapses that loop into a single tool call that returns results inline.

The capability is valuable — it removes friction from BUILD iteration, VERIFY spot-checks, and schema discovery. But the friction it removes was doing useful work: it forced thought before each round-trip, it preserved every query as a file (reproducibility), and it capped result size (what could fit in a CSV the user was willing to inspect). Unconstrained adoption would regress on cost, reproducibility, and context discipline.

The role is `EMBEDDED_ANALYST` (SELECT-only), default warehouse `DATA_SCIENCE`. The warehouse enforces read-only. We do not need to enforce that in hooks.

## Decision

Adopt MCP as a complementary execution engine, not a replacement for file-first. Governance lives in `.claude/rules/snowflake-mcp.md` and the `/sql` slash command. Key policy choices:

1. **File-first is preserved for kept queries.** Any query whose result is cited, delivered, or about to be re-run must exist in a `.sql` file with a labeled q## block. MCP is the engine; the file is the deliverable.
2. **"Twice = save" rule for ephemeral queries.** After two MCP runs of the same query, it goes to the task's `console.sql` before the third run. Prevents silent loss of iteration history.
3. **Cost discipline enforced by rule, not hook.** `LIMIT 100` default on discovery; date-scope event-grain tables; no `SELECT *` on facts. If these are violated, the rule catches it in pre-execution self-check.
4. **Context discipline.** Results > 50 rows or > 20 columns go to CSV, not the transcript. Results > 200 rows mean the query is wrong for a transcript read.
5. **No DML governance layer.** The role already rejects DML. Duplicating that in a PreToolUse hook would add friction for no safety gain.
6. **No new hooks.** The existing hook chain covers what it needs to; MCP does not need its own.
7. **No new agent.** `analyst` and `data-engineer` gain the capability via tool allow-listing; their existing directives already cover rate discipline, identity checks, and investigatory order.
8. **Seed a query KB, grow via "twice = promote".** `knowledge/query-patterns/` holds canonical reusable queries. Seed with 5 patterns proven across prior analyses; promote new patterns only after second use.

## Rationale

- **Reproducibility wins over speed.** A query executed only via MCP cannot be re-run by the user or cited in a deliverable. The file is the audit trail.
- **The warehouse is the right enforcement layer for read-only.** Claude-side hooks would duplicate what the role already does, and friction in the hook layer tends to grow over time.
- **Starting the query KB small is the only honest option.** No canonical queries exist yet in `knowledge/` — the 5 seeds are chosen because memory and analysis history prove they've been re-derived repeatedly. A speculative taxonomy would be wrong within a month.

## Consequences

**Positive:**
- Faster BUILD iteration — no manual copy/paste round-trip
- Schema discovery is now near-instant — fewer queries against the wrong columns
- Verify-pass spot-checks (Identity Checks, Type Audit cross-checks) no longer require file + manual run
- Query KB gives new analyses a leg up on the most commonly-repeated patterns

**Negative / risks to monitor:**
- Cost: if the rule is not followed, iteration is cheap and Claude may run more queries than before. Monitor DATA_SCIENCE warehouse credits weekly for the first month
- Context pollution: if large result sets are dumped inline, context fills faster. The 50-row / 20-col / 200-row limits exist to prevent this
- Reproducibility drift: if ephemeral queries don't get saved, an analysis's audit trail becomes thinner. The "twice = save" rule is the guardrail
- Query proliferation: if the KB isn't used, every analysis re-derives the same joins. The `/sql` command explicitly checks the KB first

**Revisit triggers:**
- If DATA_SCIENCE credit burn rises materially — tighten cost rules
- If a DML attempt ever succeeds (it should not) — add a PreToolUse hook
- If the query KB hits ~15 patterns — consider subdividing by domain

## Related

- Rule file: `.claude/rules/snowflake-mcp.md`
- Slash command: `.claude/commands/sql.md`
- Query KB: `knowledge/query-patterns/` (CLAUDE.md, _index.md, 5 seed `.sql` files)
- Existing guardrails referenced: `.claude/rules/guardrails.md`, `.claude/rules/sql-snowflake.md`, `.claude/rules/analysis-methodology.md`
