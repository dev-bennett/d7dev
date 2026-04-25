@../CLAUDE.md

# Ad-hoc pull — most recent 500 rows of fct_events

Purpose: raw-row inspection of `fct_events` ordered by `event_ts DESC`. Intended for visual/manual inspection in a spreadsheet or Snowflake IDE, not for transcript display.

Routing: this size (500 rows × ~70 cols) is above the MCP transcript thresholds in `.claude/rules/snowflake-mcp.md`. Run `q1.sql` in the Snowflake IDE and export to CSV; do not execute via MCP.

## Status

- 2026-04-24: Query drafted, not executed. Intentional — used as a governance stress-test of the result-set thresholds. An inline MCP aggregate summary was produced instead (500 rows, 2-minute span, 28 distinct events, 66 distinct users). Retain this directory as the example of correct routing when the user asks for oversized raw pulls.
