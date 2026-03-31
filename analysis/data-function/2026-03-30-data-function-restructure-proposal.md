# Proposal: Data Function Reporting Realignment

**Date:** 2026-03-30
**Author:** Devon
**Audience:** Sourav (CFO)
**Status:** Draft

---

## Executive Summary

With Geoff's departure, the data function requires a new reporting structure. There are two paths: backfill the Director of Data role under Finance, or realign the function to where the work naturally fits. I'm proposing the second path — move the data function under Luke (Director of Engineering), reporting to Trevor (CTO), and elevate my role to **Principal Analyst** to reflect the full scope of work I already own.

Geoff's departure means his responsibilities get absorbed regardless of which path is chosen. This proposal formalizes that absorption: management functions (budget, headcount, escalation) shift to Luke, operational functions (prioritization, stakeholder communication, project management) shift to Devon. The result eliminates a management layer, reduces cost, and places the data function alongside the team that shares its operational dependencies — while preserving full analytical support to Finance and all other departments.

---

## Current State

- **Team:** Sole data team member following Geoff's departure
- **Current title:** Data Analyst
- **Reporting line:** Geoff (Director of Data) -> Sourav (CFO)
- **Default post-departure:** Direct report to Sourav, or backfill Director of Data role
- **Scope of ownership:**
  - Data ingestion (Stitch)
  - Data transformation (dbt)
  - Data warehousing (Snowflake)
  - Business intelligence (Looker)
  - Reverse ETL / system sync (Polytomic)
  - All analytical reporting and ad-hoc analysis across departments

---

## Two Paths Forward

### Path A: Backfill the Director of Data role (status quo)

Hire a new Director of Data to replace Geoff. Devon continues as Data Analyst, reporting to the new director, who reports to the CFO.

- Adds a management layer over a single contributor
- Requires a director-level hire (salary, recruiting time, ramp-up)
- New director inherits a stack they did not build and must learn
- During the search and ramp period (likely 3-6 months), Devon operates independently anyway — the same operating model as Path B, but with the cost and disruption of an eventual transition
- Preserves the org structure that existed when the data team was expected to grow under Finance; that growth has not materialized

### Path B: Realign and elevate (proposed)

Move Devon under Luke (Director of Engineering -> Trevor, CTO). Elevate title to Principal Analyst.

- Eliminates the cost of a director-level backfill
- Zero ramp-up — Devon already owns the full scope
- Places the function alongside its operational dependencies
- Formalizes what is already true: Devon operates as an independent, senior technical contributor
- Engineering org provides technical peer review, escalation paths, and collaboration that a Finance reporting line cannot

---

## The Proposal

|                          | Current/Default                        | Proposed                                   |
| ------------------------ | -------------------------------------- | ------------------------------------------ |
| **Reports to**           | Sourav (CFO)                           | Luke (Dir. of Engineering) -> Trevor (CTO) |
| **Title**                | Data Analyst                           | Principal Analyst                          |
| **Service model**        | Single-department                      | Cross-departmental (formalized)            |
| **Director functions**   | Geoff                                  | Split between Luke and Devon (see below)   |

### How Geoff's responsibilities are absorbed

Geoff's departure creates a set of director-level responsibilities that need an owner regardless of which path is chosen. Under Path B, they split naturally:

**Shifts to Luke (management functions):**
- Budget ownership for data tooling
- Headcount decisions and hiring
- Escalation path for cross-team conflicts
- Technical oversight and review

**Shifts to Devon (operational functions):**
- Prioritization of data work across departments
- Stakeholder communication and expectations management
- Project management and delivery timelines
- Cross-departmental coordination on data requests

This split is what justifies both the reporting line change and the title change. Devon absorbs the responsibilities that require domain expertise and day-to-day context. Luke absorbs the responsibilities that require management authority.

### What does not change

- Sourav and all departments continue to receive the same analytical support
- All existing dashboards, reports, pipelines, and data products continue as-is
- Sourav retains a direct channel for analytical requests

---

## Rationale

### 1. Operational alignment

The data stack is infrastructure. Five of the six systems I manage (Stitch, dbt, Snowflake, Looker, Polytomic) are technical infrastructure that requires the same operational disciplines as the systems Luke's team manages: uptime monitoring, deployment workflows, version control, dependency management, incident response.

Under Finance, infrastructure issues are isolated — there is no peer review, no escalation path, no shared on-call awareness. Under Engineering, these concerns are native to the team's existing workflows.

### 2. Cross-system dependencies

The data stack does not operate in isolation. Examples of current and emerging integration points:

- **Polytomic** syncs data from Snowflake back into production systems managed by Engineering
- **Stitch** ingests data from systems that Engineering configures and deploys
- **Looker** connects to Snowflake via infrastructure that Engineering provisions
- **dbt** deployments follow software engineering patterns (version control, CI, environment management) that align with Engineering's existing practices

Closer organizational proximity reduces coordination overhead on these shared surfaces.

### 3. Technical management fit

Managing a data function requires evaluating tooling decisions, architectural trade-offs, and technical debt prioritization. These are engineering management competencies. The CFO is well-positioned to evaluate analytical output quality, but evaluating *how* the infrastructure is built and maintained is outside the natural scope of a finance leadership role.

### 4. Scalability

If the data function ever grows beyond a single contributor, engineering is the natural home for hiring, onboarding, and managing additional data roles. Engineering leadership has existing frameworks for technical hiring, code review processes, and development standards that would apply directly.

---

## The Principal Analyst Title

"Data Analyst" underrepresents the current scope. The role already includes:

- **Data engineering:** Pipeline development, schema design, data quality monitoring, ETL maintenance
- **Analytics engineering:** dbt model development, metric definitions, data modeling
- **Business analysis:** Ad-hoc analysis, reporting, executive dashboards, cross-departmental metric support
- **BI development:** Looker/LookML development, dashboard creation, self-service enablement
- **Data operations:** System administration, access management, vendor management across the stack

"Principal Analyst" captures the analytical ownership and seniority appropriate for the sole owner of an organizational function. It also communicates to stakeholders across the company that the role is a strategic analytical partner, not a back-end utility.

---

## What Sourav Gains

This framing matters. The pitch is not "I want to leave your org." It is:

1. **Cost savings.** Eliminating a director-level backfill saves a significant salary line. The function continues with zero interruption.
2. **Reduced management burden.** Sourav no longer manages a technical function outside his core expertise. Analytical outputs continue without interruption.
3. **Clearer accountability.** The data function is managed by a leader who can evaluate both the outputs and the methods. This means better oversight, not less.
4. **Same service, better support.** Cross-departmental analytical support continues. The difference is that the person delivering it has technical peers, infrastructure collaboration, and an escalation path — all of which improve reliability.
5. **Appropriate organizational design.** A solo technical function reporting into Finance is a legacy artifact of how the team was originally structured when the data team was expected to grow under Finance. That growth path has not materialized, and the work has become increasingly technical. This is an opportunity to realign structure to reality rather than preserving a structure that no longer fits.

---

## Risk Mitigation

| Concern                                  | Mitigation                                                                                                                                                              |
| ---------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| Sourav loses visibility into data work   | Establish a regular cadence (biweekly or monthly) for analytical priorities review with Finance                                                                          |
| Engineering deprioritizes analytical work | Formalize cross-departmental service model — analytical requests from any department are in-scope, not just Engineering                                                  |
| Transition disruption                    | Zero operational change on day one. Reporting line is the only thing that moves; all systems, processes, and deliverables continue                                       |
| Luke's team capacity to manage           | The role is self-directed with established workflows. Management overhead is minimal — this is adding a senior contributor, not a junior hire requiring close supervision |

---

## "How does all of this work still get done with one person?"

This is the right question. Geoff is a significant technical contributor, not just a manager. His departure creates a real capacity gap across the data function — in addition to the director-level responsibilities that need new owners.

The answer is not "it already gets done." The answer is that Devon has been building toward this specifically. d7dev is an analytical platform designed to close the capacity gap by systematizing and automating the operational side of the data function:

- **ETL task management** — structured workflows for transform development, with validation frameworks and promotion paths to the production dbt repo
- **Knowledge base** — data dictionary, runbooks, and decision records that reduce context-switching overhead and eliminate single-point-of-knowledge risk
- **LookML development workspace** — version-controlled BI development following software engineering practices
- **Automated validation** — cross-stack checks (SQL, LookML, Python) that catch issues before they reach production
- **Analytical methodology framework** — verification passes and audit trails that ensure output quality without requiring external review on every deliverable

This platform is purpose-built to bridge the capacity gap that Geoff's departure creates — systematizing work that previously required two people so that a single senior contributor can operate the function reliably. It is not finished; the roadmap includes further automation of pipeline monitoring, expanded self-service analytics capabilities, and deeper integration with Engineering's existing infrastructure. These goals align with and benefit from the proposed reporting structure.

The platform also mirrors engineering team practices — version control, testing, CI-like validation, code review workflows — which reinforces why the function fits naturally under Luke's org.
