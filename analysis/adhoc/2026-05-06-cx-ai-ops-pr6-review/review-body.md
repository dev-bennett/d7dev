Approving. Rules cover the load-bearing safety failure modes (§8, §5, §6, §1) — safe to ship once the doc edits below land. Two notes first.

---

## Snowflake access

`HUBSPOT_PLATFORM_DATA` exists (your memory was right) and `SELECT_ANALYST` had no visibility on it. Granted today:

```sql
GRANT IMPORTED PRIVILEGES ON DATABASE HUBSPOT_PLATFORM_DATA TO ROLE SELECT_ANALYST;
```

Constraint that affects your doc: the grant is database-wide, so `V2_LIVE` and `PUBLIC` are visible too. The "avoid V2_LIVE" guidance in your rules is the only guardrail. Verify with `SELECT COUNT(*) FROM HUBSPOT_PLATFORM_DATA.V2_DAILY.OWNERS` (expect ~191).

---

## Edits before merge

### `SNOWFLAKE_RULES.md` §1 — Schema-routing table

Delete the "`hubspot_platform_data` does not exist" paragraph. Add HPD as the first two rows:

| Schema | Use? | Notes |
|---|---|---|
| `HUBSPOT_PLATFORM_DATA.V2_DAILY.*` | **Default for event-grain HubSpot analysis.** | HubSpot's native Data Share (Operations Hub Data Sync). Daily refresh. 784 tables, 1.6B rows. Event firehose (page views, email events, form submits, list-membership changes) plus `OBJECT_PROPERTIES_HISTORY`. Date-scope mandatory per §6. |
| `HUBSPOT_PLATFORM_DATA.V2_LIVE.*` | **Avoid.** | Streaming variant. Visible to `SELECT_ANALYST` because the grant is database-wide; V2_DAILY is the analyst-friendly path. |

### `SNOWFLAKE_RULES.md` §1 — Decision tree

Add ahead of the existing TICKETS / CONTACTS rows:

| Question | Schema |
|---|---|
| Page views, email opens/clicks, form-submit events, list-size-change events | `HUBSPOT_PLATFORM_DATA.V2_DAILY.EVENTS_*` |
| Property-value history ("when did property X change for object Y") | `HUBSPOT_PLATFORM_DATA.V2_DAILY.OBJECT_PROPERTIES_HISTORY` |

Existing rows stay — they're current-state CRM questions, which is what `HUBSPOT_NEW` is for.

### `SNOWFLAKE_RULES.md` §1 — Stitch column conventions for `HUBSPOT_NEW`

Add (verified on `TICKETS`, 328 columns, 2026-05-06):

> All HubSpot-property columns in `PC_STITCH_DB.HUBSPOT_NEW.*` carry a Stitch flattening prefix: `PROPERTY_*` for user-defined properties, `PROPERTY_HS_*` for system properties. Examples on `TICKETS`: `pipeline` → `PROPERTY_HS_PIPELINE`, `subject` → `PROPERTY_SUBJECT`, `hubspot_owner_id` → `PROPERTY_HUBSPOT_OWNER_ID`. There's also a raw `PROPERTIES` VARIANT column with the full property object.
>
> Two timestamp columns exist in parallel: `CREATEDAT` / `UPDATEDAT` are Stitch loader timestamps; `PROPERTY_CREATEDATE` / `PROPERTY_HS_LASTMODIFIEDDATE` are HubSpot's. Use the HubSpot ones for analytics.

### `SNOWFLAKE_RULES.md` §14

- Q1 resolved: HPD exists, access granted 2026-05-06.
- Q4 resolved: columns confirmed; prefix note added above.
- Q2 / Q3: see below.

### `CLAUDE.md` Snowflake section

```markdown
- HubSpot routing (verified 2026-05-06):
  - `HUBSPOT_PLATFORM_DATA.V2_DAILY.*` — default for event-grain analysis. Imported Data Share. Event firehose + property history.
  - `PC_STITCH_DB.HUBSPOT_NEW.*` — current-state CRM snapshot. Property columns prefixed `PROPERTY_*` / `PROPERTY_HS_*`.
  - `SOUNDSTRIPE_PROD.HUBSPOT.*` — narrow dbt subset for email events, deal trends, lists.
  - `PC_STITCH_DB.HUBSPOT.*` — legacy, frozen 2025-03. Avoid.
```

---

## §14.2 — `knowledge/` location

Keep it in cx-ai-ops next to `SNOWFLAKE_RULES.md`. Engineering has no query-KB convention to defer to, and co-location keeps cross-references walkable in a single repo.

## §14.3 — Promote to global `~/.claude/CLAUDE.md`?

- **Promote:** §8 (capped-sample protocol). Universal across any MCP-style execution. If you're running queries from multiple repos, the global is the right home.
- **Keep repo-scoped:** connection profile, schema routing, HubSpot specifics. Account-specific.
- **Hybrid:** §6 cost discipline — lift the principles, leave the Soundstripe-specific table list.
