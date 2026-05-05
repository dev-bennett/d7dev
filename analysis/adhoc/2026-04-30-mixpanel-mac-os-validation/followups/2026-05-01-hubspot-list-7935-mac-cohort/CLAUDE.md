@../../CLAUDE.md

# 2026-05-01 — HubSpot List 7935 × Mac Cohort

Cross-system join: HubSpot list 7935 contacts → Mac / non-Mac classification from the parent Mac/OS validation.

**Stakeholder:** Dave Kart (VP Marketing). Use case: Soundstripe Live beta target list (Mac-only product offering).

**Source list:** `https://app.hubspot.com/contacts/4192879/objectLists/7935/filters` — list name "Cue Beta User Targets All", LISTTYPE = SNAPSHOT, 97 contacts. Created 2026-05-01 12:00 UTC; ingested into `HUBSPOT_PLATFORM_DATA.V2_LIVE` 1 minute later.

## Discovery note

V2_LIVE (live-sync schema) is the right source for fresh lists. V2_DAILY had not yet picked up list 7935 at first query; the original survey only hit V2_DAILY and falsely concluded "list missing." Anything created between batch syncs lives in V2_LIVE first; check both.

## Files

- `README.md` — task scope, deliverable spec, parent-task linkage
- `console.sql` — q0 (list metadata), q1 (member extract), q2 (Mac classification), q3 (audit), q4 (NO_SS_ACCOUNT diligence), §1 RATE block
- `q2_mac_cohort.csv` — final deliverable; one row per list-7935 contact
- `findings.md` — Dave-facing summary

## Method invariants

- List membership comes from `HUBSPOT_PLATFORM_DATA.V2_LIVE.LIST_MEMBERSHIPS WHERE LISTID = 7935`. Use V2_LIVE (not V2_DAILY) for any list created in the last 24h.
- Contact attributes come from `SOUNDSTRIPE_PROD.HUBSPOT.HUBSPOT_CONTACTS.PROPERTIES` (JSON OBJECT). Pull `email`, `firstname`, `lastname`, `soundstripe_user_id`, `subscription_type__core_type_`, `subscription_status`, `hs_lead_status`, `company`, `chargebee_customer_id`, `stripe_customer_id` as needed.
- Mac filter is `mp_reserved_os IN ('Mac', 'Mac OS X')` — canonical from parent task; do not redefine.
- Mac fold lineage (parent q5): `pc_stitch_db.mixpanel.export → fct_events → dim_session_mapping → fct_sessions → dim_users`. `fct_sessions.user_id` is TEXT — `TRY_CAST(... AS NUMBER)` before joining `dim_users.user_id`.
- HubSpot↔Soundstripe bridge priority: (1) `dim_users.HUBSPOT_CONTACT_VID = list_member.OBJECTID`, (2) `dim_users.USER_ID = soundstripe_user_id` HubSpot custom property, (3) `dim_users.EMAIL = HubSpot email` (case-insensitive). Use COALESCE to pick the first match; record `bridge_path`.
- Output grain: one row per HubSpot list-7935 contact. No fan-out below that.
- Classification labels: `MAC` / `NON_MAC` / `NO_DATA_12MO` (Soundstripe user, no Mixpanel events in 12mo) / `NO_SS_ACCOUNT` (verified non-user via 5 match paths).
- Window: 12 months by default (2025-05-01 → 2026-05-01) so historical Mac usage isn't lost. The 30d window dropped 19 Mac users into NO_RECENT_ACTIVITY.
