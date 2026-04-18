# Step 3 — Group & Define

The 53 raw ideas from Step 2 cluster into 12 thematic groups. Each group carries a scope statement and its member ideas by id. Groups are not yet epics — Step 4 promotes them into swimlanes and epics with explicit scope statements.

## Group definitions

### G1. Substrate catalog & host recognition
**Scope:** Formally recognize and document the host runtime and its capabilities that the framework depends on.
**Members:** I13, I15, I21, I53

### G2. Zero-prompt & command integrity
**Scope:** Every canonical command runs without permission prompts; bash and tool-call surface is auditable.
**Members:** I22, I29

### G3. Hook lifecycle & safety
**Scope:** Hooks are safe to evolve and impossible to disable mid-session; retry detection is reliable.
**Members:** I27, I28

### G4. Unified session & event state
**Scope:** All hook state, command outcomes, and lifecycle events flow through one append-only event log per session; `/orient` and `/evolve` reduce the log; lifecycle commands (`/preflight`, `/evolve`) auto-invoke at the appropriate boundaries.
**Members:** I23, I26, I30, I54

### G5. Directive artifact machinery
**Scope:** §-blocks are structurally verifiable, delivery-gated where appropriate, and semantically challenged.
**Members:** I14, I17, I18, I48, I50, I51, I52

### G6. Rule lifecycle & telemetry
**Scope:** Rules carry metadata, accumulate efficacy counters, and evolve toward deprecation, strengthening, or migration to hooks.
**Members:** I19, I20, I08

### G7. Memory decay & promotion
**Scope:** Memory files are decay-aware; stale items surface automatically; feedback memories migrate to rules on recurrence.
**Members:** I31, I32, I33, I34, I35, I36

### G8. Session-transcript corpus access
**Scope:** Session transcripts are a first-class substrate accessible to background processes for replay, drift detection, memory citation counting, and meta-retrospection.
**Members:** I37

### G9. Workspace contract & hygiene
**Scope:** Task directories carry structured status; query files carry structured metadata; scratch and exploratory work are separated.
**Members:** I16, I38, I39, I40, I41, I42, I49

### G10. Knowledge & reference substrate
**Scope:** Knowledge writes are discovery-gated; cross-references are validated; references carry manifest + staleness signals; a knowledge graph backs the markdown surface.
**Members:** I43, I44, I45, I46, I04

### G11. Orchestration intelligence
**Scope:** Agent dispatch is cost-aware; prior-investigation search is enforced; hypothesis pursuit is parallelized; directive critique is semantic not syntactic.
**Members:** I24, I25, I47, I02, I01

### G12. Corpus intelligence & self-evolution
**Scope:** The system reads its own corpus — findings, transcripts, retrospectives — to detect drift, replay adversarially, track interventions, model stakeholders, and test directive variants.
**Members:** I07, I05, I06, I10, I11, I12, I03, I09

### G13. Telemetry substrate (OpenTelemetry)
**Scope:** Enable structured tracing/metrics/logs from the host runtime itself via OpenTelemetry (`CLAUDE_CODE_ENABLE_TELEMETRY` + OTLP exporters). This is the verification surface that downstream measurement epics (G4 event state, G6 rule efficacy, G11 cost-aware dispatch, G12 corpus intelligence) consume as their primary substrate. Without it, every claim about system behavior depends on transcript reading and trust.
**Members:** I55

## Coverage check
Every I01–I55 appears in exactly one group. No orphans. Some groups are 1-member (G8, G13 — standalone infrastructure concerns); some are large (G12 — corpus-level capabilities share substrate).

## Emergent coverage (not assigned to a group)
Two items from GAP_ANALYSIS §12 (Epistemic discipline enforcement; Memory discipline mid-session update) are emergent properties satisfied by multiple groups, not standalone items. They are not assigned to a discrete group; coverage is achieved through:
- **Epistemic discipline** — G5 (directive machinery), G8 (corpus access), G11 (semantic critic + prior-investigation)
- **Memory discipline** — G7 (decay & promotion)

## Out of scope
- Half-registered `context/lookml` submodule (GAP_ANALYSIS §8 PARTIAL) — operational cleanup, tracked in `project_commit_backlog.md` memory, not a framework project.
