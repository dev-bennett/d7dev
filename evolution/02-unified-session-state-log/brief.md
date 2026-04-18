# Project 02: Unified session state log

## Overview
Hook state currently lives in scattered per-marker files under `/tmp/d7dev-hooks/<session-id>/` — `preflight_done`, `review_done`, `managed_write_count`, `edit_log`, `bash_log`, `charts_pending`, `charts_verified`. Each hook reads and writes its own files. The layout is fragile (markers can desync), invisible to retrospective analysis, and is not available at session end for summary emission. With Epic 0.3 (OTel substrate) in place, the consolidated substrate is the collector's span/metric/log stream; this project's event log is a JSONL projection of that stream, with hook events bridged into OTel via the pattern chosen in Epic 0.3 Phase 2 (stdout/filelog/sidecar).

## Dependencies on Epic 0.3 (must land first)
- Inherits the local-only PII retention constraint. Any JSONL projection this project produces must live under the same local boundary — no sync or backup crossing.
- Consumes the host-emitted OTel schema; subject to the version-pinning requirement documented in Epic 0.3. Queries are schema-agnostic where possible.
- Uses the hook-bridge pattern selected in Epic 0.3 Phase 2 to route hook events into the stream. Hook migration must wait for Epic 0.3 Phase 2 to conclude before migrating individual hooks.

## Linked framework section
`../../analytical-orchestration-framework.md` §4.3 (Hooks — Unified session state)

## End goal
A `.claude/state/sessions/<session-id>.jsonl` file exists per session. Every hook invocation appends one structured event. `/orient` and `/evolve` compute their outputs by reducing the log. SessionEnd rotates the log to a retrospective corpus. Verified by:

1. Every existing hook emits structured events instead of writing per-marker files
2. `/orient` produces the same routing and queue outputs reading from the log as it does today from scattered files
3. SessionEnd rolls the active log to `.claude/state/history/<date>/<session-id>.jsonl` (or equivalent retention scheme)

## Phased approach

### Phase 1 — Event schema design
**Complexity:** Low
**Exit criteria:** `evolution/02-unified-session-state-log/schema.md` documents the event types (tool_call_pre, tool_call_post, skill_invocation, marker_set, warning_emitted, error_logged, session_start, session_end) and their required fields.
**Steps:**
- Inventory every marker / state file currently written by hooks
- Design event schema with common fields (ts, hook, session_id, event_type) + event-specific payloads
- Document migration map from current state files to new event types

### Phase 2 — Hook migration
**Complexity:** Medium
**Exit criteria:** Each of `_lib.sh`, `session-gate.sh`, `bash-guard.sh`, `retry-guard.sh`, `workflow-tracker.sh`, `writing-scrub.sh`, `session-closeout.sh` writes structured events to the log. Per-marker files removed or kept only as transitional mirrors.
**Steps:**
- Add `append_event()` helper to `_lib.sh`
- Migrate each hook one at a time, each behind a flag
- Verify parity between old state and new event log for one session
- Remove transitional mirrors
- Follow `feedback_dont_edit_live_hooks.md`: apply edits at session boundaries

### Phase 3 — /orient and /evolve consume the log
**Complexity:** Medium
**Exit criteria:** /orient phases 2–4 read only from the log; /evolve phase 1 (friction detection) reads from the log; per-marker files are fully deprecated.
**Steps:**
- Rewrite /orient state-gathering to reduce from log
- Rewrite /evolve detect phase to consume log
- SessionEnd rotates log to history directory
- Update retrospective corpus to index rotated logs

## Dependencies
- Project 06 (hook-edit guard) should land before major hook edits to prevent mid-session hook-runner disable

## Risks
- Event schema churn during migration → pin schema version in each event; handle backward-compatible reads in /orient
- Log file size growth over long sessions → rotation on size threshold, not just session end
