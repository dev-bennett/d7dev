# Project 10: Memory-to-rule migration

## Overview
Feedback memories capture recurring patterns the agent would otherwise forget. Recurring enough to be worth a memory is also evidence that the pattern is worth enforcing at the rule or hook layer, where cost of enforcement is lower than cost of recall. Currently, promotion is ad-hoc; the user has noted several cases where a memory cited for weeks should have been promoted earlier.

## Linked framework section
`../../analytical-orchestration-framework.md` §5.6

## End goal
A background process reads the session-transcript corpus, counts citations of each feedback memory (by filename or hash of its content), and when a memory crosses the 3-session citation threshold, emits a promotion proposal artifact with a draft rule file body derived from the memory.

## Phased approach

### Phase 1 — Citation detector
**Complexity:** Medium
**Exit criteria:** Script that reads `~/.claude/projects/<proj>/*.jsonl` transcripts and counts per-memory citations.
**Steps:**
- Define citation signature (filename reference, description match, or content hash)
- Write scanner across transcript corpus
- Persist per-memory citation counts to a state file

### Phase 2 — Promotion proposals
**Complexity:** Medium
**Exit criteria:** When a memory crosses threshold, a proposal markdown is generated at `evolution/memory-to-rule-proposals/<date>-<slug>.md` with draft rule body.
**Steps:**
- Draft-rule template derived from memory body (Why/How to apply → rule form)
- Include proposed `applies_to`/`implements` frontmatter
- Emit on `/evolve` and on scheduled run

### Phase 3 — Adoption workflow
**Complexity:** Low
**Exit criteria:** Proposals accepted by the user land in `.claude/rules/`; source memory is archived with a pointer to the new rule.
**Steps:**
- Accept/reject workflow
- Cross-reference memory → rule in MEMORY.md and rule frontmatter

## Dependencies
- Project 05 (rule efficacy telemetry) for `implements` frontmatter
- Project 02 (session event log) may be simpler citation source than raw transcript scan

## Risks
- Citation signature false negatives (paraphrased references) → accept conservative under-counting
- Rule body auto-draft may need significant human editing → keep proposals as drafts, not auto-applied
