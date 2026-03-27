Build or update a business model for "$ARGUMENTS":

Follow the Three-Pass Workflow (§7) from context/informational/agent_directives_v3.md.

**PASS 1 -- BUILD:**
1. Check knowledge/ for existing models and context on this domain
2. Check context/dbt/ for relevant data models
3. Produce Deliverable Contract (§2) for the model output
4. Produce Rate Declarations (§1) for any rate metrics used as inputs
5. Use analysis/_templates/business-model.md as the output template
6. Structure the model:
   - Define the business question / hypothesis
   - Identify input metrics and their data sources
   - Build the quantitative framework (formulas, relationships)
   - Document all assumptions with sensitivity ranges
   - Show scenario analysis (base, optimistic, pessimistic)

**PASS 2 -- VERIFY:**
7. Type Audit (§1) any supporting queries
8. Algebraic Identity Check (§5) -- verify model arithmetic
9. Enumeration Check (§6) -- all assumptions listed, all scenarios computed
10. Contract Checklist (§2) -- verify all postconditions met

**PASS 3 -- INTERPRET:**
11. Null Hypothesis Check (§4) for patterns driving model inputs
12. Claim Verification (§3) for all interpretive statements
13. Adversarial Questions (§8) before delivery
14. Intervention Classification (§11) for material findings
15. Writing Scrub (§10) on stakeholder-facing prose
16. Provide actionable recommendations

**FINALIZE:**
17. Save to analysis/<domain>/<YYYY-MM-DD>-model-<slug>.md
18. If this model defines new metrics, draft data-dictionary entries
19. Stage output files

Ground all assumptions in data. Cite sources. Show your work.
