# Claude MCP Result Completeness — PSA for Non-Technical Users

- **Date:** 2026-04-24
- **Owner:** d7admin
- **Audience:** All Claude Enterprise users across departments (sales, marketing, support, ops, finance, etc.)
- **Purpose:** Paste-ready Slack / email / onboarding content for the known failure mode where Claude summarizes partial database results as if they were complete

## Context

When Claude queries a database on a user's behalf via MCP, the response can be silently capped (by the tool's overflow limit, by a `LIMIT` clause Claude added, or by server-side truncation). Claude has produced confident downstream answers from capped results — and has been observed to double down when asked to verify. See `.claude/rules/snowflake-mcp.md` "Result completeness" and `feedback_no_fabrication_from_capped_results.md`.

End users can't inspect the SQL and don't need to. They need three pattern-based tells and a clear "flag it" action.

## Paste-ready PSA (Slack / email / channel post)

```
PSA — one failure mode with Claude + database queries

Most data pulls through Claude work fine. One narrow failure mode is worth knowing: databases cap big responses at a safety limit, and Claude can summarize what it didn't see as if it were complete. This specifically shows up in counts, top-N lists, and "no results found" answers.

Three tells worth a pause:

- A count on a suspiciously round number (exactly 100, exactly 1000) — often a cap, not a count.
- A top-N list missing an item you know should be there.
- "No results found" for something you're sure exists.

When any of these show up on something that matters — a report, a deck, a decision — flag it to the data team before using it. Quick lookups and status checks don't need this scrutiny.
```

## Design notes (for the person distributing the PSA)

- Do NOT tell users to "ask Claude to double-check" — this has been observed to fail; Claude can gaslight users into re-accepting the original wrong answer
- Do NOT frame this as "be paranoid about the tool" — most usage is fine and the tool is valuable; the PSA should preserve enthusiasm while flagging one specific smell
- The three tells are designed to be pattern-matchable by non-SQL users without doing verification work; the action is "flag to data team," not "verify yourself"
- "Quick lookups and status checks" carve-out is important — it keeps the bar for the flag narrow to high-stakes asks (reports, decks, decisions)

## Delivery channels

- Slack: `#general`, department-specific channels, new-hire onboarding
- Email: monthly enterprise-tooling newsletter
- Intranet / handbook: "Working with Claude" section

## When to update this PSA

- If a new truncation mode surfaces (e.g., Snowflake updates its result cap, MCP tool changes its output limit)
- If the "three tells" miss a failure pattern seen in practice
- If the "ask Claude to verify" behavior changes (e.g., Anthropic ships a harness-level guard that makes self-verification reliable)

## Related

- `.claude/rules/snowflake-mcp.md` — Result completeness section (technical governance for MCP queries)
- `/Users/dev/.claude/projects/-Users-dev-PycharmProjects-d7dev/memory/feedback_no_fabrication_from_capped_results.md` — the rule's rationale
- `.claude/commands/sql.md` — post-execution completeness check (steps 11–14)
