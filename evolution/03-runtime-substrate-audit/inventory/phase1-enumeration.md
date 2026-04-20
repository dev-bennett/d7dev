# Phase 1 — Resource Enumeration

Observed 2026-04-20 on Claude Code CLI running on macOS Darwin 24.6.0. Session ID `db05792b-f977-4540-a83d-24b8f7c31461`. Assistant model: Opus 4.7 (1M context).

Scope roots:
- **User-scope:** `~/.claude/` → `/Users/dev/.claude/`
- **Project-scope:** `<repo>/.claude/` → `/Users/dev/PycharmProjects/d7dev/.claude/`

## 1. Memory (user-scope, per-project keyed by project path)

- **Canonical path:** `~/.claude/projects/<url-encoded-project-path>/memory/`
- **This project:** `~/.claude/projects/-Users-dev-PycharmProjects-d7dev/memory/`
- **Count:** 47 `.md` files (1 index `MEMORY.md` + 46 typed memory entries)
- **Contents (this project):** `MEMORY.md` index + `feedback_*.md` (30), `project_*.md` (11), `reference_*.md` (3), `user_*.md` (2)
- **Project-scope handle:** `<repo>/.claude/memory` is a symlink → `~/.claude/projects/-Users-dev-PycharmProjects-d7dev/memory` (since 2026-04-18; local gitignored)
- **Lifecycle:** Persistent across sessions. Authored by the assistant (per the auto-memory protocol injected by the host). Files may be edited mid-session; the index (`MEMORY.md`) is surfaced into every turn automatically by the host.
- **Injection mechanism:** Host auto-injects `MEMORY.md` into every conversation; individual memory files are loaded on-demand via `Read`.
- **Staleness cue:** Files ≥14 days old appear with a `<system-reminder>` noting staleness when read.

## 2. Session transcripts (user-scope, per-project)

- **Canonical path:** `~/.claude/projects/<url-encoded-project-path>/*.jsonl`
- **This project:** 30 `.jsonl` files, one per session (UUID-named). Example: `db05792b-f977-4540-a83d-24b8f7c31461.jsonl`, `082e3bc6-16ef-400a-86e7-00a84d621bfc.jsonl`.
- **Project-scope handle:** `<repo>/.claude/session-transcripts` is a symlink → `~/.claude/projects/-Users-dev-PycharmProjects-d7dev` (since 2026-04-18; local gitignored).
- **Lifecycle:** Written continuously during a session by the host runtime. Persist indefinitely. No rotation observed.
- **Companion dirs:** same parent also contains per-session UUID subdirectories (likely auxiliary state per conversation).

## 3. Projects registry (user-scope)

- **Canonical path:** `~/.claude/projects/`
- **Contents:** 7 project subdirectories keyed by URL-encoded absolute path:
  - `-Users-dev-PycharmProjects-d7` (d7 workspace)
  - `-Users-dev-PycharmProjects-d7dev` (this workspace)
  - `-Users-dev-PycharmProjects-d7farms`
  - `-Users-dev-PycharmProjects-dev`
  - `-Users-dev-PycharmProjects-dev-tasks-research`
  - `-Users-dev-PycharmProjects-dev-tasks-soundstripe-digest`
  - `-Users-dev-conductor-workspaces-conductor-playground-dallas`
- **Lifecycle:** Host creates a directory the first time Claude Code is invoked from a given working directory. No explicit delete mechanism observed.

## 4. Todos / native task state (user-scope)

- **Canonical path:** `~/.claude/todos/*.json`
- **Count:** 38 JSON files, all named `<session_id>-agent-<session_id>.json`.
- **Contents sampled:** Empty arrays `[]` for old/inactive sessions; the file for the active session holds the live todo list.
- **Lifecycle:** Created per-session; persists after session ends (as empty or stale).
- **Invocation:** Written via `TaskCreate`/`TaskUpdate` tools. Read-back via `TaskList`/`TaskGet`.
- **Sibling (per-subagent):** `~/.claude/tasks/<session_id>/N.json` holds per-agent-launch task state (seen: 9 session dirs, each with numeric task files).

## 5. Settings files (user-scope AND project-scope with precedence)

- **User-scope:** `~/.claude/settings.json` (29 bytes; contents `{"effortLevel": "xhigh"}`). No user-scope `settings.local.json`.
- **Project-scope tracked:** `<repo>/.claude/settings.json` (2378 bytes; wires hooks, permissions allow/deny list, env).
- **Project-scope local:** `<repo>/.claude/settings.local.json` (7637 bytes; per-user permission grants accumulated over sessions). Not git-tracked (see `.gitignore`).
- **Remote config:** `~/.claude/remote-settings.json` (255 bytes, user-only mode `0600`). Source-of-truth unknown; observed mtime 2026-04-14.
- **Policy limits:** `~/.claude/policy-limits.json` (219 bytes, mode `0600`).
- **Precedence (inferred):** project-scope `settings.json` > project-scope `settings.local.json` > user-scope `settings.json`. Explicit verification pending (see Phase 2).

## 6. Commands (project-scope)

- **Canonical path:** `<repo>/.claude/commands/*.md`
- **Count:** 16 markdown files (analyze, checkpoint, etl, evolve, ingest, kb-update, lookml, model, monitor, orient, preflight, review, roadmap, scaffold, status, test).
- **User-scope:** none (`~/.claude/commands/` does not exist).
- **Plugin-supplied commands:** yes, via installed plugin `marketing@soundstripe-plugins` (has `commands/` subdirectory).
- **Invocation:** user types `/<name>` in chat; host resolves to the command markdown and interprets it as an instruction.
- **Lifecycle:** static; authored by humans + agents; tracked in git.

## 7. Agents (project-scope + user-scope absent)

- **Project-scope path:** `<repo>/.claude/agents/*.md`
- **Count:** 6 agents (analyst, architect, data-engineer, kb-curator, lookml-developer, modeler — all `claude-sonnet-4-6`).
- **User-scope:** none (`~/.claude/agents/` does not exist).
- **Plugin-supplied agents:** yes — marketing plugin ships 5 agents (content-generation, conversation-analysis, discover-brand, document-analysis, quality-assurance).
- **Invocation:** via `Agent` tool with `subagent_type` field, or surfaced in the system prompt's available-agents list.
- **Lifecycle:** static; tracked in git.

## 8. Hooks (project-scope + user-scope absent)

- **Project-scope path:** `<repo>/.claude/hooks/*.sh` (and supporting files)
- **Count:** 11 shell scripts + 2 markdown references:
  - `_lib.sh` (shared utilities)
  - `bash-guard.sh` (PreToolUse Bash)
  - `health-check.sh` (SessionStart)
  - `prompt-context.sh` (UserPromptSubmit)
  - `retry-guard.sh` (PreToolUse Write|Edit)
  - `session-closeout.sh` (SessionEnd)
  - `session-gate.sh` (PreToolUse Write|Edit)
  - `test-all.sh` (manual harness)
  - `workflow-tracker.sh` (PostToolUse Write|Edit|Bash|Skill)
  - `writing-scrub.sh` (PreToolUse Write|Edit)
  - `checkpoint.md` (cross-session checkpoint artifact, not a script)
  - `claude_hooks_walkthrough.md` (reference doc)
- **User-scope:** none (`~/.claude/hooks/` does not exist).
- **Wiring:** `<repo>/.claude/settings.json` → `hooks` block maps event name → command path.
- **Runtime state:** `/tmp/d7dev-hooks/<SESSION_ID>/` (created by `_lib.sh::ensure_state_dir`; holds marker files and counters).
- **Error log:** `<repo>/.claude/hooks/errors.log` (persistent) + `.prev` on rotation.
- **Lifecycle:** static files; runtime state transient (lives under `/tmp`, per-session scope).

## 9. Skills (project-scope + user-scope via plugins)

- **Project-scope path:** `<repo>/.claude/skills/<skill>/SKILL.md`
- **Project skills count:** 1 (`new-domain`).
- **Plugin-supplied skills:** 2 from marketing plugin (`brand-voice-enforcement`, `guideline-generation`) + skills from official marketplace (loop, schedule, simplify, ingest, etc. — surfaced via the available-skills list in the system prompt).
- **Plugin install location:** `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/skills/`
- **Invocation:** via `Skill` tool with `skill` name, or user types `/<name>` (slash-command alias).

## 10. MCP / plugin registry (user-scope)

- **Registry root:** `~/.claude/plugins/`
  - `blocklist.json` — host-managed block list; fetched 2026-03-30.
  - `cache/` — cached plugin downloads (by marketplace and version).
  - `installed_plugins.json` — which plugins are installed (v2; currently only `marketing@soundstripe-plugins@1.0.0` managed-scope).
  - `known_marketplaces.json` — marketplace registrations (2 known: `claude-plugins-official` from anthropics, `soundstripe-plugins` from SoundstripeEngineering).
  - `marketplaces/<name>/` — cloned marketplace repos (plugin source of truth).
- **MCP auth cache:** `~/.claude/mcp-needs-auth-cache.json` — timestamps of which connected MCP servers prompted for auth.
- **Lifecycle:** cloned on `claude mcp` / plugin install; refreshed by the host on-demand.

## 11. Rules (project-scope, auto-loaded)

- **Canonical path:** `<repo>/.claude/rules/*.md`
- **Count:** 10 rule files (analysis-methodology, dbt-standards, deliverable-standards, git-workflow, guardrails, lookml-standards, python-standards, roadmapping-methodology, sql-snowflake, writing-standards).
- **User-scope:** none (`~/.claude/rules/` does not exist).
- **Loading mechanism:** `@` imports at the bottom of the root `CLAUDE.md` — the host resolves each `@.claude/rules/<file>.md` and auto-loads the content into every conversation's system context.
- **Lifecycle:** static; tracked in git.

## 12. CLAUDE.md import chain (project-scope, auto-loaded)

- **Root:** `<repo>/CLAUDE.md` (auto-loaded on every session start).
- **Import operator:** `@<path>` — resolved relative to the file doing the import.
- **Chain convention:** every subdirectory under managed roots (`analysis/`, `etl/`, `lookml/`, `knowledge/`, `initiatives/`, `evolution/`) has its own `CLAUDE.md` with `@../CLAUDE.md` import. 106 CLAUDE.md files resolved via `Glob **/CLAUDE.md` (2026-04-20).
- **Enforcement:** `.claude/hooks/session-gate.sh` blocks any Write/Edit in a managed directory missing its `CLAUDE.md`.
- **Loading mechanism:** host auto-loads the nearest `CLAUDE.md` when navigating into a directory and recursively loads imports via `@`.

## 13. Keybindings (user-scope config, optional)

- **Canonical path:** `~/.claude/keybindings.json`
- **Observed:** file does not exist. Defaults in effect.
- **Invocation:** via the `keybindings-help` skill (from official plugin marketplace).

## 14. Status-line config (user-scope, optional)

- **Canonical path:** `~/.claude/statusline.json` (inferred)
- **Observed:** file does not exist.
- **Invocation:** via the `statusline-setup` agent (listed in available-agents).

## 15. Session log / user prompt history (user-scope transcripts directory)

- **Canonical path:** `~/.claude/history.jsonl` (user-scope, aggregate across ALL projects). 283934 bytes, mode `0600`, mtime 2026-04-20.
- **Distinct from per-project transcripts (§2).** This file is an aggregate prompt log; per-project JSONL transcripts hold full conversation content.
- **Lifecycle:** append-only. No rotation observed.

## Additional user-scope resources observed (not in the original 15)

| Path | Apparent purpose | Lifecycle |
|---|---|---|
| `~/.claude/backups/` | Timestamped backups of `.claude.json` (the user-scope configuration file kept in $HOME). Presence indicates host auto-backs-up on config writes. | Append-only; rotation unknown |
| `~/.claude/cache/` | General host cache | Transient |
| `~/.claude/chrome/` | Claude-in-chrome MCP server state | Refreshed on use |
| `~/.claude/debug/` | Per-session debug dumps (e.g., `db05792b-...txt`); `latest` symlink points to current session. Symlinked into this repo as `debug/` on 2026-04-20. | Per-session; retention unknown |
| `~/.claude/file-history/` | Per-session directories holding versioned snapshots of files the assistant Read/Edited (`<hash>@vN` pattern). Used for undo / retrospective introspection. | Persistent per-session |
| `~/.claude/ide/` | IDE integration state (JetBrains/VS Code). Currently holds `58229.lock` (a PID lock). | Session-bound |
| `~/.claude/paste-cache/` | Paste buffer cache for large clipboard operations | Transient |
| `~/.claude/plans/` | Plan-mode output files (one per `ExitPlanMode` invocation; `<slug>.md`). 20 files observed. | Persistent |
| `~/.claude/session-env/<session_id>/` | Per-session shell environment captures (empty for recent sessions; likely a workspace for shell-env delta tracking). | Per-session |
| `~/.claude/sessions/` | Session metadata (`47045.json` observed). Appears to hold cross-session state. | Persistent |
| `~/.claude/shell-snapshots/` | Zsh session snapshots (`snapshot-zsh-<epoch-ms>-<slug>.sh`). Used to reconstruct shell state the assistant's bash tool sees. | Per-bash-init |
| `~/.claude/statsig/` | Statsig SDK state (feature flags for Claude Code itself — evaluations, session_id, stable_id). | Host-managed |
| `~/.claude/stats-cache.json` | Host-level stats cache (mode `0600`) | Persistent |
| `~/.claude/telemetry/` | Telemetry output (`1p_failed_events.<uuid>.<uuid>.json` observed — failed-event buffer). Relevant to Epic 0.3 (OpenTelemetry). | Transient/flushed |

## Absences confirmed

- `~/.claude/agents/` — absent. All agents live project-scope.
- `~/.claude/commands/` — absent.
- `~/.claude/hooks/` — absent.
- `~/.claude/skills/` — absent.
- `~/.claude/memory/` — absent at the top level (lives under `~/.claude/projects/<slug>/memory/`).
- `~/.claude/keybindings.json` — absent.
- `~/.claude/statusline.json` — absent.
- `~/.claude/settings.local.json` — absent (local overlays live only at project scope).
- `~/.claude/history/` as a directory — absent (`history.jsonl` is a flat file).
- `<repo>/.claude/plugins/` — absent (no project-installed plugins; all plugins are user-scope).
