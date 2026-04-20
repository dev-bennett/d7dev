# Phase 2 — Resource Interactions & Precedence

## Precedence rules

### Settings precedence (observed + inferred)
1. `<repo>/.claude/settings.local.json` — user-specific, local-only permission grants. Accumulates over time as the host prompts for permission and the user approves.
2. `<repo>/.claude/settings.json` — project-scope, git-tracked. Defines hooks, allow/deny lists, env.
3. `~/.claude/settings.json` — user-scope, cross-project. Holds sparse global config (e.g., `effortLevel`).
4. Defaults compiled into the host.

Effective merge: values present in more-specific scopes OVERLAY less-specific ones. For `permissions.allow`, the effective allowlist is the UNION of project + local + user. For scalar keys (e.g., `env.FOO`), project overrides user.

### Memory keying
- Memory is user-scope but keyed by URL-encoded absolute project path (`-Users-dev-PycharmProjects-d7dev/memory/`). Opening the same project from a different machine or from a moved directory creates a NEW memory keyspace.
- The project's `.claude/memory` symlink resolves the key transparently inside the repo. The symlink target is per-user, so it is `.gitignore`d.

### CLAUDE.md chain
- Root `<repo>/CLAUDE.md` is auto-loaded at session start.
- `@<path>` imports are transitive — imports import.
- Directory-level `CLAUDE.md` is lazily loaded when the assistant navigates into that directory. Not transitively pre-loaded at session start — this is by design and is what makes deep directory trees affordable.
- Rule files imported from root CLAUDE.md (the 10 `.claude/rules/*.md`) ARE loaded at session start and persist for the whole session.

### Hook firing order (same event)
- Multiple hook entries under one event fire in declared order (sequential, not parallel).
- Example: `PreToolUse` `Write|Edit` wires `session-gate.sh` → `retry-guard.sh` → `writing-scrub.sh`. Each receives the same JSON input from stdin; each can block.
- First hook that exits 2 blocks the tool call; later hooks for the same event do not run.
- Exit 1 emits a warning but does not block. Subsequent hooks still run.

### Skill vs command vs agent invocation
- Slash-commands map to `.claude/commands/<name>.md`.
- Skills are invoked via the `Skill` tool with `skill` parameter. Project skills at `.claude/skills/<name>/SKILL.md`; plugin skills at `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/skills/<name>/SKILL.md`.
- If a slash-command name collides with a skill name, the slash-command wins (commands are more specific to the project).
- Agents are dispatched via the `Agent` tool with `subagent_type`; project agents at `.claude/agents/`; plugin agents at `~/.claude/plugins/cache/.../agents/`.

## Adjacency table

Edges describe direct runtime interactions (shared state, override, sequencing). `→` denotes directional flow (A writes / affects B); `↔` denotes mutual.

| From | To | Kind | Mechanism |
|---|---|---|---|
| `settings.json` (project) | hooks | config → activation | `hooks` block maps event name to script path |
| `settings.local.json` (project) | `settings.json` (project) | overlay | permission allowlist union |
| `settings.json` (user) | `settings.json` (project) | base | scalar keys overridden by project |
| `hooks/session-gate.sh` | CLAUDE.md chain | enforce | blocks Write/Edit in managed dirs lacking `CLAUDE.md` |
| `hooks/retry-guard.sh` | `/tmp/d7dev-hooks/<sid>/edit_log` | write | appends per-file fingerprint on each Write/Edit |
| `hooks/bash-guard.sh` | `/tmp/d7dev-hooks/<sid>/bash_log` | write | appends command fingerprint on each Bash |
| `hooks/bash-guard.sh` | `/tmp/d7dev-hooks/<sid>/review_done` | read | checks marker before allowing `git commit` |
| `hooks/workflow-tracker.sh` | `/tmp/d7dev-hooks/<sid>/review_done` | write | touches marker when `/review` skill fires |
| `hooks/workflow-tracker.sh` | `/tmp/d7dev-hooks/<sid>/preflight_done` | write | touches marker when `/preflight` skill fires |
| `hooks/session-gate.sh` | `/tmp/d7dev-hooks/<sid>/preflight_done` | read | nudges `/preflight` after 3+ managed writes without marker |
| `hooks/prompt-context.sh` | conversation context | inject | emits `hookSpecificOutput.additionalContext` with date, checkpoint age, memory staleness |
| `hooks/health-check.sh` | `.claude/hooks/errors.log` | read + rotate | surfaces prior-session errors at SessionStart; rotates to `.prev` |
| all hooks | `.claude/hooks/errors.log` | write | `init_hook` error trap appends crashes |
| root `CLAUDE.md` | `.claude/rules/*.md` | import | `@` directives auto-load at session start |
| directory `CLAUDE.md` | parent `CLAUDE.md` | import | `@../CLAUDE.md` chain |
| `prompt-context.sh` | memory `MEMORY.md` | reads mtime | emits staleness warning if ≥14 days old |
| host runtime | memory `MEMORY.md` | auto-inject | loaded into every conversation context |
| host runtime | per-directory `CLAUDE.md` | auto-inject | loaded when assistant navigates into that directory |
| `Skill` tool | `.claude/skills/*/SKILL.md` | resolve + execute | project skills checked first |
| `Skill` tool | `~/.claude/plugins/cache/.../skills/*/SKILL.md` | resolve + execute | plugin skills checked after project |
| slash-command | `.claude/commands/<name>.md` | resolve + interpret | user types `/<name>` |
| `Agent` tool | `.claude/agents/<type>.md` | resolve + spawn | project agents first |
| `Agent` tool | plugin agents | resolve + spawn | fallback + marketing:* namespace |
| `TaskCreate` / `TaskUpdate` | `~/.claude/todos/<sid>-agent-<sid>.json` | write | per-session todo list |
| sub-agent launch | `~/.claude/tasks/<sid>/N.json` | write | per-agent-launch task state |
| session start | `~/.claude/projects/<slug>/<sid>.jsonl` | append | transcript file created + updated per turn |
| every prompt | `~/.claude/history.jsonl` | append | cross-project prompt log |
| every plan exit | `~/.claude/plans/<slug>.md` | write | plan-mode output |
| every Read/Edit | `~/.claude/file-history/<sid>/<hash>@vN` | snapshot | per-file versioning (assistant-side undo buffer) |
| every bash init | `~/.claude/shell-snapshots/snapshot-zsh-<ts>-<slug>.sh` | write | captures shell state for the Bash tool's execution context |
| host | `~/.claude/sessions/<pid>.json` | write | cross-session metadata |
| host | `~/.claude/telemetry/*.json` | write | failed-event buffer (1p_failed_events) — substrate for Epic 0.3 |
| host | `~/.claude/debug/<sid>.txt` + `latest` symlink | write | debug dump per session |
| plugin install | `~/.claude/plugins/cache/<marketplace>/<plugin>/<ver>/` | clone | plugin contents available to tool surface |
| plugin install | `~/.claude/plugins/installed_plugins.json` | update | registry of installed plugins |
| marketplace sync | `~/.claude/plugins/marketplaces/<name>/` | clone / pull | marketplace repo |

## Known-problematic interactions

| Pattern | Observation | Mitigation / rule memory |
|---|---|---|
| Editing `.claude/hooks/*.sh` mid-session | Host caches hook state at session start; mid-session errors in a hook can disable the entire hook runner for the rest of the session. Observed 2026-04-07 when iterating on `_lib.sh` crashed all downstream hooks. | `feedback_dont_edit_live_hooks.md` — never edit hooks in the session where they run; test with `bash -n` and start fresh. |
| `Stop` vs `SessionEnd` event confusion | `Stop` fires per-turn; `SessionEnd` fires once. Wiring `session-closeout.sh` to `Stop` wiped per-session state mid-session. | `feedback_hook_events.md` — per-turn → Stop; per-session → SessionEnd. SessionEnd cannot block. |
| `settings.local.json` silent accumulation | Permissions granted per-prompt land in `settings.local.json` and accumulate. The derived allowlist is the union of project + local, so canonical commands may "work" locally via `settings.local.json` while failing for another user with an empty local overlay. | Epic 0.2 goal: derive allowlist from command specs rather than reacting to prompts. |
| Hook state in `/tmp/d7dev-hooks/<sid>/` | No cleanup on SessionEnd (`session-closeout.sh` presence TBD). Stale per-session dirs accumulate under `/tmp` until OS reboot or `/tmp` clear. | `session-closeout.sh` opportunity: `rm -rf "$STATE_DIR"` at session end. |
| `/clear` fires `SessionEnd` | Context reset; any SessionEnd-registered cleanup runs. | Desired behavior. |
| Memory staleness | Memories unrefreshed ≥14 days trigger a `<system-reminder>` on Read. | `prompt-context.sh` injects warning at prompt submit if `MEMORY.md` itself is ≥14 days stale. |
| Plugin agents with overlapping names | Plugin `marketing` supplies `discover-brand`, `content-generation`, etc. Namespaced as `marketing:<name>` in available-agents. | Host namespaces plugin agents; project-scope agents live in the unnamespaced list. |
| Slash-command collisions | If a slash-command name matches a skill name, the command wins. Observed in `/review` (both a command and a skill exist — command wins). | Not a bug; by design. |
| `context/dbt` and `context/lookml` submodules | Submodules are live git submodules. `context/lookml` is currently half-registered (.gitmodules entry, no gitlink). | Loose end tracked in `project_commit_backlog.md`. |
| File-history accumulation | `~/.claude/file-history/<sid>/` grows per-Read/Edit. No observed retention policy. | Monitor disk usage periodically. |

## Precedence as a decision tree (for resource selection)

Use this to pick the right resource when adding a new capability:

1. **Stateful config read across turns?** → `~/.claude/file-history/` (assistant-internal) or CLAUDE.md/rules (user-visible).
2. **Per-session ephemeral state?** → `/tmp/d7dev-hooks/<sid>/` via `_lib.sh` helpers.
3. **Durable cross-session user-specific knowledge?** → memory (`~/.claude/projects/<slug>/memory/`).
4. **Durable project knowledge shared with collaborators?** → `knowledge/` or `.claude/rules/`.
5. **Invocable via slash?** → `.claude/commands/` (command) or `.claude/skills/` (skill).
6. **Invocable via sub-agent dispatch?** → `.claude/agents/`.
7. **Reactive to tool use?** → `.claude/hooks/` + wire in `settings.json`.
8. **Cross-repo or cross-user?** → plugin (marketplace → install).

## Version-sensitivity note

Every observation in Phases 1–2 is scoped to the host runtime version in effect at 2026-04-20. The host-runtime changelog is external; when a new version ships, re-run the `ls`-level enumeration on `~/.claude/` to detect new directories (e.g., OTel collector paths if Epic 0.3 lands). Date-stamp all future updates to the runbook.
