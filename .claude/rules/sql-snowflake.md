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

## Query Efficiency (§13)

- Check existing artifacts before writing new queries -- don't duplicate prior work
- Consolidate related checks into single queries using conditional aggregation
- Minimize round-trips: each query the user must run manually is a round-trip
- No subset queries: if Query A returns monthly breakdown and Query B returns the overall total from the same table, drop Query B
- Scope queries to the hypothesis -- don't produce broad audits unless asked

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
