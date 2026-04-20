# Command → Tool-Call Matrix

**Epic:** 0.2 — Zero-prompt contract audit
**Phase:** 2 deliverable
**Last updated:** 2026-04-20
**Audit scope:** `.claude/commands/*.md` vs `.claude/settings.json` `permissions.allow` (union with `.claude/settings.local.json` and `~/.claude/settings.json` is computed by the audit script in Phase 3; this matrix only reconciles against the propagatable project-scope allowlist).

## How to read

- **Tool class** — `Read`, `Glob`, `Grep`, `Write`, `Edit`, `Bash(<cmd>:*)`, etc. Matches the permission-entry syntax from `knowledge/runbooks/runtime-substrate-catalog.md` §5.
- **Explicit?** — `Y` if the command file literally names the tool or bash command. `N` if the assistant would typically invoke it as a natural side-effect (e.g., reading a file referenced in the command spec).
- **Covered?** — `Y` if the project-scope `settings.json` allowlist covers the pattern after Phase 1 + Phase 2 edits. `N` means gap to close.

## Summary

All 16 commands pass; every tool call each command issues is covered by the project-scope allowlist after this audit. The three additions from Phase 2 (`Bash(rm:*)`, `Bash(mv:*)`, `Bash(cp:*)`) close the `/ingest` directory-clear and `/evolve` orphan-cleanup gaps.

Conservative over-approximation applies to dynamic patterns where `$ARGUMENTS` interpolates into paths (`/roadmap`, `/scaffold`, `/analyze`): bare `Write` covers these.

## Matrix

### 1. `/analyze <domain>`
| Tool class | Explicit? | Covered? | Notes |
|---|---|---|---|
| `Read` | Y | Y | knowledge/, context/dbt/, context/lookml/, analysis/_templates/ |
| `Glob` | N | Y | knowledge/ and context/ surface probe |
| `Grep` | N | Y | lineage discovery |
| `Write` | Y | Y | `analysis/<domain>/<YYYY-MM-DD>-<slug>.md`, `analysis/<domain>/checkpoint.md` |
| `Edit` | Y | Y | checkpoint updates |
| `Bash(git:*)` | Y | Y | stage output file |

### 2. `/checkpoint [init|update|review]`
| Tool class | Explicit? | Covered? | Notes |
|---|---|---|---|
| `Read` | Y | Y | `analysis/<domain>/checkpoint.md`, template |
| `Write` | Y | Y | checkpoint init |
| `Edit` | Y | Y | checkpoint update |
| `Bash(git:*)` | Y | Y | stage checkpoint |

### 3. `/etl <action>`
| Tool class | Explicit? | Covered? | Notes |
|---|---|---|---|
| `Read` | Y | Y | context/dbt/ models + lineage |
| `Glob` | N | Y | lineage probe |
| `Write` | Y | Y | `etl/sql/<layer>/`, `etl/quality/`, `etl/pipelines/` |
| `Edit` | Y | Y | transform edits |
| `Bash(git:*)` | Y | Y | stage files |

### 4. `/evolve [scope]`
| Tool class | Explicit? | Covered? | Notes |
|---|---|---|---|
| `Read` | Y | Y | rules, commands, memory, knowledge/, session transcripts |
| `Glob` | Y | Y | `**/CLAUDE.md`, `.claude/rules/*.md`, `.claude/commands/*.md`, memory/ |
| `Grep` | N | Y | pattern detection across session artifacts |
| `Write` | Y | Y | `analysis/data-health/YYYY-MM-DD-session-retrospective.md`, MEMORY.md index, new memory files, new rule/command files |
| `Edit` | Y | Y | rules, commands, CLAUDE.md files |
| `Bash(ls:*)` | Y | Y | inventory walks |
| `Bash(git:*)` | N | Y | status checks |
| `Bash(rm:*)` | Y | **Y (Phase 2)** | orphaned-file cleanup per Phase 4 step 6 (with user confirmation per guardrails) |

### 5. `/ingest <repo-type>`
| Tool class | Explicit? | Covered? | Notes |
|---|---|---|---|
| `Read` | Y | Y | existing MANIFEST.md |
| `Write` | Y | Y | `context/<repo-type>/MANIFEST.md` |
| `Bash(tar:*)` | Y | Y | `.tar.gz` extraction |
| `Bash(unzip:*)` | Y | Y | `.zip` extraction |
| `Bash(ls:*)` | Y | Y | post-extraction inventory |
| `Bash(rm:*)` | Y | **Y (Phase 2)** | "Clear the target directory (preserve .gitkeep)" step 4 |
| `Bash(git:*)` | Y | Y | stage ingested files |

### 6. `/kb-update <topic>`
| Tool class | Explicit? | Covered? | Notes |
|---|---|---|---|
| `Read` | Y | Y | existing articles |
| `Glob` | Y | Y | `knowledge/` search |
| `Grep` | Y | Y | topic search across KB |
| `Write` | Y | Y | `knowledge/domains/`, `knowledge/data-dictionary/`, `knowledge/runbooks/`, `knowledge/decisions/` |
| `Edit` | Y | Y | article updates |
| `Bash(git:*)` | Y | Y | stage |

### 7. `/lookml <action>`
| Tool class | Explicit? | Covered? | Notes |
|---|---|---|---|
| `Read` | Y | Y | context/lookml/, knowledge/data-dictionary/, context/dbt/ |
| `Glob` | N | Y | view/explore discovery |
| `Write` | Y | Y | `lookml/views/*.view.lkml`, `lookml/explores/*.explore.lkml`, `lookml/dashboards/*.dashboard.lkml`, `lookml/models/*.model.lkml`, `lookml/tests/` |
| `Edit` | Y | Y | LookML edits |
| `Bash(git:*)` | Y | Y | stage |

### 8. `/model <domain>`
| Tool class | Explicit? | Covered? | Notes |
|---|---|---|---|
| `Read` | Y | Y | knowledge/, context/dbt/, analysis/_templates/business-model.md |
| `Glob` | N | Y | domain surface probe |
| `Write` | Y | Y | `analysis/<domain>/<YYYY-MM-DD>-model-<slug>.md`, data-dictionary drafts |
| `Edit` | Y | Y | iterative model refinement |
| `Bash(git:*)` | Y | Y | stage |

### 9. `/monitor`
| Tool class | Explicit? | Covered? | Notes |
|---|---|---|---|
| `Read` | Y | Y | `etl/quality/`, `context/dbt/`, `knowledge/data-dictionary/` |
| `Glob` | N | Y | quality-check discovery |
| `Write` | Y | Y | `analysis/_monitoring/YYYY-MM-DD-monitor.md` |
| `Edit` | N | Y | iterative updates |
| `Bash(git:*)` | N | Y | stage |

### 10. `/orient`
| Tool class | Explicit? | Covered? | Notes |
|---|---|---|---|
| `Read` | Y | Y | rules, commands, agent_directives_v3, memory, settings, hooks, root CLAUDE.md |
| `Glob` | Y | Y | `**/CLAUDE.md`, `.claude/agents/*.md`, memory/ |
| `Write` | Y | Y | `.claude/hooks/session-briefing.md` (Phase 4) |
| `Bash(git:*)` | Y | Y | rev-parse, status, log, submodule |
| `Bash(ls:*)` | Y | Y | memory enum, task-dir enum, retrospective sort |
| `Bash(date:*)` | Y | Y | checkpoint age |
| `Bash(head:*)` | Y | Y | pipeline tail (e.g., `ls -t ... \| head -1`) |

### 11. `/preflight [task]`
| Tool class | Explicit? | Covered? | Notes |
|---|---|---|---|
| `Read` | Y | Y | rule files, existing view/source files, KB |
| `Glob` | Y | Y | `analysis/**/*<topic-slug>*` (dynamic slug via `$ARGUMENTS`) |
| `Grep` | Y | Y | metric/channel/pipeline name scan |
| `Bash(ls:*)` | Y | Y | `etl/tasks/`, `analysis/`, `initiatives/`, target marts/, transformations/ |
| `Write` | Y | Y | task-dir setup + CLAUDE.md |

### 12. `/review`
| Tool class | Explicit? | Covered? | Notes |
|---|---|---|---|
| `Read` | Y | Y | changed files of all types |
| `Bash(git:*)` | Y | Y | `git diff`, `git diff --cached` |

### 13. `/roadmap <domain>`
| Tool class | Explicit? | Covered? | Notes |
|---|---|---|---|
| `Read` | Y | Y | `analysis/$ARGUMENTS/CLAUDE.md`, template files, brainstorm artifacts |
| `Write` | Y | Y | `analysis/$ARGUMENTS/CLAUDE.md`, roadmap artifact, epic plans, scope doc |
| `Edit` | Y | Y | incremental step updates |
| `Bash(git:*)` | Y | Y | stage |
| *Graphviz/Mermaid CLI* | N | N | Step 20 mentions "Generate a visual flowchart (Graphviz or Mermaid)" but defers the generator choice. No bash binary named in the command. If `dot` or `mmdc` is invoked in a future run it will prompt; accepted deferral (conservative over-approx per brief). |

### 14. `/scaffold <domain>`
| Tool class | Explicit? | Covered? | Notes |
|---|---|---|---|
| `Read` | Y | Y | `context/dbt/` model discovery |
| `Glob` | Y | Y | `analysis/*/CLAUDE.md` initiative-link check |
| `Grep` | N | Y | initiative reference scan |
| `Write` | Y | Y | `analysis/$ARGUMENTS/README.md`, `knowledge/domains/$ARGUMENTS/{overview,metrics}.md`, `lookml/views/<model>.view.lkml`, `etl/quality/$ARGUMENTS-quality.sql`, `knowledge/data-dictionary/` |
| `Edit` | Y | Y | data-dictionary updates |
| `Bash(git:*)` | Y | Y | stage |
| `Bash(cp:*)` | N | **Y (Phase 2)** | defensive — scaffold templating may copy template skeletons |

### 15. `/status`
| Tool class | Explicit? | Covered? | Notes |
|---|---|---|---|
| `Read` | Y | Y | MANIFEST.md × 2, `analysis/*/CLAUDE.md`, KB articles |
| `Glob` | N | Y | domain × coverage matrix |
| `Bash(git:*)` | Y | Y | `git status` |
| `Bash(ls:*)` | Y | Y | inventory across analysis/, lookml/, etl/, knowledge/, scripts/, tests/ |
| `Bash(date:*)` | N | Y | staleness math |

### 16. `/test [args]`
| Tool class | Explicit? | Covered? | Notes |
|---|---|---|---|
| `Read` | Y | Y | `.sql`, `.lkml`, `.md` source |
| `Glob` | Y | Y | file discovery per step |
| `Grep` | Y | Y | broken cross-ref detection, hardcoded table patterns |
| `Bash(pytest:*)` | Y | Y | step 1 |
| `Bash(python:*)` / `Bash(python3:*)` | N (Phase 3) | Y | Phase 3 will wire step 5 `python scripts/audit_command_permissions.py --check` |

## Inter-command invocations

No command invokes another via the `Skill` or slash-command-call mechanism. `/analyze` step 21 says "flag for `/kb-update`" — this is verbal routing, not programmatic invocation. No audit-propagation risk.

## Dynamic patterns

Three commands interpolate `$ARGUMENTS` into paths: `/analyze`, `/model`, `/scaffold`, `/roadmap`. Because `Write` and `Edit` are bare-allowed, no path-shape mismatch can trigger a prompt. The `Glob` patterns (`analysis/**/*<topic-slug>*`) are covered by bare `Glob`.

## Residual known gaps (accepted)

1. `/roadmap` step 20 may eventually call `dot` (Graphviz) or `mmdc` (Mermaid CLI). Neither is allowlisted. If the user opts for visual flowchart generation in a future `/roadmap` run, a one-time prompt will land. Accepted per brief Phase-1 guidance ("conservative over-approximation").
2. Plugin-sourced slash commands (marketing:*, loop, schedule, etc.) are out of scope — this audit covers only the 16 canonical project-scope commands enumerated in `knowledge/runbooks/runtime-substrate-catalog.md` §6.
