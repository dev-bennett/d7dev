---
title: HubSpot List 7935 × Mac Cohort
date: 2026-05-01
status: final
parent: ../../  (analysis/adhoc/2026-04-30-mixpanel-mac-os-validation)
stakeholder: Dave Kart (VP Marketing)
deliverable: q2_mac_cohort.csv
---

# Scope

Single-row-per-contact CSV for HubSpot list 7935 ("Cue Beta User Targets All") with each contact tagged Mac / non-Mac / no-data-12mo / no-SS-account.

# Inputs

| Source | Role |
|---|---|
| `HUBSPOT_PLATFORM_DATA.V2_LIVE.LIST_MEMBERSHIPS` | List membership (LISTID = 7935 → 97 OBJECTIDs). |
| `HUBSPOT_PLATFORM_DATA.V2_LIVE.LISTS` | List metadata (name, type, size, created_at). |
| `SOUNDSTRIPE_PROD.HUBSPOT.HUBSPOT_CONTACTS` | Contact attributes via PROPERTIES JSON. |
| `SOUNDSTRIPE_PROD.CORE.DIM_USERS` | Soundstripe ↔ HubSpot bridge (`HUBSPOT_CONTACT_VID`, `USER_ID`, `EMAIL`). |
| `pc_stitch_db.mixpanel.export` | Raw Mixpanel; `mp_reserved_os` carries OS label. |
| `core.fct_events`, `core.dim_session_mapping`, `core.fct_sessions` | Event lineage from Mixpanel to authenticated user. |

# Why V2_LIVE, not V2_DAILY

Initial discovery checked `HUBSPOT_PLATFORM_DATA.V2_DAILY.LISTS` and found max LISTID = 7933. Falsely concluded list 7935 was missing. The list was created 2026-05-01 12:00 UTC and ingested into `V2_LIVE` (the live-sync schema, separate from V2_DAILY) one minute later. V2_LIVE had it the entire time; V2_DAILY runs nightly and had not yet picked it up.

Lesson recorded in CLAUDE.md: when looking for any HubSpot list created in the last 24h, query V2_LIVE first.

# Deliverable

`q2_mac_cohort.csv`. One row per HubSpot list-7935 contact (97 rows). Column dictionary:

| Column | Source | Notes |
|---|---|---|
| `hubspot_vid` | `LIST_MEMBERSHIPS.OBJECTID` | HubSpot's primary contact ID. |
| `email` | `HUBSPOT_CONTACTS.PROPERTIES:email` | Lower-cased. |
| `firstname`, `lastname` | `PROPERTIES:firstname/lastname` | Empty for some lead-only contacts. |
| `soundstripe_user_id` | `PROPERTIES:soundstripe_user_id` | Numeric; HubSpot custom property. NULL for contacts with no Soundstripe account. |
| `subscription_core_type` | `PROPERTIES:subscription_type__core_type_` | Enterprise / Pro Plus / Pro / Creator / blank. |
| `subscription_status` | `PROPERTIES:subscription_status` | active / cancelled / blank. |
| `hs_lead_status` | `PROPERTIES:hs_lead_status` | ENT CUS / NTR / SAL / MQL / NTR / blank. |
| `company` | `PROPERTIES:company` | |
| `bridge_path` | derived | `hubspot_vid` / `soundstripe_user_id` / `email` / `none`. Identifies which match path resolved the SS user_id. |
| `resolved_user_id` | derived | Soundstripe user_id (or NULL if `bridge_path = none`). |
| `mac_classification` | derived | `MAC` / `NON_MAC` / `NO_DATA_12MO` / `NO_SS_ACCOUNT`. |
| `most_recent_os` | derived | Last observed OS in 12mo window. Useful for spotting users who switched (classified MAC because of a year-old event but currently on Windows). |
| `last_seen_date` | derived | Last Mixpanel event date in window. |
| `last_mac_date` | derived | Last date contact appeared on a Mac (NULL if never in window). |
| `mac_event_count`, `total_events` | derived | Raw counts in the 12mo window. |

# Audit summary

| Classification | Count | % | Meaning |
|---|---:|---:|---|
| MAC | 56 | 57.7% | At least one Mac event in the 12-month window |
| NON_MAC | 19 | 19.6% | Has events in 12mo, none on Mac |
| NO_DATA_12MO | 9 | 9.3% | Soundstripe account exists but no Mixpanel events in 12mo |
| NO_SS_ACCOUNT | 12 | 12.4% | No Soundstripe account — verified across 5 match paths |
| **Total** | **97** | | |

The 12 NO_SS_ACCOUNT contacts were verified non-users via dim_users (HUBSPOT_CONTACT_VID, USER_ID, EMAIL, alt-VIDs from `hs_all_contact_vids`) and the upstream `pc_stitch_db.soundstripe.users` table (1.7M rows, 370 broader than dim_users). HubSpot-side: 10 of 12 are `lifecyclestage = 'lead'`; all 12 have NULL `chargebee_customer_id`, `stripe_customer_id`, and `subscription_type`. They are leads, not paid subscribers.

# Open question for Dave

The list label suggests "active paid subscribers / enterprise contacts" but the membership includes 12 lead-only contacts and 1 cancelled subscriber. Dave can confirm whether this was intentional (e.g., the filter included `lifecyclestage IN ('customer','lead')`) or whether the filter needs adjustment.
