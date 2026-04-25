Run a deep-dive analysis on "$ARGUMENTS":

Follow the Three-Pass Workflow (§7) from context/informational/agent_directives_v3.md.

**PASS 1 -- BUILD:**
1. Check knowledge/domains/ and knowledge/data-dictionary/ for existing context
2. Check context/dbt/ for relevant models and their lineage
3. Check context/lookml/ for existing reporting on this topic
4. **Calibration.** For each target table the analysis will touch, check `knowledge/data-dictionary/calibration/<qualified_name>.md`. Follow the first-touch rule in `.claude/rules/snowflake-mcp.md` — block-and-calibrate for fact-grain / large / raw-source / join-heavy queries; soft-warn for small dim tables. Read each artifact's "Known pitfalls" section before writing queries — that's where prior gotchas live
5. Produce Rate Declarations (§1) for any rate/ratio metrics before writing SQL
6. Produce Definition-Use Case Alignment (§12) for any segments or cohorts
7. Draft analysis using analysis/_templates/ as structure:
   - State the question clearly
   - Identify data sources and relevant tables
   - Write SQL queries (Snowflake dialect) to investigate
8. Initialize checkpoint: create/update analysis/<domain>/checkpoint.md (§9)

**PASS 2 -- VERIFY:**
8. Type Audit (§1) every query that computes a rate
9. Algebraic Identity Check (§5) if 3+ related metrics computed
10. Spot-check: manually compute one rate from one data point

**PASS 3 -- INTERPRET:**
11. Document findings with supporting data
12. Null Hypothesis Check (§4) for cohort shifts, seasonal patterns, decay
13. Claim Verification (§3) for every interpretive statement
14. Adversarial Questions (§8) before finalizing
15. Intervention Classification (§11) for each material finding
16. Writing Scrub (§10) -- Sentence Audit on all stakeholder-facing prose
17. State limitations and assumptions
18. Recommend next steps

**FINALIZE:**
19. Save output to analysis/<domain>/<YYYY-MM-DD>-<slug>.md
20. Update checkpoint.md
21. If new metric definitions emerge, flag for /kb-update
22. Stage the analysis file
