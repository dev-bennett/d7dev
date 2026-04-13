Perform a comprehensive retrospective and continuous improvement cycle for the d7dev workspace. This command can be invoked as `/evolve`, `/evolve <scope>`, or by saying "initiate evolution."

If "$ARGUMENTS" specifies a scope, focus there. Otherwise, review the full session and repo state.

**PHASE 1 -- DETECT**

Review the conversation from start to finish. Extract:

1. **Friction points:** Where the user corrected you, where you wasted round-trips, where you made wrong assumptions, where you had to redo work.
2. **Wins:** Approaches that worked well, outputs the user accepted without revision, patterns worth reinforcing.
3. **Patterns:** Recurring themes across friction points (e.g., "failed to gather context before acting" appearing in multiple places is a pattern, not just individual mistakes).

For each friction point, classify:
- **PROCESS:** The workflow or sequencing was wrong (e.g., wrote queries before reading the model)
- **JUDGMENT:** The hypothesis or framing was wrong (e.g., proposed new directory when existing one fits)
- **EXECUTION:** The mechanics were wrong (e.g., wrong file extension, wrong schema reference)
- **COMMUNICATION:** The output format or tone missed the mark

**PHASE 2 -- AUDIT**

Scan the current repo state for structural health. Every item below MUST be addressed explicitly -- do not skip items or defer them. Produce a checklist with PASS/FAIL/ACTION for each.

1. **CLAUDE.md chain integrity:** Verify every directory has a CLAUDE.md with `@../CLAUDE.md` reference, walkable to root.
2. **Stale documentation:** Check if root CLAUDE.md, directory maps, and cross-repo references match actual state.
3. **Memory freshness:** Read MEMORY.md index. Check for memories that may be outdated based on session work. Remove or update stale entries. Check for duplicates.
4. **Rule coverage:** Read EVERY file in `.claude/rules/`. For each rule file:
   - Did the session involve work governed by this rule?
   - If yes, was the rule followed? If not, does it need strengthening or was it an execution failure?
   - Does the rule's `paths` glob cover files created/modified this session?
   - Are there new patterns from this session that no existing rule covers?
5. **Command coverage:** Read EVERY file in `.claude/commands/`. For each command:
   - Should it have been invoked during this session? Was it?
   - Did any reusable workflow pattern emerge that warrants a new command or an update to an existing one?
6. **Knowledge base gaps:** `ls` knowledge/ directories. Check if session work produced institutional knowledge (methodology, workflows, decision rationale) not yet captured. A runbook-worthy workflow used 3+ times should be documented.
7. **Agent coverage:** Read `.claude/agents/` list. Were any agent types relevant to this session's work but not used? Should a new agent type be created?
8. **Orphaned files:** Check for temp files, lock files, or files outside established directory structure.
9. **Task directory hygiene:** Verify task directories have README.md/CLAUDE.md with current status. Verify completed work is marked as such.
10. **Open design problems:** Identify features or requirements that were abandoned, deferred, or stripped out due to execution failure. These are NOT resolved -- they are open items that need to be logged honestly. Removing a broken feature is not fixing it.

**PHASE 2 GATE -- Before proceeding to Phase 3, produce the checklist:**

```
AUDIT CHECKLIST:
[ ] 1. CLAUDE.md chain -- [PASS/FAIL: details]
[ ] 2. Stale docs -- [PASS/FAIL: details]
[ ] 3. Memory freshness -- [PASS/FAIL: details]
[ ] 4. Rule coverage -- [PASS/FAIL: details, list each rule file checked]
[ ] 5. Command coverage -- [PASS/FAIL: details, list each command checked]
[ ] 6. Knowledge gaps -- [PASS/FAIL: details]
[ ] 7. Agent coverage -- [PASS/FAIL: details]
[ ] 8. Orphaned files -- [PASS/FAIL: details]
[ ] 9. Task hygiene -- [PASS/FAIL: details]
[ ] 10. Open design problems -- [list or NONE]
```

Do not proceed to Phase 3 until every item has a status.

**PHASE 3 -- DESIGN**

For each detected issue, determine the integration point:

| Issue Type | Integration Point |
|---|---|
| Behavioral correction the user gave | Feedback memory |
| Workflow improvement for a task type | Rule file (.claude/rules/) or command (.claude/commands/) |
| Repo convention that emerged | CLAUDE.md (root or subdirectory) |
| Project context learned | Project memory |
| External system reference learned | Reference memory |
| Structural gap in repo | New directory/file with CLAUDE.md chain |
| Stale documentation | Update in place |
| Open design problem | Project memory flagged as OPEN, with context on what was attempted and why it failed |

Design each update concisely. Rules and commands must be actionable, not aspirational. Memory entries follow the standard frontmatter format with Why/How to apply structure.

**PHASE 4 -- INTEGRATE**

Apply all updates:

1. **Memory:** Write or update memory files. Check for duplicates -- update rather than create new.
2. **Rules:** Edit existing rule files to add guidance. Only create new files if guidance doesn't fit existing.
3. **Commands:** Update existing commands or create new ones for reusable patterns.
4. **CLAUDE.md:** Update root and subdirectory files to match current state.
5. **MEMORY.md:** Update the index for any new, removed, or reclassified memories.
6. **Cleanup:** Remove orphaned files (with user confirmation per guardrails).
7. **Task status:** Update README.md in completed task directories.
8. **Knowledge:** Write or update runbooks, decision records, or data dictionary entries.

Do NOT:
- Create rule entries for one-time mistakes already covered by existing rules
- Add guidance that restates what agent_directives_v3.md already says
- Write aspirational rules ("always be thorough") -- rules must be concrete and testable
- Update files that weren't relevant to the session
- Treat stripping a broken feature as "resolving" it -- log it as an open problem

**PHASE 5 -- REPORT**

Write a retrospective artifact to `analysis/data-health/YYYY-MM-DD-session-retrospective.md` covering:

1. **Session summary:** What was accomplished
2. **Friction points:** Enumerated with classification (PROCESS/JUDGMENT/EXECUTION/COMMUNICATION)
3. **Patterns:** Recurring themes across friction points
4. **Wins:** What worked well
5. **Audit checklist:** The complete Phase 2 checklist with statuses
6. **Updates applied:** Count by type (memory, rule, command, knowledge, CLAUDE.md, cleanup)
7. **Open design problems:** Unresolved items carried forward
8. **Highest-leverage change:** The single improvement that will prevent the most future friction

Then report the summary to the user:
- Number of friction points detected
- Number of updates applied (by type)
- The highest-leverage change and why
- Open design problems (what's unresolved and why)
- Any items flagged for user decision (e.g., orphaned file deletion)

Keep the report concise. No self-congratulation. State what changed and where.
