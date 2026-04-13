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
- No blind retry loops -- investigate, then fix. If the same approach fails twice with different symptoms, the approach is wrong -- simplify fundamentally
- When creating new modules, use `/scaffold` to maintain consistency
- Keep all config/rule files under 50 lines where possible
- Never overwrite knowledge/ articles without confirming the update rationale
- Never modify context/ snapshots -- they are read-only reference material
- When analysis contradicts existing KB, flag the discrepancy, don't silently update
- Never fabricate database names, schema paths, table names, column names, dbt variables, model parameters, or any other identifiers. If a reference isn't confirmed from the actual source file, existing queries, or schema checks, read the file first. This includes dbt run commands -- read the model's config block and incremental logic before proposing --vars, --full-refresh, or backfill instructions.
- SQL queries against production: read-only. Never generate DML without explicit request
- LookML: validate syntax before committing (check for common errors)
- Data sensitivity: never include PII or credentials in analysis outputs
- Context freshness: note when snapshots are stale (>30 days old)

## File-First Output

- Everything the user will execute, reference, or paste goes in a FILE, not chat
- SQL queries: write to `.sql` files in the appropriate task directory
- Shell commands: write to files or provide as single-line instructions, not multi-step chat blocks
- Complete file replacements: provide the full file, not fragments the user must manually insert
- Each distinct query set gets its own subdirectory with CLAUDE.md -- never reuse query labels across sets in the same directory

## Verify Target Before Writing

- Before writing any dbt model: `ls` the target marts/transformations directory to confirm placement
- Before writing any LookML: read an existing file in the target directory to confirm extension and conventions
- Before writing any source definition: read the existing source yml to confirm format and ordering
- Before proposing any file path: verify the directory exists and check what's already there
- When debugging environment issues: ask about the target database, role, and deployment path FIRST
- Before reporting a chart/visualization script as working: run it, read the output image, and verify the rendered result matches intent (text readable, no clipping, no overlaps, data accurate)

## Directory CLAUDE.md Chain (Mandatory)

Every new subdirectory MUST include a `CLAUDE.md` file. No exceptions. This applies to task directories, nested subdirectories (schema_check/, validation/, etc.), and any other directory created during any operation.

At minimum, each `CLAUDE.md` must:
1. State the directory's purpose
2. Reference the parent directory's `CLAUDE.md` with a relative path directive (`@../CLAUDE.md`)
3. Include any directory-specific conventions (table reference patterns, file naming, etc.)

The `@../CLAUDE.md` chain must be walkable from any leaf directory up to the project root `CLAUDE.md`. This ensures that rules, conventions, and context are always reachable regardless of where work is being performed.

**Before writing ANY file in a new directory:** create the `CLAUDE.md` first.

## Enumeration Protocol (§6)

Never enumerate from memory. When listing, counting, or comparing items from a known finite set:
1. Write the reference set as a numbered list
2. Iterate and check each item with ✓/✗
3. Verify count matches the number of marks; recount on mismatch

"I think there are N" is never acceptable. "The checklist shows N" is required.
