Manage a roadmapping initiative for "$ARGUMENTS":

Follow the 7-step roadmapping process from .claude/rules/roadmapping-methodology.md.

**ASSESS CURRENT STATE:**
1. Check if `analysis/$ARGUMENTS/` exists
   - If yes: read its CLAUDE.md to determine which roadmapping step the initiative is on
   - If no: this is a new initiative -- start at Step 1
2. Check `knowledge/runbooks/roadmapping-process.md` for process reference

**STEP 1 -- SCOPE (if not yet done):**
3. Create `analysis/$ARGUMENTS/` if it doesn't exist
4. Create `analysis/$ARGUMENTS/CLAUDE.md` with initiative status
5. Use `analysis/_templates/initiative-scope.md` to draft the scope document
6. Identify stakeholders and document them
7. Report: scope summary, stakeholders, recommended next step (schedule brainstorm)

**STEP 3 -- CONSOLIDATE (after brainstorm):**
8. Review brainstorm artifacts (FigJam PNGs, notes) in `analysis/$ARGUMENTS/`
9. Use `analysis/_templates/brainstorm-consolidation.md` to group and define ideas
10. Identify cross-cutting themes
11. Report: grouped ideas, themes, gaps, recommended swimlane framing

**STEP 4 -- SWIMLANES & EPICS:**
12. Propose swimlane structure based on domain context
13. Map grouped ideas into swimlanes as named epics
14. Write scope statements for each epic
15. Identify dependencies

**STEP 5 -- PRIORITIZE (after stakeholder session):**
16. Document priority assignments (P1-P5) for each epic
17. Capture rationale for P1/P2 assignments
18. Flag any epics needing further scoping

**STEP 6 -- ROADMAP ARTIFACT:**
19. Use `analysis/_templates/roadmap-artifact.md` to create the canonical roadmap
20. Generate a visual flowchart (Graphviz or Mermaid)
21. Organize by priority within swimlanes

**STEP 7 -- EPIC PROJECT PLANS:**
22. For each P1/P2 epic, use `analysis/_templates/epic-project-plan.md`
23. Break down into tasks, deliverables, milestones
24. Create corresponding Asana tasks if requested

**FINALIZE:**
25. Update `analysis/$ARGUMENTS/CLAUDE.md` with current step and status
26. Stage all new/modified files
27. Report: what was done, current step, recommended next action
