# MQL Workflow Monitoring Dashboard — Tile Alignment Notes

**Status:** open question, deferred to Monday 2026-05-11 review.
**Source:** post-deploy review of `mql_workflow_monitoring_dashboard.txt` (this directory) on 2026-05-08.
**Related task status:** the MQL discrepancy fix follow-up (this task) shipped successfully — these notes are about dashboard interpretation, not pipeline correctness.

## The question

The dashboard has two tiles that look like they should agree but don't:

- **"MQLs (Mixpanel) - Source"** — stacked column from `fct_sessions` summing `mqls_pricing_page + mqls_enterprise_page + mqls_schedule_demo`.
- **"MQL Forms (Hubspot) -> Workflow"** — stacked column from `hubspot_forms` showing `hubspot_forms.emails` pivoted by `stg_contacts_2.mql_flag`. The `Yes` pivot is labeled "Mixpanel Labeled MQL" via `series_labels`.

Expectation was that the totals (or at least the "Yes / Mixpanel Labeled MQL" series in the second chart) align with the first chart's totals. They don't — and they can't, given the underlying definitions.

## Why they don't align (three stacked reasons)

### 1. The "Mixpanel Labeled MQL" series label is misleading

`stg_contacts_2.mql_flag` is defined (`context/lookml/views/Hubspot/stg_contacts_2.view.lkml:350-353`):

```lookml
dimension: mql_flag {
  type: yesno
  sql: case when ${TABLE}.became_mql is not null then true else false end ;;
}
```

`became_mql` is a **HubSpot lifecycle property** — the timestamp HubSpot's own MQL workflow set on the contact. It has nothing to do with Mixpanel. The dashboard YAML's `series_labels: Yes - hubspot_forms.emails: Mixpanel Labeled MQL` mislabels what the dimension actually measures. Compared accurately, the chart shows "HubSpot form submissions split by whether the contact has HubSpot's `became_mql` timestamp set."

### 2. Different starting populations and different grains

|  | Chart 1 — "MQLs (Mixpanel) - Source" | Chart 2 — "MQL Forms (Hubspot) -> Workflow" |
|---|---|---|
| Source explore | `fct_sessions` | `hubspot_forms` |
| Population | every Mixpanel session | `hubspot_forms` filtered to enterprise form names |
| Measure SQL | `COUNT(DISTINCT case when <col> > 0 then distinct_id end)` per bucket | `COUNT(DISTINCT email)` |
| Grain | `distinct_id` (Mixpanel cookie/visitor) | `email` (HubSpot contact) |

A logged-out visitor who fills the form is one email but can be multiple `distinct_id`s. A single `distinct_id` can submit multiple forms with different emails. The two grains do not deduplicate the same way.

### 3. `fct_sessions.mqls` double-counts visitors across sub-measures

The LookML composite (`context/lookml/views/Mixpanel/fct_sessions.view.lkml:545-552`):

```lookml
measure: mqls {
  sql: ${mqls_pricing_page} + ${mqls_enterprise_page} + ${mqls_schedule_demo} ;;
}
```

Each component is independently `COUNT(DISTINCT case when <col> > 0 then distinct_id)`. A visitor who fired both a pricing-page form-submit event and an enterprise-page form-submit event contributes 1 to `mqls_pricing_page` AND 1 to `mqls_enterprise_page` — total 2 in `mqls`. The total tile value can exceed the unique-visitor count for the same reason.

## What actually aligns with what

The right tile to compare against the HubSpot side at the same grain and definition is anything sourced from `dim_mql_mapping` (the model this task built). `dim_mql_mapping` is HubSpot-anchored at email grain with tiered Mixpanel-session attribution — it explicitly joins HubSpot form submissions to Mixpanel sessions, so `dim_mql_mapping.mqls` and the chart 2 "Yes / mql_flag = true" series are directly compatible populations.

`fct_sessions.mqls` is "any Mixpanel visitor who fired an enterprise-form-related event" with no HubSpot filter — it will always exceed HubSpot's MQL count.

## Suggested actions for Monday

Pick one or more, depending on what the dashboard is meant to tell stakeholders:

### A. Cosmetic fix (low effort) — rename the misleading series labels

In the dashboard YAML for both `MQL Forms (Hubspot) -> Workflow` tiles, change:

```yaml
series_labels:
  Yes - hubspot_forms.emails: Mixpanel Labeled MQL
  No - hubspot_forms.emails: Not Mixpanel Labeled MQL
```

to:

```yaml
series_labels:
  Yes - hubspot_forms.emails: HubSpot MQL
  No - hubspot_forms.emails: Not HubSpot MQL
```

This stops the chart from advertising a Mixpanel signal it doesn't measure. Doesn't fix the cross-tile comparability question, but at least the chart describes itself honestly.

### B. Replace the `mqls` source breakdown with a `dim_mql_mapping`-based view

If the dashboard's intent is "what fraction of HubSpot MQLs trace back to which Mixpanel page source," that lives naturally in `dim_mql_mapping` via `form_page_type` (`enterprise_landing`, `brand_solutions`, `agency_solutions`, `enterprise_page`). A new tile sourced from `dim_mql_mapping` pivoted by `form_page_type` would give the right answer at the right grain.

### C. Build a true "Mixpanel-anchored MQL" dimension on contacts

If the dashboard's intent is to compare HubSpot's MQL flag with a Mixpanel-evidence-based MQL flag, neither exists today as a contact-level dimension. Could be added by joining `dim_mql_mapping` → `stg_contacts_2` on `hubspot_uid = canonical_vid` and exposing a `has_mixpanel_mql_evidence` boolean — that would make a true side-by-side comparison possible.

## Workspace references

- Dashboard YAML: `etl/tasks/2026-04-07-mql-discrepancy-fix/mql_workflow_monitoring_dashboard.txt`
- `stg_contacts_2.mql_flag` definition: `context/lookml/views/Hubspot/stg_contacts_2.view.lkml:350-353`
- `fct_sessions.mqls` composite: `context/lookml/views/Mixpanel/fct_sessions.view.lkml:545-552`
- `dim_mql_mapping` model (deployed via this task): `context/dbt/models/marts/marketing/dim_mql_mapping.sql`
