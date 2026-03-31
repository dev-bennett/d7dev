# Roadmapping Process Runbook

- **Last updated:** 2026-03-31
- **Author:** Devon Bennett (d7admin)

## Purpose

Codifies the 7-step roadmapping process used to take a domain initiative from ideation through executable epic project plans.

## Prerequisites

- Domain/topic identified
- Stakeholders identified and available for 2 live sessions
- FigJam (or equivalent) board access for brainstorming
- Asana access for epic/task tracking

## Process

### Step 1: Scope & Stakeholders

**Input:** A domain or initiative that needs a roadmap.
**Output:** Initiative Scope document (`analysis/_templates/initiative-scope.md`).

1. Define the domain, topic, or functional area being roadmapped
2. Identify all stakeholders (contributors, decision-makers, informed parties)
3. Identify who owns each subsequent step (analyst, PM, marketing lead, etc.)
4. Create the initiative scope document in the relevant `analysis/<domain>/` directory
5. Create or update the domain's `CLAUDE.md` to reflect "Step 1: Scoping"

### Step 2: Live Brainstorm

**Input:** Initiative scope, stakeholder list.
**Output:** FigJam board screenshot (PNG), raw idea inventory.

1. Prepare a FigJam board with high-level category columns relevant to the domain
2. Schedule a live session with stakeholders
3. All participants add sticky notes -- ideas, initiatives, models, triggers, etc.
4. Capture the completed board as a PNG
5. Commit the PNG to `analysis/<domain>/`
6. Update `CLAUDE.md` to reflect "Step 2: Brainstorm complete"

### Step 3: Group & Define

**Input:** Raw brainstorm output.
**Output:** Brainstorm consolidation document (`analysis/_templates/brainstorm-consolidation.md`).

1. Review all sticky notes from the brainstorm
2. Cluster related ideas into logical groupings
3. Name and describe each grouping
4. Identify cross-cutting themes that span multiple groups
5. Flag any ideas that need clarification or are out of scope
6. Document using the brainstorm consolidation template

### Step 4: Refine Swimlanes & Define Epics

**Input:** Grouped ideas from Step 3.
**Output:** Swimlane structure with named epics.

1. Choose swimlane framing appropriate to the domain:
   - Department-based (Marketing, Engineering, Product, etc.)
   - User-journey milestones (Acquire, Activate, Engage, Retain, etc.)
   - Capability-based (Infrastructure, Content, Measurement, etc.)
   - Time-horizon (Now, Next, Later)
2. Map grouped idea bundles into swimlanes as named epics
3. Write a 1-2 sentence scope statement for each epic
4. Identify dependencies between epics

### Step 5: Prioritize

**Input:** Swimlane/epic structure from Step 4.
**Output:** Priority-assigned epics (P1-P5).

1. Schedule a live session with stakeholders
2. Present each epic with its scope statement
3. Assign priority collaboratively:
   - **P1:** Immediate -- start now, high impact or blocking
   - **P2:** Near-term -- start within 1-2 months
   - **P3:** Mid-term -- plan for next quarter
   - **P4:** Future -- validated idea, not yet scheduled
   - **P5:** Backlog -- captured for reference, no commitment
4. Document rationale for priority assignments (especially P1/P2)
5. Identify any epics that need further scoping before prioritization

### Step 6: Roadmap Artifact

**Input:** Prioritized epics from Step 5.
**Output:** Roadmap flowchart + outline document (`analysis/_templates/roadmap-artifact.md`).

1. Create the canonical roadmap document
2. Organize epics by priority within swimlanes
3. Include: epic name, scope, priority, owner, dependencies, target timeline
4. Create a visual flowchart (Graphviz, FigJam, or Mermaid) showing sequencing
5. This document becomes the single source of truth for the initiative

### Step 7: Epic Project Plans

**Input:** Roadmap artifact from Step 6.
**Output:** Per-epic project plans (`analysis/_templates/epic-project-plan.md`).

1. For each P1/P2 epic, create a project plan
2. Break down into tasks, deliverables, milestones
3. Assign owners and target dates
4. Create corresponding Asana tasks/projects
5. Link back to the parent roadmap artifact

## Troubleshooting

- **Brainstorm produces too few ideas:** Pre-seed categories with example stickies; share context docs 24h before the session
- **Stakeholders can't agree on priority:** Use impact/effort scoring as a tiebreaker; escalate P1 conflicts to the domain owner
- **Epics are too large:** Apply the "can this be delivered in one quarter?" test; split if no
- **Roadmap goes stale:** Review and update during quarterly planning; archive completed epics

## Related

- `.claude/rules/roadmapping-methodology.md` -- Standards and conventions
- `analysis/_templates/initiative-scope.md` -- Step 1 template
- `analysis/_templates/brainstorm-consolidation.md` -- Step 3 template
- `analysis/_templates/roadmap-artifact.md` -- Step 6 template
- `analysis/_templates/epic-project-plan.md` -- Step 7 template
