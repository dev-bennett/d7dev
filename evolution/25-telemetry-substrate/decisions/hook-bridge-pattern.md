# Decision — Hook → OTel bridge pattern

**Date:** 2026-04-20
**Status:** accepted
**Epic:** 0.3 (telemetry substrate)
**Phase:** 2

## Context
Claude Code's native OTel exporter emits spans, metrics, and logs for host-level activity (tool calls, session lifecycle, token usage, latency). Workspace hooks in `.claude/hooks/*.sh` emit structured JSONL to `.claude/hooks/session-log.jsonl` via `_lib.sh:log_event()`. For Epic 1.2 (unified session event log), Epic 2.3 (rule efficacy), and downstream corpus queries to treat both signals uniformly, hook events must land in the same pipeline as host events.

Bash hooks cannot emit OTel spans directly (no practical SDK, would require forking behavior into every hook). Three bridge patterns were considered in the brief:

**(a) Stdout shim.** Each hook prints an OTel-shaped structured line to stdout; host or a wrapper ingests.
**(b) Sidecar wrapper.** A wrapper script runs between host and each hook, emits spans around the hook's execution.
**(c) File tail.** Collector's filelog receiver tails `session-log.jsonl` directly; hook code unchanged.

## Decision
**Pattern (c) — filelog receiver tailing `session-log.jsonl`.**

## Rationale
1. **Zero hook-code changes.** `_lib.sh:log_event()` already writes a stable JSONL schema with fields (`ts`, `session`, `hook`, `tool`, `file`, `skill`, `outcome`, `elapsed_ms`, `extra`) that map cleanly to OTel log records. No churn in 8 hook scripts.
2. **Schema transform is declarative.** Collector operators (json_parser, add, move, severity_parser) handle field promotion and status mapping in one YAML file that lives alongside the collector config.
3. **Bridging is out-of-band.** Hooks write to file as they do today; the collector tails asynchronously. No latency added to hook execution; no fork cost; no new failure modes in the hook critical path.
4. **Storage checkpoint is first-class.** `file_storage` extension persists the tail position, so collector restarts do not re-ingest. `session-log.jsonl.prev` rotation is handled by the `include:` glob.
5. **Reversible.** If a better pattern emerges, hooks keep writing to `session-log.jsonl` regardless; only the collector config changes.

## Alternatives rejected

### Pattern (a) — stdout shim
- Requires modifying every hook script to emit a second structured line.
- Host would need a shim to capture the hook's stdout and route it to the collector — Claude Code does not expose a documented hook-stdout capture for this purpose.
- Redundant with the existing JSONL write path.

### Pattern (b) — sidecar wrapper
- Each hook binding in `settings.json` would need to change from `.claude/hooks/<name>.sh` to a wrapper script.
- Wrapper becomes an untested bridging layer sitting in the hook critical path (fork + exec cost per invocation).
- Adds 8+ permission-allowlist entries; brittle against future hook additions.
- Does not solve the schema-transform problem — the wrapper would still need to emit JSON the collector understands.

## Consequences
- **Positive:** Hook code stays pure shell; all telemetry complexity lives in `.claude/telemetry/otelcol-config.yaml`. Single source of truth for bridging. Pattern works identically for any future hook because hooks already share `_lib.sh:log_event()`.
- **Negative:** Hook events are routed through the filelog receiver specifically and appear in the `logs/hooks` pipeline, not the `logs/host` pipeline — downstream queries distinguish via `attributes.source` (`d7dev.hook` vs `d7dev.host`). Downstream epics must key on `session.id` for cross-stream joins, not on an OTel trace_id (hooks have no trace context to propagate).
- **Neutral:** Synthesized span semantics — hook JSONL is a point-in-time event with `elapsed_ms`, not a native span. We emit it as an OTel log record with severity (mapped from `outcome`), not as a span. Downstream queries compute duration from `elapsed_ms` explicitly. Epic 1.2 and 2.3 both work against log records.

## Revisit triggers
Re-evaluate this decision if any of the following hold:
- Claude Code adds a first-class hook-span emission path (e.g., hooks can directly post OTLP spans)
- `session-log.jsonl` volume causes filelog receiver to lag >60s behind current line
- A consumer epic (1.2 specifically) needs trace-context propagation between host spans and hook events (currently not needed — session.id join is sufficient)
- Scrubbing requirements can no longer be met at the collector (e.g., new sensitive field is written before scrubbing runs)

## Supersedes
_none_

## Superseded by
_none_
