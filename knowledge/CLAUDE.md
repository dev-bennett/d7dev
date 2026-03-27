# Knowledge Base

Institutional knowledge, canonical definitions, and operational procedures.

## Structure

- `knowledge/domains/<domain>/` -- per-domain knowledge (overview, metrics, context)
- `knowledge/data-dictionary/` -- canonical field and metric definitions
- `knowledge/runbooks/` -- operational how-tos and procedures
- `knowledge/decisions/` -- ADR-style analytical decision records

## Conventions

- Articles must have: title, last-updated date, author/source
- Data dictionary entries: field name, definition, calculation SQL, source table, owner
- Runbooks: purpose, prerequisites, step-by-step, troubleshooting
- Decisions: context, decision, rationale, consequences, status
- Cross-reference related articles; maintain link integrity
- When analysis produces new institutional knowledge, capture it here
- This is the single source of truth -- accuracy over speed
