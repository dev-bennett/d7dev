@../CLAUDE.md

# Followups

Follow-on tasks built on top of the parent Mac/OS validation. Each subdirectory is a discrete deliverable dated `YYYY-MM-DD-<slug>/`.

Convention:
- Each subdirectory has its own `CLAUDE.md` chained via `@../../CLAUDE.md` (skipping this index file).
- Each carries its own `console.sql`, query CSVs, contract, and findings.
- The parent task's calibrated source filter (`mp_reserved_os IN ('Mac','Mac OS X')`) is canonical here — do not redefine it.
