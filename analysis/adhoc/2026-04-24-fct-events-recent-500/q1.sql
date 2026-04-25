-- PURPOSE:       Most recent 500 rows of fct_events for raw inspection.
-- TABLES:        soundstripe_prod.core.fct_events
-- PARAMETERS:    none
-- AUTHOR:        d7admin (via Claude Code)
-- DATE:          2026-04-24
--
-- ROUTING: this result is above the MCP transcript threshold (50 rows / 20 cols)
-- per .claude/rules/snowflake-mcp.md. Run in the Snowflake IDE and export to CSV.
-- Do NOT execute via MCP — it pollutes Claude's context with ~35K cells.
--
-- Date-scoped to last 2 days as a safety rail; fct_events lands enough that
-- 500 rows are comfortably within that window. Widen if needed.

SELECT *
FROM soundstripe_prod.core.fct_events
WHERE event_ts >= DATEADD('day', -2, CURRENT_TIMESTAMP())
ORDER BY event_ts DESC
LIMIT 500;
