# Decisions — Epic 0.3

@../CLAUDE.md

## Purpose
Records load-bearing design decisions for the telemetry substrate. Each record captures: decision, rationale, alternatives rejected, trigger conditions to revisit.

## Conventions
- One file per decision
- Filename: `<short-slug>.md`
- Include a revisit-trigger list — decisions decay; name the signals that would force a re-evaluation
- When a decision is overturned, do not delete the record — add a "Superseded by" pointer

## Files
- `hook-bridge-pattern.md` — choice of filelog tail (pattern c) for bridging workspace hook events into OTel
