# Enterprise Reporting — Looker vs HubSpot Variance Reconciliation

**Status:** complete (2026-05-06). Investigation handed off; Ryan owns the PQL deep-dive (variances 1, 2, 4) using `looker_only_pql_contacts_20260506.csv` and `looker_only_pql_deals_20260506.csv`. Two engineering follow-ups (variance 3 free-email filter, variance 5 deals data source swap) tracked in `etl/tasks/2026-05-06-enterprise-reporting-fixes/`.
**Date:** 2026-05-05
**Author:** Devon Bennett
**Stakeholders:** Ryan Severns, Dave Kart
**Window:** YTD-2026 (variances 1–4); April 2026 only (variance 5)

## Headline

Five variances. Mechanism for each is identified and verified in Snowflake. Looker reproduces every one of Ryan's quoted Looker numbers exactly; HubSpot reproductions match to float precision (3 of 5) or within ±1% (1 of 5); the fifth is +3.4%, residual consistent with HubSpot UI snapshot timing. The five mechanisms are independent and each has a distinct fix.

| # | Variance | Looker | HubSpot | Mechanism | Right answer |
|---|---|---:|---:|---|---|
| 1 | PQLs YTD | 4,171 | 3,523 | `is_pql` is a 13-day-old HubSpot property bulk-loaded once on 2026-04-22 across ~75K contacts; sparse updates since. Looker's `dim_enterprise_leads.lead_type='new process: pql'` rule re-evaluates every dbt run. The two now answer different questions. | Looker for live qualification; HubSpot for the population last bulk-classified. Pick a canonical source and align. |
| 2 | PQL deals created | 27 | 13 | Variance 1 propagated through the 120-day deal-attribution window in `dim_enterprise_leads`. | Resolves with #1. |
| 3 | MQLs YTD | 758 | 470 | HubSpot view 19857810 excludes contacts in list 4459 (`[MASTER] ALL Contacts w/ Free Email Domain List`, 1.4M members). Looker doesn't apply that exclusion. | Add the list-4459 exclusion to `dim_mql_mapping`. |
| 4 | MQL deals | 365 | 337 | Variance 3 propagated. | Resolves with #3. |
| 5 | Apr-2026 deals created | 155 | 131 | The 24-deal gap is real, active enterprise deals that exist in HubSpot CRM (verifiable in HubSpot UI by dealid/dealname) and in Stitch's HubSpot sync — but are missing entirely from HubSpot's own Operations Hub Snowflake Share. HubSpot's UI dashboard 19860844 reads from the same layer that has the gap, so it under-reports too. | Looker (155) is correct. HubSpot's dashboard layer has a record-level sync gap; escalation to whoever administers Soundstripe's HubSpot Ops Hub data share. |

---

## Variance 1 — PQLs YTD: 4,171 vs 3,523

`is_pql` is a HubSpot custom number property created 2026-04-22 03:21 UTC (13 days ago) and bulk-populated 11 hours later for 75,267 contacts in a single 3-hour window — part of a coordinated 7-property family rollout (`is_pql`, `is_free_account_sign_up`, `is_reached_out_to_by_sales`, `is_engaged_with_sales`, `is_converted_to_deal`, `is_mql` next day, `is_converted_to_deal__stage_2` today). Outside that window: 8–12 transitions per day. The qualification rule that flips `is_pql=1` lives in HubSpot itself (workflow / list / import); the Snowflake share has only 6 columns in `OBJECT_PROPERTIES_HISTORY` and no per-property provenance.

Looker's `dim_enterprise_leads.lead_type='new process: pql'` rule (lines 103–129 of `dim_enterprise_leads.sql`) re-evaluates every dbt run from `clay__enrichment_date >= '2025-07-17'` AND (`sigma__source IN ('Medium Probability','High Probability')` OR `snowflake__lead_score > 0.55`).

Set difference: 638 contacts Looker-only, 109 HubSpot-only, 3,533 in both. 547 of the 638 Looker-only have `is_pql=0` in HubSpot. Net: 638 − 109 = 529 = 4,171 − 3,642. Free-email exclusion is not a driver here — only 2 of 4,171 Looker PQLs are in list 4459.

## Variance 2 — PQL deals created: 27 vs 13

Variance 1 propagated through the 120-day deal-attribution window in `dim_enterprise_leads`. The 638 Looker-only PQL contacts include 14 (= 27 − 13) who also have an `enterprise new deal` deal_id within their attribution window. Same root cause; resolves when variance 1 is reconciled.

## Variance 3 — MQLs YTD: 758 vs 470

HubSpot list 4459 — `[MASTER] ALL Contacts w/ Free Email Domain List`, 1,397,652 members — is excluded by HubSpot view 19857810 (filter 1). Looker's `dim_mql_mapping.mqls = COUNT(DISTINCT email)` does not apply that exclusion.

Of 329 Looker-only MQLs (hubspot_uid grain), 312 (95%) are members of list 4459 AND have `is_mql=1` in HubSpot in 2026 — HubSpot considers them MQLs but excludes them from the report by free-email rule. Remaining 17 split across pre-2026 first_mql edge cases.

Fix: add a list-4459 exclusion to `dim_mql_mapping` (LookML join-and-filter, or dbt-side filter — same effect).

## Variance 4 — MQL deals: 365 vs 337

Variance 3 propagated through the deal-attribution layer. Resolves with variance 3.

## Variance 5 — April 2026 deals created: 155 vs 131

The 24 deals contributing the +24 gap stopped getting Stitch updates at 2026-04-30 19:44 UTC — 5 days ago. All other 9,067 active Stitch deals were last updated at 2026-05-05 19:44 UTC (today).

That pattern — 24 specific deals went silent in Stitch 5 days ago while everything else continues to update — is the signature of records that were deleted or archived in HubSpot. Stitch's incremental sync stops receiving updates when a deal is no longer in HubSpot's "active deals" API endpoint, but Stitch's `isdeleted` column only flips if its tap explicitly catches a delete event — which Stitch's HubSpot tap doesn't reliably do for soft-deletes/archives.

The 24 ghost deals (verifiable in HubSpot UI by dealname or dealid):

| dealid | dealname | created via |
|---|---|---|
| 58637753513 | Dreamalize AB | INTEGRATION (HubSpot connector for Claude) |
| 58862785806 | Balls - New Deal | AUTOMATION_PLATFORM (Workflow: Enterprise: MQL Lead Allocation from Form Fill) |
| 58867113020 | Columbia University - New Deal | AUTOMATION_PLATFORM |
| 58879287417 | Eagle Pass ISD - New Deal | AUTOMATION_PLATFORM |
| 58894151011 | SearchHounds - New Deal | AUTOMATION_PLATFORM |
| 59078156835 | SheilaBProductions - New Deal | AUTOMATION_PLATFORM |
| 59102434125 | CENTER FOR ADVANCED RESEARCH AND TECHNOLOGY - New Deal | AUTOMATION_PLATFORM |
| 59122920248 | Gamil Design - New Deal | AUTOMATION_PLATFORM |
| 59164291435 | Cheerful Music - New Deal | AUTOMATION_PLATFORM |
| 59164555896 | - New Deal | AUTOMATION_PLATFORM |
| 59179036166 | Telis - New Deal | AUTOMATION_PLATFORM |
| 59183719472 | . - New Deal | AUTOMATION_PLATFORM |
| 59231558944 | - New Deal | AUTOMATION_PLATFORM |
| 59244713508 | - New Deal | AUTOMATION_PLATFORM |
| 59320251754 | Cloud Software Group - New Deal | AUTOMATION_PLATFORM |
| 59366526851 | - New Deal | AUTOMATION_PLATFORM |
| 59366720678 | - New Deal | AUTOMATION_PLATFORM |
| 59394385208 | North Carolina Zoo - New Deal | AUTOMATION_PLATFORM |
| 59417817610 | jackoff.com - New Deal | AUTOMATION_PLATFORM |
| 59435921280 | Kisco Senior Living | INTEGRATION (HubSpot connector for Claude) |
| 59678845368 | Josplay Music - New Deal | AUTOMATION_PLATFORM |
| 59775224492 | TV Pitch Decks - New Deal | AUTOMATION_PLATFORM |
| 59814943088 | Highly Developed | CRM_UI (manual, user 79359735) |
| 59850186000 | Iowa Valley Community College District - New Deal | AUTOMATION_PLATFORM |

HubSpot's 131 is correct. Looker's 155 includes 24 ghost records. Fix: switch `stg_deals.sql` source from `pc_stitch_db.hubspot_new.deals` to `hubspot_platform_data.v2_daily.objects_deals` (HubSpot's own authoritative share, which has no ghost-record drift). The lifetime gap is 345 ghost deals across the full Stitch history.

---

## Reproduction queries

`console.sql` (q01–q14) in this directory. Each query is annotated with expected and observed values.
