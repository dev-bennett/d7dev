Calibrate warehouse context for "$ARGUMENTS":

Produces or refreshes per-table calibration artifacts in `knowledge/data-dictionary/calibration/` that ground MCP queries in dbt + LookML + Snowflake + analysis-history context. Works for **any** table in the warehouse — there is no pre-approved list. The first-touch rule in `.claude/rules/snowflake-mcp.md` "Calibration before query" decides at query time whether a missing artifact blocks or only soft-warns, based on table size, fact/dim naming, raw-source schema, and query shape.

## Modes

Parse `$ARGUMENTS` to determine mode:

**1. Single table — `/calibrate <schema>.<table>`**
- Delegate to `warehouse-calibrator` subagent with target = `<schema>.<table>`
- On return, summarize: artifact path, row_count, col_count, top 3 gotchas, any missing inputs

**2. Domain — `/calibrate <domain>`** (e.g. `experimentation`, `lifecycle`, `enterprise`, `search`, `tracking`, `data-health`)
- Resolve domain → candidate table list by Glob + Grep of `analysis/<domain>/**/*.sql` for table references
- Rank candidates by reference frequency; propose top 5–10 to calibrate
- Present the list to the user for confirmation before invoking the subagent in sequence (or in parallel if safe — the subagent is read-only and idempotent)

**3. Stale sweep — `/calibrate --stale`**
- List all artifacts in `knowledge/data-dictionary/calibration/` (glob `*.md` minus `_*.md`)
- For each: parse frontmatter `last_calibrated` and `schema_hash`; mark stale if age > 30 days OR hash mismatches `information_schema`
- Report: fresh count, stale (age), stale (drift), pending (in `_index.md` but no artifact)
- Ask the user which to refresh; invoke subagent for approved set

**4. Force refresh — `/calibrate --refresh <schema>.<table>`**
- Invoke subagent with `--refresh` flag regardless of current artifact freshness
- Use when schema drift is suspected or institutional notes need rebuild

## Flow

1. Classify mode per above
2. For domain/stale modes, produce the candidate list and confirm with user (unless in auto mode)
3. Invoke `warehouse-calibrator` subagent (one per table, parallel safe)
4. Collect returned summaries
5. Update `_index.md` row for each calibrated table (date + short hash). Subagent also does this; this step is a sanity check
6. Report to user: artifacts written, key gotchas surfaced, any tables that failed or need manual follow-up

## Post-calibration

- Any table newly calibrated is now "warm" for this session — `/sql` against it won't re-trigger the calibration check
- If the subagent surfaced "description missing" for any table: ask the user to supply a one-paragraph business-meaning and append to the artifact
- If the subagent surfaced new gotchas worth capturing as memory entries: propose them to the user (do not write memory without approval)

## Not this command's job

- Does not execute `SELECT` against the target table data (calibration is `information_schema`-only)
- Does not modify dbt or LookML submodules
- Does not run analyses — `/analyze` is a separate path that may invoke this command for its target tables
