# Current Subscriber Lifecycle Analysis

@../CLAUDE.md

Deep-dive analysis on the current subscriber segment for retention and upsell lifecycle email flows.

## Structure

- `CONTEXT.md` -- Original Asana task context and status log
- `agent_directives_v3.md` -- Governing analytical directives
- `enrichment_flows.png` -- Reference Figma board (structural template)
- `Subscriber - Lifecycle Email Flow.png` -- Final lifecycle flow diagram
- `v1_proposal/` -- MVP proposal: 5 segments, per-plan sizing, flow diagrams
- `retention_sizing/` -- Ramp-up retention model (initial deployment phase)
- `evergreen/` -- Continuous enrollment design (phase 2)

## Segment Model

5 mutually exclusive segments based on session recency + download activity:

1. **Active Downloader** -- Session in 30d + 1+ downloads
2. **Active Browser** -- Session in 30d + 0 downloads
3. **Early Lapse** -- No session 31-60d
4. **Deep Lapse** -- No session 61-180d
5. **Dormant** -- No session 180+ days or never

## Status

- V1 proposal, ramp-up model, and evergreen design are complete
- This work feeds into the broader lifecycle email program (see parent CLAUDE.md)
- Next steps are owned by Marketing (Dave) for roadmapping
