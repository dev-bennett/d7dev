# Restructure Proposal - Talking Points

---

## The situation

- Geoff is leaving. Data team = Devon, solo.
- Two options: backfill the director role, or restructure.

## The idea

- Move data function from CFO org to Engineering (Luke -> Trevor)
- Title: Data Analyst -> Principal Analyst
- Geoff's departure means his responsibilities get absorbed. The question is how.
  - **To Luke:** escalation path, budget ownership, headcount decisions, technical oversight
  - **To Devon:** prioritization, stakeholder communication, project management, cross-departmental coordination
- This is a role expansion that's happening regardless. The proposal formalizes it with the right reporting line and title.

## Why not backfill

- Director salary for managing one person
- 3-6 month search + ramp on a stack they didn't build
- During that entire period, Devon operates independently — proving the proposed model already works

## Why Engineering

- The work is largely infrastructure: Stitch, dbt, Snowflake, Looker, Polytomic
- Luke's team already manages everything else system-related
- Shared operational concerns: deployments, uptime, version control, incident response
- Direct integration points: Polytomic syncs to production systems, Stitch pulls from systems Engineering manages
- Technical decisions need technical oversight — tooling, architecture, debt prioritization

## Why Principal Analyst (not Data Analyst, not Data Engineer)

- Absorbing director-level responsibilities: prioritization, stakeholder communication, project management
- Existing scope already spans: data engineering, analytics engineering, BI development, reporting, data ops
- "Analyst" keeps the analytical function front and center (vs. "Engineer" which loses the reporting/analysis side)
- "Principal" reflects independent ownership of a function, including the operational judgment that Geoff previously handled

## What Sourav gains

- Saves a director-level salary
- Removes a technical management burden that isn't core to Finance
- Same analytical service, no interruption
- Better oversight — managed by someone who can evaluate the methods, not just the outputs

## Anticipated questions

**"Why can't you just report to me directly?"**
Can. But a CFO managing a solo technical infrastructure role isn't a natural fit. The work looks more like what Luke's team does than what Finance does.

**"What if we want to grow the data team later?"**
Engineering has hiring frameworks, code review processes, and development standards that apply directly. Growing a data team under Finance would mean building all of that from scratch.

**"Does Luke want this?"**
TBD - haven't discussed this with him yet.

**"How does all of this get done with one person?"**
Geoff is a major technical contributor — this isn't just losing a manager. There's a real capacity gap. That's exactly why I've been building d7dev: a platform that systematizes and automates the operational side of the data function — ETL workflows, validation, knowledge base, automated checks. It's designed specifically to bridge that gap. Not finished yet, but the foundation is in place and the roadmap targets the areas where the gap is largest. Happy to walk through it.

**"What changes day one?"**
Nothing operational. Reporting line moves. Everything else continues.
