# Verification artifacts — Epic 0.3

@../CLAUDE.md

## Purpose
Captures evidence that each phase of Epic 0.3 met its exit criteria. Each artifact is a redacted, human-readable record — not raw exporter dumps.

## Conventions
- One file per phase gate: `phase1-orient-spans.md`, `phase2-hook-bridge-poc.md`, `full-e2e.md`
- Redact before commit: `session.id`, `file.path` values, any prompt/user content
- Artifact must identify host version (from `../host-version-pin.md`) at time of capture
- Mark each exit-criteria checkpoint with pass/fail and a copied line from the captured output

## Files
- `phase1-orient-spans.md` — Phase 1 four-signal checklist capture
- `phase2-hook-bridge-poc.md` — Phase 2 POC (filelog receiver bridges session-gate event)
- `full-e2e.md` — Phase 2 exit; full 10-step substrate verification
