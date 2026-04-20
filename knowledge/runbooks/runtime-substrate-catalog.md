# Runtime Substrate Catalog

- **Last updated:** 2026-04-20
- **Author:** Devon Bennett (d7admin) — compiled by assistant as Epic 0.1 deliverable
- **Host observed:** Claude Code CLI, macOS Darwin 24.6.0, assistant Opus 4.7 (1M context)
- **Framework anchor:** `../../analytical-orchestration-framework.md` §1.4 (Runtime substrate)
- **Source observations:** `evolution/03-runtime-substrate-audit/inventory/phase1-enumeration.md` (Phase 1) and `phase2-interactions.md` (Phase 2)

## Purpose

The framework's §3–§9 discipline (directives, three-pass workflow, deliverable contracts, enumeration protocol, writing scrub) assumes substrate properties the workspace does not author: hook events, permission model, CLAUDE.md import semantics, additional-context injection, session-transcript persistence, skills/plugins/agents/MCP surfaces, scope separation between user and project. This runbook catalogs every user-scope and project-scope Claude runtime resource observed at 2026-04-20, documents their lifecycles, precedence relationships, canonical usage patterns, and known failure modes. It is the reference a future operator or agent consults when deciding where a new capability belongs.

Framework §13 bootstrap step 0 is "Runtime substrate audit — inventory host capabilities ... confirm the substrate supports every assumption in §1.4." This runbook is the artifact for that step.

## Prerequisites

- Read access to `~/.claude/` and `<repo>/.claude/`.
- Familiarity with the framework doc §1.4 (context for why the substrate matters).
- Understanding of the three runtime scopes: user (`~/.claude/`), project (`<repo>/.claude/`), and transient (`/tmp/d7dev-hooks/<sid>/`).

## Scope boundaries

- **User scope** (`~/.claude/`): per-user, cross-project state. Not version-controlled. Persistent across sessions.
- **Project scope** (`<repo>/.claude/`): per-project, version-controlled state (except `settings.local.json` and symlinks to user-scope state, which are git-ignored).
- **Transient scope** (`/tmp/d7dev-hooks/<SESSION_ID>/`): per-session hook state. Lives until OS `/tmp` clear.
- **Plugin scope** (`~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/`): installed plugin contents; surfaces agents, skills, and commands into both user and project scopes.

## Resource catalog

Each resource lists: path, scope, lifecycle, authoring mechanism, invocation mechanism, precedence, canonical usage, known failure modes.

### 1. Memory

- **Path:** `~/.claude/projects/<url-encoded-project-path>/memory/` (this project: `~/.claude/projects/-Users-dev-PycharmProjects-d7dev/memory/`). Project-scope symlink at `<repo>/.claude/memory`.
- **Scope:** user-scope, keyed by URL-encoded absolute project path.
- **Lifecycle:** persistent across sessions. Created when the assistant first writes a memory. Individual files may be updated or deleted by the assistant per the auto-memory protocol.
- **Authoring:** the assistant, per the auto-memory instructions in the project system prompt.
- **Invocation:** host auto-injects `MEMORY.md` (the index) into every conversation. Individual memory files are loaded on-demand via `Read`.
- **Precedence:** single-source; no competing stores. The project-scope symlink is an alias for the user-scope directory, not an overlay.
- **Canonical usage:** durable cross-session knowledge about the user, project, references, and feedback. Four types: `user_*`, `project_*`, `reference_*`, `feedback_*`. Staleness markers injected when a memory is ≥14 days old on Read.
- **Known failure modes:** moving the project directory orphans the memory keyspace. Memory written without updating `MEMORY.md` is invisible to the injector. Memory that contradicts current code state may silently mislead — always verify against current files before asserting from memory.

### 2. Session transcripts

- **Path:** `~/.claude/projects/<url-encoded-project-path>/<session-uuid>.jsonl`. Project-scope symlink at `<repo>/.claude/session-transcripts`.
- **Scope:** user-scope, per-project, per-session.
- **Lifecycle:** created at session start, appended per turn, persists indefinitely. No rotation observed.
- **Authoring:** host runtime.
- **Invocation:** readable by `Read` or shell tooling. Not injected into the session it records (only prior sessions are referenceable).
- **Precedence:** aggregate prompt log at `~/.claude/history.jsonl` is cross-project and holds only prompts; JSONL per-project holds full conversation including assistant turns and tool calls.
- **Canonical usage:** retrospective analysis of past sessions; input for session-transcript corpus access (Epic 3.3, future work); source-of-truth for reconstructing what happened in a past session.
- **Known failure modes:** file grows unbounded; no retention policy. Contains PII / stakeholder messages; do not export outside the local machine.

### 3. Projects registry

- **Path:** `~/.claude/projects/<url-encoded-path>/`
- **Scope:** user-scope, global.
- **Lifecycle:** host creates a subdirectory the first time Claude Code is invoked from a given working directory. No explicit delete surfaced to the user.
- **Authoring:** host runtime.
- **Invocation:** not directly invoked; holds per-project memory, transcripts, and supporting state.
- **Precedence:** none; sole registry of known projects.
- **Canonical usage:** reference when listing projects from the host's point of view; target for cross-project audits.
- **Known failure modes:** directory names are URL-encoded absolute paths. Moving or renaming the project on disk creates a new registry entry and orphans the old one.

### 4. Todos and task state

- **Paths:**
  - `~/.claude/todos/<session-id>-agent-<session-id>.json` — the main-thread todo list per session.
  - `~/.claude/tasks/<session-id>/<N>.json` — per-sub-agent-launch task state.
- **Scope:** user-scope.
- **Lifecycle:** created per session / per sub-agent launch; files persist after session ends (often as empty arrays).
- **Authoring:** host runtime via the `TaskCreate`, `TaskUpdate`, `TaskGet`, `TaskList` tool family.
- **Invocation:** via the task tool family.
- **Precedence:** none.
- **Canonical usage:** multi-step task tracking within a single session. Not a persistent planner.
- **Known failure modes:** task lists are session-local; they do not survive into a new session. Stale empty files accumulate.

### 5. Settings files

- **Paths:**
  - `<repo>/.claude/settings.json` (project-scope, git-tracked) — wires hooks, `permissions.allow`, `permissions.deny`, `env`.
  - `<repo>/.claude/settings.local.json` (project-scope, git-ignored) — per-user permission grants accumulated on prompt-approve.
  - `~/.claude/settings.json` (user-scope, cross-project) — sparse global config (e.g., `effortLevel`).
  - `~/.claude/remote-settings.json` (user-scope, mode 0600) — remote-managed config; source of truth external.
  - `~/.claude/policy-limits.json` (user-scope, mode 0600) — policy limits.
- **Scope:** layered — user + project + project-local.
- **Lifecycle:** tracked (project `settings.json`), accumulating (project `settings.local.json`), edited in place (user `settings.json`).
- **Authoring:** humans (tracked), host/user dialog (local).
- **Invocation:** read at session start; applied throughout.
- **Precedence (for overlapping keys):** project `settings.local.json` > project `settings.json` > user `settings.json` > host defaults. For `permissions.allow`, the effective allowlist is the UNION of scopes (set union, not override).
- **Canonical usage:** declare hooks + allow/deny patterns at project scope; let local overlays handle per-user conveniences. Commands should not require `settings.local.json` entries — if they do, promote the pattern to `settings.json` (Epic 0.2).
- **Known failure modes:** silent accumulation of `settings.local.json` masks command permission gaps for new users. `update-config` skill (via MCP) is the canonical editor; hand-editing is supported but must preserve JSON structure.

### 6. Commands (slash-commands)

- **Path:** `<repo>/.claude/commands/*.md` (project-scope). No user-scope `~/.claude/commands/`.
- **Scope:** project-scope; plugin-supplied commands live under the plugin cache.
- **Lifecycle:** static; tracked in git.
- **Authoring:** humans, agents authoring scaffolded commands.
- **Invocation:** user types `/<name>` at a chat prompt; host resolves to the markdown and interprets it as instructions to the assistant.
- **Precedence:** project command name wins over skill of the same name.
- **Canonical usage:** durable, project-specific workflows (e.g., `/orient`, `/preflight`, `/analyze`). 16 commands present: analyze, checkpoint, etl, evolve, ingest, kb-update, lookml, model, monitor, orient, preflight, review, roadmap, scaffold, status, test.
- **Known failure modes:** a command that invokes tool calls not in the settings allowlist triggers a permission prompt per call (Epic 0.2 target).

### 7. Agents (sub-agents)

- **Paths:**
  - Project: `<repo>/.claude/agents/<type>.md` (6 agents: analyst, architect, data-engineer, kb-curator, lookml-developer, modeler, all `claude-sonnet-4-6`).
  - Plugin: `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/agents/<name>.md` (marketing plugin ships content-generation, conversation-analysis, discover-brand, document-analysis, quality-assurance).
- **Scope:** project + plugin (no user-scope direct agents dir).
- **Lifecycle:** static; tracked in their respective git repos.
- **Authoring:** humans.
- **Invocation:** via the `Agent` tool with `subagent_type`. Plugin agents are namespaced as `<plugin>:<name>`.
- **Precedence:** project-scope agents appear in the unnamespaced list; plugin agents use the `<plugin>:<name>` form.
- **Canonical usage:** delegate research (Explore), design (Plan), or specialized analytical work (analyst, data-engineer, modeler).
- **Known failure modes:** agent frontmatter (description, model) is load-bearing — it drives when the host offers the agent to the assistant. Stale descriptions lead to mis-dispatch.

### 8. Hooks

- **Path:** `<repo>/.claude/hooks/*.sh` (11 scripts + `_lib.sh` + 2 markdown references).
- **Scope:** project-scope. No user-scope hooks directory.
- **Lifecycle:** static scripts; runtime state transient under `/tmp/d7dev-hooks/<SESSION_ID>/`.
- **Authoring:** humans; agents draft changes in non-live sessions.
- **Invocation:** wired in `<repo>/.claude/settings.json` under the `hooks` block; host runs the script on the registered event.
  - `SessionStart` → `health-check.sh`
  - `UserPromptSubmit` → `prompt-context.sh` (emits `additionalContext`)
  - `PreToolUse` `Write|Edit` → `session-gate.sh`, `retry-guard.sh`, `writing-scrub.sh` (sequential)
  - `PreToolUse` `Bash` → `bash-guard.sh`
  - `PostToolUse` `Write|Edit|Bash|Skill` → `workflow-tracker.sh`
  - `SessionEnd` → `session-closeout.sh`
- **Precedence:** within one event, hooks fire in declared order; exit 2 blocks the tool and aborts later hooks for that event; exit 1 warns and continues.
- **Canonical usage:** enforce guardrails (CLAUDE.md chain, retry limits, git add . blocking), nudge workflow steps (`/preflight`, `/review`), inject context (date, checkpoint age, memory staleness).
- **Known failure modes:**
  - Editing hook scripts mid-session can disable the hook runner for the rest of the session (see `feedback_dont_edit_live_hooks.md`). Iterate in a new session, or test with `bash -n <script>` without invoking the host.
  - `Stop` fires per-turn, not per-session. Use `SessionEnd` for cleanup or summary hooks (see `feedback_hook_events.md`).
  - Hook state files under `/tmp/d7dev-hooks/<sid>/` accumulate without cleanup unless `session-closeout.sh` handles it. `SessionEnd` cannot block termination.

### 9. Skills

- **Paths:**
  - Project: `<repo>/.claude/skills/<skill>/SKILL.md` (1 project skill: `new-domain`).
  - Plugin: `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/skills/<name>/SKILL.md` (marketing plugin: `brand-voice-enforcement`, `guideline-generation`; official marketplace supplies loop, schedule, simplify, ingest, claude-api, keybindings-help, etc.).
- **Scope:** project + plugin.
- **Lifecycle:** static; tracked in source repos.
- **Authoring:** humans.
- **Invocation:** via the `Skill` tool with `skill` parameter; or via slash-command alias when the skill is bound to a command name.
- **Precedence:** project skill name wins over plugin skill of the same name; a command with the same name as a skill wins over both.
- **Canonical usage:** reusable procedure the assistant can delegate to (e.g., `update-config`, `review`). Different from commands: skills emphasize reusable procedures with defined inputs; commands emphasize durable project workflows.
- **Known failure modes:** a user-invoked slash name that matches both a skill and a command routes to the command. Plugin skills need the plugin to be installed (check `~/.claude/plugins/installed_plugins.json`).

### 10. MCP / plugin registry

- **Paths:**
  - `~/.claude/plugins/installed_plugins.json` — installed plugins registry (v2 format).
  - `~/.claude/plugins/known_marketplaces.json` — known marketplaces (currently: `claude-plugins-official` from anthropics/claude-plugins-official; `soundstripe-plugins` from SoundstripeEngineering/plugin-marketplace).
  - `~/.claude/plugins/blocklist.json` — host-managed plugin block list.
  - `~/.claude/plugins/cache/<marketplace>/<plugin>/<version>/` — extracted plugin contents.
  - `~/.claude/plugins/marketplaces/<name>/` — cloned marketplace repos.
  - `~/.claude/mcp-needs-auth-cache.json` — MCP server auth state.
- **Scope:** user-scope.
- **Lifecycle:** installed/removed via `claude mcp` CLI; marketplace repos pulled on refresh; cache is append-only per version.
- **Authoring:** host-managed; user triggers installs.
- **Invocation:** not directly invoked — the plugin's contents (agents, skills, commands, hooks) become available as tool surfaces after install.
- **Precedence:** project-scope tool definitions win over plugin-supplied ones of the same name.
- **Canonical usage:** distribute agents/skills/commands across projects or users via a marketplace; `blocklist.json` centrally blocks known-bad plugins.
- **Known failure modes:** plugin upgrades can change agent/skill signatures — callers may break silently. Marketplace pull failure leaves stale caches active.

### 11. Rules

- **Path:** `<repo>/.claude/rules/*.md` (10 files: analysis-methodology, dbt-standards, deliverable-standards, git-workflow, guardrails, lookml-standards, python-standards, roadmapping-methodology, sql-snowflake, writing-standards).
- **Scope:** project-scope. No user-scope rules directory.
- **Lifecycle:** static; tracked in git.
- **Authoring:** humans; agents draft rule changes in dedicated sessions.
- **Invocation:** auto-loaded into every conversation via `@.claude/rules/<file>.md` directives at the bottom of the root `CLAUDE.md`. Unlike directory-specific CLAUDE.md files, rule files ARE loaded at session start and persist for the entire session.
- **Precedence:** rules imported into the root CLAUDE.md form a single loaded namespace; a newly authored rule has no effect until it is imported from the root CLAUDE.md.
- **Canonical usage:** cross-cutting conventions that govern authoring, not specific procedures (procedures go in runbooks). Every rule file is stakeholder-facing prose; subject to the §10 Writing Scrub.
- **Known failure modes:** rule files not referenced from root CLAUDE.md are inert. Rule files exceeding ~50 lines lose readability; keep them tight. Contradictions between rules fail silently unless reviewed.

### 12. CLAUDE.md import chain

- **Path:** root `<repo>/CLAUDE.md` + one `CLAUDE.md` per managed subdirectory (106 files confirmed at 2026-04-20).
- **Scope:** project-scope.
- **Lifecycle:** static; tracked in git.
- **Authoring:** humans + agents; mandatory when creating any new subdirectory under a managed root.
- **Invocation:** root CLAUDE.md auto-loaded at session start. Per-directory CLAUDE.md is lazily loaded when the assistant navigates into that directory. The `@<path>` operator resolves imports recursively.
- **Precedence:** local CLAUDE.md rules do not override parent — they extend. Import chains must be walkable from any leaf up to the project root.
- **Canonical usage:** state the directory's purpose, chain to parent via `@../CLAUDE.md`, include directory-specific conventions. The chain provides the assistant continuous access to the governance context regardless of leaf depth.
- **Known failure modes:** a missing CLAUDE.md in a managed subdirectory silently breaks the rule chain. `session-gate.sh` enforces presence on any Write/Edit in managed dirs.

### 13. Keybindings

- **Path:** `~/.claude/keybindings.json` (absent on this host).
- **Scope:** user-scope.
- **Lifecycle:** created on first keybindings edit.
- **Authoring:** humans, via the `keybindings-help` skill.
- **Invocation:** config file read at host startup.
- **Precedence:** user-scope only.
- **Canonical usage:** customize chord bindings and shortcuts.
- **Known failure modes:** invalid JSON silently falls back to defaults.

### 14. Status-line config

- **Path:** `~/.claude/statusline.json` (absent on this host).
- **Scope:** user-scope.
- **Lifecycle:** created when status-line is customized.
- **Authoring:** humans, via the `statusline-setup` agent.
- **Invocation:** host reads on startup; status line displays per turn.
- **Precedence:** user-scope only.
- **Canonical usage:** customize the status-line content the host prints.
- **Known failure modes:** schema changes across host versions may silently reset.

### 15. Session log / user prompt history

- **Path:** `~/.claude/history.jsonl` (283934 bytes at 2026-04-20, mode `0600`).
- **Scope:** user-scope; cross-project.
- **Lifecycle:** append-only; no rotation observed.
- **Authoring:** host runtime, on every user prompt submit.
- **Invocation:** not directly invoked; queryable for prior-prompt analytics.
- **Precedence:** aggregate of all prompts; per-project transcripts (§2) carry the full conversation.
- **Canonical usage:** cross-project prompt pattern audits; reference when debugging "did I already try this approach?".
- **Known failure modes:** file grows unbounded; mode `0600` prevents cross-user leakage but contains PII from every project.

### Additional observed resources (supporting the 15)

| Path | Role | Lifecycle |
|---|---|---|
| `~/.claude/backups/` | Timestamped backups of `~/.claude.json` (the user-scope host config). Auto-created on host config writes. | Append-only; rotation unknown |
| `~/.claude/cache/` | General host cache | Transient |
| `~/.claude/chrome/` | Claude-in-chrome MCP server state | Refreshed on use |
| `~/.claude/debug/<session_id>.txt` + `latest` symlink | Per-session debug dump. Symlinked into this repo at `debug/` on 2026-04-20 for quick access. | Per-session |
| `~/.claude/file-history/<session_id>/<hash>@vN` | Versioned snapshots of every file Read or Edited by the assistant (undo buffer) | Persistent per-session |
| `~/.claude/ide/` | IDE integration state (JetBrains, VS Code); holds PID lock | Session-bound |
| `~/.claude/paste-cache/` | Paste buffer cache for large clipboards | Transient |
| `~/.claude/plans/<slug>.md` | Plan-mode output files (one per `ExitPlanMode` invocation); 20 files observed. | Persistent |
| `~/.claude/session-env/<session_id>/` | Per-session shell environment captures | Per-session |
| `~/.claude/sessions/<pid>.json` | Cross-session metadata | Persistent |
| `~/.claude/shell-snapshots/snapshot-zsh-<ts>-<slug>.sh` | Zsh snapshot the Bash tool re-sources | Per-bash-init |
| `~/.claude/statsig/` | Statsig SDK state (feature flags for Claude Code itself) | Host-managed |
| `~/.claude/stats-cache.json` | Host statistics cache | Persistent |
| `~/.claude/telemetry/` | Failed-event telemetry buffer. Substrate foundation for Epic 0.3 OpenTelemetry work. | Transient/flushed |

## Interaction adjacency (summary)

See `evolution/03-runtime-substrate-audit/inventory/phase2-interactions.md` for the full edge list. High-level groups:

- **Config → activation:** `settings.json` → hooks, rules, env.
- **Hook → state:** hooks write/read `/tmp/d7dev-hooks/<sid>/` marker files (`preflight_done`, `review_done`, `managed_write_count`, `edit_log`, `bash_log`, `charts_pending`).
- **Hook → context injection:** `prompt-context.sh` injects date, checkpoint age, memory staleness into every user prompt via `hookSpecificOutput.additionalContext`.
- **Hook → persistent log:** all hooks write crashes to `.claude/hooks/errors.log`; `health-check.sh` surfaces on SessionStart and rotates.
- **Root CLAUDE.md → rules:** `@.claude/rules/*.md` imports load rule files at session start.
- **Child CLAUDE.md → parent:** `@../CLAUDE.md` chain; lazy-loaded on directory navigation.
- **Assistant tools → user-scope state:** `TaskCreate`/`TaskUpdate` → `~/.claude/todos/`; `Agent` launches → `~/.claude/tasks/`; every Read/Edit → `~/.claude/file-history/`; every prompt submit → `~/.claude/history.jsonl` + per-project JSONL.
- **Plugin install → tool surface:** plugin cache population adds agents, skills, commands to available namespaces.

## Precedence rules (canonical)

1. **Settings merge:** project local > project tracked > user > host defaults. `permissions.allow` is a set-union across scopes.
2. **Memory key:** URL-encoded absolute project path; moving the project breaks continuity.
3. **CLAUDE.md loading:** root at session start; per-directory lazy-loaded on navigation; rule files auto-loaded via `@` imports from root.
4. **Tool name resolution:** project scope wins over plugin scope; for slash-invocations, command wins over skill wins over agent.
5. **Hook firing order:** declared order within a single event; exit 2 blocks and aborts later hooks for that event.
6. **Sub-agent dispatch:** project agents appear unnamespaced; plugin agents as `<plugin>:<name>`.

## Canonical usage patterns (decision tree)

Use this when adding a new capability, to pick the right resource:

1. **Stateful config across turns?** → rule file or CLAUDE.md (user-visible, governance-level).
2. **Per-session ephemeral state?** → `/tmp/d7dev-hooks/<sid>/` via `_lib.sh` helpers.
3. **Durable cross-session knowledge about the user or project?** → memory (`~/.claude/projects/<slug>/memory/<type>_<topic>.md`).
4. **Durable project knowledge shared with collaborators?** → `knowledge/` (runbooks, decisions, data-dictionary, domains) or `.claude/rules/`.
5. **Invocable via slash?** → `.claude/commands/` (command file) or `.claude/skills/` (skill). Use command when it's durable project workflow; use skill when it's a reusable procedure.
6. **Invocable via sub-agent dispatch?** → `.claude/agents/`.
7. **Reactive to tool use?** → `.claude/hooks/` + wire in `settings.json`.
8. **Cross-repo or cross-user?** → plugin (marketplace → install).

## Known failure modes (cross-reference to feedback memories)

| Failure | Memory |
|---|---|
| Hook edits mid-session disable the runner | `feedback_dont_edit_live_hooks.md` |
| `Stop` vs `SessionEnd` — per-turn vs per-session | `feedback_hook_events.md` |
| CLAUDE.md chain missing in new directories | `feedback_claude_md_chain.md` |
| `git add .` / `-A` prohibited; stage by name | `.claude/rules/git-workflow.md` + `bash-guard.sh` |
| `settings.local.json` silent accumulation masks missing project allowlist entries | Epic 0.2 target; rule not yet codified |
| Memory keyed by absolute path → moving project breaks continuity | Documented here; no memory entry |

## Troubleshooting

- **"Hook stopped firing mid-session."** Likely caused by mid-session edit to a hook script. Do not iterate further; start a fresh session and test via `bash -n <hook>.sh` and manual JSON-input piping before re-enabling.
- **"Canonical command triggers permission prompts."** `.claude/settings.json` allowlist is missing a Bash pattern. Either add the pattern to `settings.json` (durable) or accept the prompt once to land in `settings.local.json` (local-only fix — does not propagate to other users). Epic 0.2 is the durable fix.
- **"Memory file seems stale."** Read it — if `<system-reminder>` appears calling out age, update or remove. Verify against current code before asserting as fact.
- **"Plugin agent not available."** Check `~/.claude/plugins/installed_plugins.json` — plugin may not be installed. Use `claude mcp` to install from a known marketplace.
- **"Hook state not cleaning up."** `session-closeout.sh` (wired to `SessionEnd`) is the cleanup hook. Confirm it exists and does not error on SessionEnd. `SessionEnd` cannot block, so errors go to `errors.log` only.

## Host-version sensitivity

Every observation in this runbook is scoped to the host runtime version in effect at 2026-04-20. The host runtime is under active development. When the host updates:

1. Re-run the top-level `ls ~/.claude/` and `ls <repo>/.claude/` enumeration to detect new resources (e.g., OpenTelemetry collector paths when Epic 0.3 lands).
2. Re-verify the hook event names and firing semantics against the host changelog.
3. Re-verify settings merge precedence — assumption: project-local > project > user.

Update cadence: refresh this runbook on every host-runtime major upgrade, or quarterly, whichever comes first. Preserve the `Last updated` line at the top as the version stamp.

## Related

- `../../analytical-orchestration-framework.md` §1.4 (Runtime substrate) — the framework section this runbook satisfies.
- `../../evolution/GAP_ANALYSIS.md` — framework-vs-current-state audit that scoped this work.
- `../../evolution/03-runtime-substrate-audit/brief.md` — Epic 0.1 scope + phased approach.
- `../../evolution/03-runtime-substrate-audit/inventory/phase1-enumeration.md` — raw Phase 1 observations.
- `../../evolution/03-runtime-substrate-audit/inventory/phase2-interactions.md` — raw Phase 2 adjacency + precedence.
- `../../.claude/rules/guardrails.md` — CLAUDE.md chain guardrail enforced via `session-gate.sh`.
- `../../.claude/rules/git-workflow.md` — rule enforced via `bash-guard.sh`.
- Memory entries: `feedback_dont_edit_live_hooks.md`, `feedback_hook_events.md`, `feedback_claude_md_chain.md`.
- Downstream epics that consume this runbook: Epic 1.1 (hook lifecycle & safety), Epic 1.2 (unified session + event state substrate), Epic 0.3 (telemetry substrate).
