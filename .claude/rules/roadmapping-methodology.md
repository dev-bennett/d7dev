# Roadmapping Methodology

## 7-Step Roadmapping Process

All initiative roadmapping follows this sequence. Do not skip steps.

### Step 1: Scope & Stakeholders
- Define the roadmapping domain/topic/scope
- Identify stakeholders and decision-makers
- Document in an Initiative Scope (use `analysis/_templates/initiative-scope.md`)

### Step 2: Live Brainstorm
- Meet with stakeholders using a templated FigJam board
- Board includes high-level categories for the domain
- All participants add sticky notes with ideas
- Capture the board as a PNG artifact in the relevant `analysis/<domain>/` directory

### Step 3: Group & Define
- Cluster brainstorm ideas into logical groupings
- Define each grouping with a clear label and description
- Use `analysis/_templates/brainstorm-consolidation.md` to document

### Step 4: Refine Swimlanes & Define Epics
- Redefine high-level swimlanes based on context (department-based, user-journey milestones, etc.)
- Place grouped idea bundles into swimlanes as named epics
- Use `analysis/_templates/roadmap-artifact.md` for the swimlane structure

### Step 5: Prioritize
- Meet with stakeholders to assign priority (P1-P5) per epic
- P1 = immediate/critical, P5 = backlog/future consideration
- Document rationale for priority assignments

### Step 6: Roadmap Artifact
- Transfer to a streamlined roadmap flowchart + outline document
- This becomes the canonical reference for tracking epics
- Store in `analysis/<domain>/` alongside the analysis work

### Step 7: Epic Project Plans
- Each epic gets its own project plan
- Plans include: tasks, deliverables, milestones, subtasks
- Use `analysis/_templates/epic-project-plan.md` as template

## Conventions

- Roadmapping is upstream of analysis -- it determines what gets analyzed and built
- Each initiative's `CLAUDE.md` should track which roadmapping step it's on
- Ownership transitions (e.g., analyst -> marketing) must be documented with name and date
- Brainstorm artifacts (FigJam PNGs) are committed alongside analysis outputs
- Priority assignments (P1-P5) drive sequencing of analytical and engineering work