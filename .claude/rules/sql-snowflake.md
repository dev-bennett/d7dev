---
name: SQL / Snowflake Standards
paths: ["**/*.sql"]
---

# SQL & Snowflake Conventions

See context/informational/agent_directives_v3.md for full directive details.

## Rate Declarations (§1)

Before writing any query that computes a rate, ratio, or percentage:

```
RATE: [metric_name]
NUMERATOR: [exact population and condition]
DENOMINATOR: [exact population and condition]
TYPE: [numerator_label] / [denominator_label]
NOT: [the wrong denominator and why it's wrong]
```

After writing each such query, produce a Type Audit:

```
TYPE AUDIT -- [Query name]:
  Declared denominator: [from RATE block]
  JOIN chain: [all JOINs in order with type]
  Column used as denominator: [exact column reference]
  Does JOIN type enforce declared denominator? [YES/NO + reasoning]
  RESULT: [PASS or FAIL]
```

**The JOIN type IS the denominator.** A LEFT JOIN preserves the left table population. An INNER JOIN restricts to the intersection. If declared and JOIN-implied denominators disagree, the query is wrong. No query advances without a passing Type Audit.

### Step-rate nesting audit (funnel step rates)

When a query computes step rates (step N numerator / step N-1 denominator) via LAG / LEAD / FIRST_VALUE over a UNION ALL of per-step CTEs, the numerator population MUST be a subset of the denominator population. Independent CTEs do not automatically nest — the SELECT DISTINCT that builds each step's population says nothing about whether the downstream population is contained in the upstream one.

After writing any step-rate query, add to the Type Audit:

```
STEP NESTING AUDIT -- [Query name]:
  Step N-1 population definition: [summary]
  Step N population definition:   [summary]
  Is step N population a subset of step N-1? [YES/NO + reasoning]
  Enforcement: [INNER JOIN on (window,user) to prior step's CTE / predicate in WHERE / none]
  RESULT: [PASS or FAIL]
```

Enforce nesting explicitly in the CTE chain: each step CTE should INNER JOIN (or filter against) the prior step's CTE on (window, distinct_id). Two independently-defined `SELECT DISTINCT` CTEs that happen to share a key do NOT count as nested. If the ratio is bigger than the published benchmark for the same metric by >2x, the nesting is almost certainly wrong. See `feedback_population_nesting_in_step_rates.md`.

## Query Efficiency (§13)

- Check existing artifacts before writing new queries -- don't duplicate prior work
- Check `knowledge/query-patterns/_index.md` for a canonical reusable pattern before drafting from scratch
- Consolidate related checks into single queries using conditional aggregation
- Minimize round-trips: each query the user must run manually is a round-trip
- No subset queries: if Query A returns monthly breakdown and Query B returns the overall total from the same table, drop Query B
- Scope queries to the hypothesis -- don't produce broad audits unless asked

## MCP Execution

Direct Snowflake execution is available via `mcp__claude_ai_Snowflake__sql_exec_tool` and the `/sql` command. Governance in `.claude/rules/snowflake-mcp.md`.

- MCP is for BUILD iteration, VERIFY spot-checks, and schema discovery — not a substitute for file-first deliverable queries
- Any query whose result is kept, cited, or delivered must live in a `.sql` file; MCP is the engine, the file is the deliverable
- "Twice = save": after two MCP runs of the same query, write it to the task's `console.sql` with a q## label before the third run
- EMBEDDED_ANALYST is SELECT-only; a DML statement is a bug — stop and surface it rather than executing

## Formatting & Style

- UPPERCASE for SQL keywords (SELECT, FROM, WHERE, JOIN)
- snake_case for table/column names
- CTEs over subqueries; name CTEs descriptively
- Always qualify column names with table alias in JOINs
- Explicit JOIN types (INNER JOIN, LEFT JOIN) -- never implicit
- One column per line in SELECT for diffs
- Leading commas
- Indent consistently (4 spaces)
- Always include header comment: purpose, author, date, dependencies

## Snowflake-Specific

- Prefer QUALIFY over subquery for window function filtering
- Use TRY_CAST over CAST when input data may be dirty
- Use FLATTEN for semi-structured data (VARIANT, ARRAY, OBJECT)
- Date conventions: DATE_TRUNC, DATEADD, DATEDIFF -- not legacy functions
