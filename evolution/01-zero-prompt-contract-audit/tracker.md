# Tracker: 01-zero-prompt-contract-audit

## Current state
**Tier:** 1
**Complexity:** Medium (overall)
**Current phase:** complete
**Status:** complete
**Last touched:** 2026-04-20
**Blockers:** none
**Next action:** —

## Phase log
### Phase 1 — Audit /orient specifically
- Start: 2026-04-20
- Complete: 2026-04-20
- Notes:
  - `/orient`'s explicit bash surface (`git:*`, `ls:*`, `date:*`, piped to `head:*`) was already covered by `settings.json`.
  - Structural gaps closed for the whole contract: added bare `Write` and `Edit` (operator decision — matches existing bare `Read`/`Glob`/`Grep`; runtime safety remains with `bash-guard.sh`, `retry-guard.sh`, `session-gate.sh`, and the `deny` list).
  - Added defensive bash patterns named in the brief or natural for /orient ad-libs: `stat`, `find`, `awk`, `sort`, `uniq`, `cut`, `tr`, `jq`, `echo`, `printf`, `xargs`, `for`, `while`, `if`, `test`.
  - `Bash(grep:*)` and `Bash(sed:*)` intentionally NOT added — rule preference directs agents to the `Grep` and `Edit` tools.
  - Removed redundant `Write(.claude/hooks/session-briefing.md)` since bare `Write` supersedes it.
  - Allowlist: 27 → 41 entries. `settings.local.json` untouched per operator decision.

### Phase 2 — Audit remaining commands
- Start: 2026-04-20
- Complete: 2026-04-20
- Notes:
  - Read all 15 remaining command files; authored `command-tool-matrix.md` (16-command × tool-call inventory with coverage flags).
  - Additions to `settings.json`: `Bash(rm:*)`, `Bash(mv:*)`, `Bash(cp:*)` — closes gaps in `/ingest` step 4 ("Clear the target directory"), `/evolve` Phase 4 step 6 ("Remove orphaned files"), and defensive `/scaffold` templating.
  - Existing deny `Bash(rm -rf /)*` already covers catastrophic absolute-path deletions including `rm -rf /Users/...` via prefix match; runtime safety further enforced by `bash-guard.sh` + `session-gate.sh`.
  - No inter-command `Skill`/command-call invocations found; no propagation risk.
  - Accepted residual gap: `/roadmap` step 20 Graphviz/Mermaid CLI (not wired in current command spec); will prompt if/when a user opts for flowchart generation. Conservative over-approximation per brief.
  - Allowlist: 41 → 44 entries.

### Phase 3 — Automated audit + guard
- Start: 2026-04-20
- Complete: 2026-04-20
- Notes:
  - Authored `scripts/audit_command_permissions.py` (py312, type-hinted). Parses `.claude/commands/*.md` for tool-call references from three surfaces: `Run: \`<cmd>\`` lines, fenced ```bash blocks, inline backticks that look like invocations (lowercase command + whitespace + args), and `Tool(args)` settings-style references. Computes effective allowlist as the set union of project, project-local, and user settings files per substrate-catalog §5. Matching algorithm implements bare tool-class cover, exact literal cover, and `Tool(prefix:*)` wildcard-prefix cover (supporting multi-word prefixes like `Bash(git add:*)`). Modes: `--report` (human-readable table) and `--check` (exit 1 on gap).
  - Authored `tests/test_audit_command_permissions.py` — 23 tests covering extraction surfaces, allowlist union loading (missing/invalid scope tolerance), matching semantics (bare tool, exact literal, wildcard prefix, piped commands, multi-word prefixes), end-to-end audit against synthetic fixtures (all-covered and gap cases), CLI `--check`/`--report` behavior, and a live-repo smoke test. `python3 -m pytest tests/test_audit_command_permissions.py -v` → 23 passed.
  - Extended `.claude/commands/test.md` step 5: invokes `python scripts/audit_command_permissions.py --check` when `$ARGUMENTS` is empty or contains "audit".
  - Live-repo audit: `python3 scripts/audit_command_permissions.py --check` → exit 0 (17/17 explicit tool-call references covered).
  - Ruff lint not run — binary not installed on this host; defer to CI.
  - Allowlist: 44 entries (final; up from 27 at epic start).

## Decisions
- 2026-04-18 — Project scoped as tier 1 given immediate friction observed in this session's /orient run.

## Related artifacts
- `.claude/settings.json`
- `.claude/settings.local.json`
- `.claude/commands/*.md`
