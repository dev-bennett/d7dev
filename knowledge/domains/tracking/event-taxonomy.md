# Event Taxonomy

- **Last updated:** 2026-04-02
- **Author:** d7admin
- **Status:** Draft -- initial capture, partial coverage

## Coverage Summary

- **Capture date:** 2026-04-02
- **Flows covered:** Song playback, license purchase flow, download, account menu, notifications
- **Flows NOT yet covered:** Search, browse/discover, pricing page, sign-up, onboarding, settings, navigation, SFX, video

## Observed Events

### Specific Events (dedicated event name)

| Event | Domain | Properties (excluding common) |
|-------|--------|-------------------------------|
| **Played Song** | Playback | Play Duration (int), Play Completed (bool), Song ID, Song Title, Song Parent ID, Recommendation Rank, Artist ID, Artist Name, Playlist ID, Playlist Name, Content Partner Slug, Song Version ID, Song Version Description |
| **Clicked Pricing Product** | Commerce | Product Type |
| **Clicked Download Song** | Commerce | Song ID, Song Title, Artist ID, Artist Name |
| **Viewed Account Avatar Menu** | Account | *(no additional props)* |
| **Clicked Notifications Link** | Account | Context, Link Text |

### Generic Events (disambiguated by context/element properties)

| Event | context | element / other | Domain |
|-------|---------|-----------------|--------|
| **Viewed Modal** | "Buy Song License" | -- | Commerce |
| **Viewed Modal** | "Download Song Preview" | Song Id | Commerce |
| **Clicked Element** | "Buy Song License Modal" | "select digital" | Commerce |
| **Clicked Element** | "License Purchase" | "Add to Cart" + Items[] | Commerce |
| **Clicked Element** | "User Notification" | url, title, message, read_at, notification_type | Account |

### Common Properties (every event)

| Property | Type | Description |
|----------|------|-------------|
| `$device_id` | UUID | Mixpanel device identifier |
| `Statsig Stable ID` | UUID | Experimentation assignment ID |
| `Client Event Timestamp` | int (epoch ms) | Client-side event timestamp |

## Observations

1. **Two-tier naming pattern:** High-value actions get specific event names (`Played Song`, `Clicked Download Song`). Lower-priority interactions use `Clicked Element` / `Viewed Modal` with `context` + `element` for disambiguation.
2. **Property casing inconsistency:** `Song Id` (Viewed Modal > Download Song Preview) vs `Song ID` (Played Song, Clicked Download Song). Likely a bug.
3. **Items array:** `Clicked Element` with context "License Purchase" carries a structured `Items[]` array with license metadata -- this is the cart/commerce payload.
4. **Null properties:** `Played Song` sends null for Playlist ID/Name, Song Parent ID, Recommendation Rank when not applicable (not omitted, explicitly null).

## Known Events Not Yet Captured

From `knowledge/domains/search/overview.md`:
- Executed Reference Track Search
- Reference Track Search Sign Up Modal Opened
- Reference Track Search Error
- Reference Track Search Closed
- Executed Agent Search
- Searched Songs

From `context/dbt/models/marts/core/dim_mixpanel_feature_events.sql` and `dim_mixpanel_cart_events.sql`:
- *(Requires model read to enumerate -- pending)*

## Related

- Raw captures: `analysis/data-health/event-captures/`
- Capture runbook: `knowledge/runbooks/event-capture-workflow.md`
- Search events: `knowledge/domains/search/overview.md`
- Warehouse staging: `context/dbt/models/staging/mixpanel/stg_events.sql`
