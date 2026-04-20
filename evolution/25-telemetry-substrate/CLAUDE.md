# Project 25: Telemetry substrate (OpenTelemetry)

@../CLAUDE.md

## Project purpose
Enable `CLAUDE_CODE_ENABLE_TELEMETRY` and stand up a local OTLP collector so every tool call, session event, token usage, and latency is captured as a structured span/metric/log. Provides the verification substrate that downstream measurement epics consume.

## Linked framework section
§1.4 (Runtime substrate — observability layer). User-introduced addition post-roadmap-audit.

## Linked epic
Epic 0.3 (Swimlane 0, P1)

## Files
- `brief.md` — overview + phased approach + risks
- `tracker.md` — phase log + decisions + open action items
- `close-out.md` — gated, copy-paste-able steps to drive Phase 1/2/3 validation to completion
- `host-version-pin.md` — Claude Code CLI version + observed host-emits; re-validation checklist
- `decisions/` — load-bearing decision records (hook-bridge pattern, …)
- `verification/` — phase-gate acceptance artifacts (`phase1-orient-spans.md`, `phase2-hook-bridge-poc.md`, `full-e2e.md`)
