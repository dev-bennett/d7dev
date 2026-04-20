# Tracker: 25-telemetry-substrate

## Current state
**Tier:** 0 (substrate & bootstrap hygiene)
**Epic:** 0.3
**Priority:** P1
**Complexity:** Medium (overall)
**Current phase:** all three phases complete
**Status:** complete
**Last touched:** 2026-04-20
**Blockers:** none.
**Next action:** none for this epic. Non-blocking follow-ups (scrub-scope tightening for hook `file` + host `user.email`, stop/start re-validation, warn/block severity mapping) enumerated in `verification/full-e2e.md` "Follow-ups carried forward". Downstream consumer epics (1.2, 2.3, 5.2, 6.8, 6.9) are now unblocked.

## Phase log
### Phase 1 — Enable + local console capture
- Start: 2026-04-20
- Complete: 2026-04-20 (closed via supersession by Phase 2 OTLP)
- Notes: Env block landed in `.claude/settings.json` (`CLAUDE_CODE_ENABLE_TELEMETRY=1` + `OTEL_{LOGS,METRICS,TRACES}_EXPORTER=console` + `OTEL_LOG_USER_PROMPTS=0` + `OTEL_METRIC_EXPORT_INTERVAL=60000`). Runbook scaffolded at `knowledge/runbooks/telemetry-substrate.md` with env-reference table and 4-signal checklist. Verification dir + `phase1-orient-spans.md` scaffold created. Policy-limits pre-check: passed.
- 2026-04-20 capture attempt (console): `verification/snapshot.txt` was populated with chat transcript rather than OTel stderr. Recorded as UNUSABLE in `verification/phase1-orient-spans.md` "Capture attempt log".
- 2026-04-20 closure: rather than retry console-stderr capture, Phase 2 (collector + OTLP) was stood up and settings flipped from `console` to `otlp`. The four signals are now captured at the collector file exporters. Coverage at closure: signals 2 + 3 observed; signal 4 satisfied via `claude_code.active_time.total` and hook `elapsed_ms`; signal 1 absent by design (host 2.1.114 emits no OTel traces). Host-emits inventory populated in `host-version-pin.md`.

### Phase 2 — Local collector + persistence + hook bridge
- Start: 2026-04-20
- Complete: 2026-04-20
- Notes: Collector installed (`brew install opentelemetry-collector-contrib`, version 0.150.1) and running under launchd (`com.d7dev.otelcol`). Both OTLP HTTP (`:4318`) and self-metrics (`:8888`) reachable. Settings env flipped from `console` to `otlp`. Hook-bridge POC evidence captured in `verification/phase2-hook-bridge-poc.md` — all functional acceptance checks PASS; two scrub-scope findings flagged for non-blocking follow-up (hook `file` attribute + host `user.email`). Full e2e walked in `verification/full-e2e.md` — 8 PASS, 1 DEFERRED (stop/start), 0 FAIL. Collector config hash `aa4cb6b4eca6b81cbee7ac6ab61e36daea92962d` pinned in `host-version-pin.md`. Host-emits schema finding: Claude Code 2.1.114 emits metrics + event logs but NO OTel traces; `spans.jsonl` is absent by design. Step 4 (host spans) and Step 10 (Epic 1.2 projection shape) were re-framed against `source=d7dev.host` log records with `event.name ∈ {user_prompt, api_request, tool_decision, tool_result}`. Cross-stream correlation on `session.id` verified for both resource-level (hook) and attribute-level (host) carriers.

### Phase 3 — Downstream consumption
- Start: 2026-04-20
- Complete: 2026-04-20
- Notes: Framework §1.4 amendment landed in `../../analytical-orchestration-framework.md` adding the host-version pinning operational rule. Consumer-brief sections added to all five downstream epics (02, 05, 07, 23, 24) with identically-structured "Telemetry substrate consumption (from Epic 0.3)" blocks naming stream, schema-agnostic keying, and host-version sensitivity. Schema-agnostic keying table + consumer query-pattern index appended to `telemetry-substrate.md`. `host-version-pin.md` populated with Claude Code 2.1.114 observed-emits (2026-04-20). Phase 2 substrate verified; downstream consumption path is therefore resting on a measured substrate, not a promised one. Consumers keying on `session.id` + `source` + `hook` + `event.name` are forward-portable across host upgrades per the schema-agnostic keying guidance.

## Decisions
- 2026-04-18 — User introduced this epic post-audit. Rationale: verification substrate is foundational; without it, downstream work rests on promise not measurement. Priority P1.
- 2026-04-18 — Local-only retention by default. External observability backend is out of scope.
- 2026-04-20 — Hook-bridge pattern: filelog tail on `session-log.jsonl` (pattern c). See `decisions/hook-bridge-pattern.md` for rationale and revisit triggers.
- 2026-04-20 — PII scrubbing posture: hash file paths (preserves uniqueness), delete prompt-content attributes, regex-scrub Bash commands for secret patterns. All scrubbing collector-side; no hook changes.
- 2026-04-20 — Launch mechanism: user-scope launchd plist (`~/Library/LaunchAgents/com.d7dev.otelcol.plist`). Manual invocation documented as debug fallback.
- 2026-04-20 — `session-log.jsonl` size-rotation (in `session-closeout.sh`) deferred to post-session follow-up per `feedback_dont_edit_live_hooks.md`. Current file volume is safe for months.
- 2026-04-20 — `.claude/settings.json` env flip from `console` to `otlp` committed after collector verified running (`nc -z 127.0.0.1 4318` passing; file exporters writing to `.claude/telemetry/data/`).
- 2026-04-20 — Host-emits schema: Claude Code 2.1.114 emits metrics + event logs only, not OTel traces. Traces pipeline retained defensively. Step 4/10 e2e checks re-framed to use `source=d7dev.host` log records in lieu of spans. Captured in `host-version-pin.md`.

## Related artifacts
- `.claude/settings.json` — env block (Phase 1 landed; OTLP flip pending Phase 2 verification)
- `.claude/telemetry/otelcol-config.yaml` — collector config
- `.claude/telemetry/com.d7dev.otelcol.plist.template` — launchd template
- `.gitignore` — excludes `data/`, `state/`, `collector.log`
- `knowledge/runbooks/telemetry-substrate.md` — runbook (Phase 1 + 2 + 3 sections)
- `knowledge/runbooks/telemetry-queries.md` — 7 jq query examples
- `decisions/hook-bridge-pattern.md` — pattern (c) decision record
- `host-version-pin.md` — host CLI version + observed-emits snapshot
- `verification/CLAUDE.md` — verification dir purpose
- `verification/phase1-orient-spans.md` — Phase 1 4-signal checklist (awaiting capture)
- `verification/phase2-hook-bridge-poc.md` — Phase 2 POC acceptance (awaiting run)
- `verification/full-e2e.md` — 10-step substrate verification (awaiting run)
- `../../analytical-orchestration-framework.md` §1.4 — host-version pinning rule
- Consumer briefs: `../02-unified-session-state-log/brief.md`, `../05-rule-efficacy-telemetry/brief.md`, `../07-agent-cost-dispatch/brief.md`, `../23-meta-retrospective/brief.md`, `../24-directive-efficacy-experiments/brief.md`

## Open action items
All original exit-gate items closed 2026-04-20. Remaining items are non-blocking follow-ups carried forward from `verification/full-e2e.md`:

1. Stop/start verification on next host-version re-pin (architectural posture in place via `file_storage` extension + filelog `start_at: end`; not exercised in initial capture window)
2. Scrub-scope: close hook `file` attribute gap — either rename hook emitter `file → file.path` in `.claude/hooks/_lib.sh` (preferred, aligns with OTel semconv) or add explicit scrub rule in `otelcol-config.yaml`
3. Scrub-scope: close host `user.email` gap — add `- key: user.email\n    action: delete` (or `hash`) to `attributes/scrub.actions` in `otelcol-config.yaml`
4. Severity-mapping verification for hook records with `outcome=warn|block` (not exercised in initial capture; confirm mapping at next occurrence)
5. Confirm `session-closeout` hook on session-exit path (not observed in initial capture window)

Items 2 and 3 are single-line config edits and can be bundled with a re-run of the scrubbing validation in `verification/full-e2e.md` step 7. They do not gate Epic 0.3 closure or any downstream consumer epic — local-only retention means the substrate meets its functional contract today.
