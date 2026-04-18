# Project 04: Directive linter

## Overview
§-blocks (Rate Declarations, Type Audits, Null Hypothesis, Contract Checklists, Adversarial Checks, Intervention Classifications, Sentence Audits) are currently authored as free-form code fences. Presence is by convention. No deterministic check exists that a required §-block is present on a given analytical output, that its preamble is well-formed, or that required sub-fields (RATE, NUMERATOR, DENOMINATOR, etc.) are populated.

## Linked framework section
`../../analytical-orchestration-framework.md` §3.1

## End goal
A Python linter at `scripts/directive_lint.py` that:

1. Accepts a file path (or glob) and determines required §-blocks for that file type (findings.md → §1/§2/§7/§8/§10/§11; query.sql → §1 type audit; etc.)
2. Parses the file for fenced preambles (`<§N>...</§N>` or equivalent convention)
3. Reports missing or malformed blocks with line numbers
4. Exits non-zero on failure for CI/pre-commit integration
5. Integrates with `/review` and `/test`

## Phased approach

### Phase 1 — Preamble convention + parser
**Complexity:** Low
**Exit criteria:** A fenced preamble convention is chosen (e.g., `<§1>...</§1>` or front-matter-style). Parser reads a file and returns a list of found blocks with sub-fields.
**Steps:**
- Decide preamble syntax (HTML-comment-delimited, markdown-fence-language, or yaml front-matter)
- Write parser + unit tests
- Migrate one existing analysis file to the new convention as a reference

### Phase 2 — Required-block map per file type
**Complexity:** Medium
**Exit criteria:** `scripts/directive_lint.py` accepts a file and reports missing required blocks.
**Steps:**
- Build the mapping: file glob → list of required §-blocks
- Implement checker
- Backfill migration for existing analysis files (one-shot pass)

### Phase 3 — CI + pre-commit integration
**Complexity:** Low-Medium
**Exit criteria:** `/test lint` runs the directive linter. Pre-commit hook fails on unfixed §-block violations.
**Steps:**
- Wire into `/test`
- Add pre-commit hook
- Document in CLAUDE.md

## Dependencies
- Consensus on preamble convention (semi-blocking for Phase 2)

## Risks
- Strict checking on historical files would generate a migration backlog → scope enforcement to new files + known-good subset
