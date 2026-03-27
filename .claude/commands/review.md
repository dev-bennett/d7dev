Review uncommitted changes in this repository:

1. Run `git diff` and `git diff --cached` to see all changes.
2. For each changed file, evaluate based on file type:

   **Python (.py):**
   - Follows Python standards? Type hints, docstrings?
   - Tests for new functionality?
   - Bugs, edge cases, security issues?

   **SQL (.sql):**
   - Follows Snowflake SQL conventions?
   - Proper CTE structure, column qualification?
   - Performance concerns (full table scans, missing filters)?
   - Header comment with purpose and dependencies?
   - Rate queries: does a Type Audit (§1) pass? Is the JOIN type consistent with declared denominator?
   - Query efficiency (§13): any redundant or subset queries?

   **LookML (.lkml):**
   - Follows LookML standards?
   - Descriptions on explores and measures?
   - Proper naming conventions?
   - Data tests included?

   **Analysis (.md in analysis/):**
   - States question, methodology, limitations?
   - Includes reproducible queries?
   - Timestamped and sourced?
   - Three-pass workflow followed? (§7) -- are verification artifacts present?
   - Writing standards (§10) -- any banned phrases or reaction-framing?
   - Any STRUCTURAL findings framed as INFORMATIONAL? (§11)

   **Knowledge (.md in knowledge/):**
   - Accurate and well-sourced?
   - Cross-references consistent?
   - Claim Verification (§3) on interpretive statements?

3. Summary: what looks good, what needs attention (file:line), suggestions.

Be direct and specific. No filler praise.
