# Host-version pin — Epic 0.3 telemetry substrate

**Epic:** 0.3 (telemetry substrate)
**Linked framework:** `../../analytical-orchestration-framework.md` §1.4
**Runbook:** `../../knowledge/runbooks/telemetry-substrate.md`

## Purpose
Records the Claude Code CLI version against which the collector config at `.claude/telemetry/otelcol-config.yaml` was validated. OTel span names, metric names, log record types, and attribute shapes are host-versioned: a host upgrade may shift them without notice. This file is the operational gate for host upgrades.

## Current pin

| Field | Value |
|---|---|
| Claude Code CLI version | 2.1.114 (Claude Code) |
| Assistant model at validation | claude-opus-4-7 (1M context) |
| Validation date | 2026-04-20 |
| Collector version | otelcol-contrib 0.150.1 |
| Collector config hash | aa4cb6b4eca6b81cbee7ac6ab61e36daea92962d |

## Observed host-emits (captured 2026-04-20)

Snapshot captured from `.claude/telemetry/data/logs.jsonl` + `metrics.jsonl` after collector came up and the settings env-block was flipped from `console` to `otlp`. Claude Code CLI 2.1.114 emits two signal families natively: **metrics** and **event logs** (no OTel traces). Host-side activity flows as log records with `source=d7dev.host` rather than as spans. This shifts downstream query patterns — consumers key on logs, not spans, for host events.

### Span names
None. Claude Code 2.1.114 does not emit OTel traces. `.claude/telemetry/data/spans.jsonl` therefore does not exist. Traces pipeline in `otelcol-config.yaml` is retained defensively in case a future host release begins emitting them.

### Metric names
Scope: `com.anthropic.claude_code` (version 2.1.114).
- `claude_code.session.count` (Sum, monotonic)
- `claude_code.cost.usage` (Sum, unit=USD, per-model)
- `claude_code.token.usage` (Sum, unit=tokens, type ∈ {input, output, cacheRead, cacheCreation}, per-model)
- `claude_code.active_time.total` (Sum, unit=s, type ∈ {user, cli})

### Log record types
- `source=d7dev.host` — Claude Code native event logs. Event discriminator is `event.name` ∈ {`user_prompt`, `api_request`, `tool_decision`, `tool_result`} observed on 2026-04-20; additional event names may appear as the observation window widens.
- `source=d7dev.hook` — workspace hook bridge records (via filelog tail on `session-log.jsonl`). Hook discriminator is `hook` ∈ {`bash-guard`, `health-check`, `prompt-context`, `retry-guard`, `session-closeout`, `session-gate`, `workflow-tracker`, `writing-scrub`}.
- `source=config` — collector boot/config messages.

### Stable attribute keys (used for downstream joins)
- `session.id` — on resource attrs (both host + hook streams). **Stable.**
- `service.name` — `claude-code` on host stream. **Stable.**
- `service.version` — host CLI semver. **Host-versioned** (triggers re-pin on drift).
- `source` — workspace-authored discriminator (`d7dev.host` / `d7dev.hook` / `config`). **Stable.**
- `hook` — workspace-authored hook name on `d7dev.hook` records. **Stable.**
- `outcome` — workspace-authored (`pass` / `warn` / `block`) on hook records. **Stable.**
- `schema.version` — workspace-applied via `transform/schema_version` processor. Current value `0.3.0`. **Stable** (workspace controls this).
- `type` — token-type discriminator on `claude_code.token.usage` (`input` / `output` / `cacheRead` / `cacheCreation`). **Host-versioned.**
- `model` — model name on cost/token metrics. **Host-versioned** format (e.g., `claude-opus-4-7[1m]`, `claude-haiku-4-5-20251001`).

## Re-validation checklist (run on host upgrade)

When `claude --version` differs from the pin above:

1. [ ] Capture pre-upgrade state: copy current `verification/phase1-orient-spans.md` to `verification/phase1-orient-spans.<old-version>.md`
2. [ ] Upgrade Claude Code CLI
3. [ ] Restart session; invoke `/orient`; capture new console span output
4. [ ] Diff span/metric/log names against the pin's "Observed host-emits" section
5. [ ] If any name changed: update collector config (`filelog` operators, scrubbing rules) AND any downstream consumer query that was not written schema-agnostically
6. [ ] If attribute shapes changed: update scrubbing actions in `otelcol-config.yaml`
7. [ ] Re-run full e2e verification (`verification/full-e2e.md`)
8. [ ] Update this pin file — new version, new date, new observed-emits table, new config hash
9. [ ] Commit with message `telemetry: re-pin to claude-code <new-version>`

## Schema-agnostic query practice
Downstream consumer epics (1.2, 2.3, 5.2, 6.8, 6.9) must prefer keying on:
- `resource["session.id"]` — workspace-stable
- `attributes.source` — workspace-stable (`d7dev.hook` vs `d7dev.host`)
- `attributes["rule.id"]` (Epic 2.3) — workspace-authored
- `attributes["directive.variant"]` (Epic 6.9) — workspace-authored

Over exact span/metric/log names which are host-versioned. When a consumer must key on a host-versioned name, it cites this file and lists the keyed-upon names; re-pin triggers downstream query review.

## Related
- `decisions/hook-bridge-pattern.md` — why hook events join through filelog and carry `source=d7dev.hook`
- `../../analytical-orchestration-framework.md` §1.4 — framework rule that gates host upgrades on this file
