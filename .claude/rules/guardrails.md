---
name: Guardrails
---

# Operational Guardrails

- Never delete files without explicit user confirmation
- Never modify `.env`, credentials, or secrets files without asking
- Never install packages without stating what and why first
- When unsure about architecture, ask or plan before implementing
- Prefer editing existing files over creating new ones
- When a task touches 3+ files, summarize the plan before starting
- Always preserve existing tests; add new ones, don't remove old ones
- If a command fails, diagnose the root cause before retrying
- No blind retry loops -- investigate, then fix
- When creating new modules, use `/scaffold` to maintain consistency
- Keep all config/rule files under 50 lines where possible
- Never overwrite knowledge/ articles without confirming the update rationale
- Never modify context/ snapshots -- they are read-only reference material
- When analysis contradicts existing KB, flag the discrepancy, don't silently update
- SQL queries against production: read-only. Never generate DML without explicit request
- LookML: validate syntax before committing (check for common errors)
- Data sensitivity: never include PII or credentials in analysis outputs
- Context freshness: note when snapshots are stale (>30 days old)

## Enumeration Protocol (§6)

Never enumerate from memory. When listing, counting, or comparing items from a known finite set:
1. Write the reference set as a numbered list
2. Iterate and check each item with ✓/✗
3. Verify count matches the number of marks; recount on mismatch

"I think there are N" is never acceptable. "The checklist shows N" is required.
