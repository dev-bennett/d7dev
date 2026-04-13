# Tracking Domain Overview

- **Last updated:** 2026-04-02
- **Author:** d7admin

## Scope

The tracking domain covers all client-side event instrumentation on www.soundstripe.com, including event taxonomy, property standards, identity resolution, and data flow into the warehouse.

## Architecture

### Tracking API

All client-side events route through a single endpoint:
```
POST https://api.soundstripe.com/app/tracking
```

Payload format (JSONAPI-style envelope):
```json
{
  "data": {
    "type": "tracking",
    "attributes": {
      "event_name": "Event Name",
      "event_properties": { ... }
    }
  }
}
```

Transport: XHR (primary, confirmed 2026-04-02). Fetch may also be used.

### Identity Properties (present on every event)

| Property | Description |
|----------|-------------|
| `$device_id` | Mixpanel device identifier (UUID) |
| `Statsig Stable ID` | Experimentation assignment identifier (UUID) |
| `Client Event Timestamp` | Epoch milliseconds, client-side clock |

### Data Flow

```
Browser -> api.soundstripe.com/app/tracking -> Mixpanel -> Stitch -> Snowflake (pc_stitch_db.mixpanel.export) -> dbt (stg_events -> fct_events)
```

## Event Naming Conventions (Observed)

- **Title Case** with spaces: `Played Song`, `Viewed Modal`, `Clicked Element`
- **Specific events** for high-value actions: `Played Song`, `Clicked Download Song`, `Clicked Pricing Product`
- **Generic events** with context/element properties for lower-priority interactions: `Clicked Element` + `context` + `element`, `Viewed Modal` + `context`

## Related

- Event taxonomy: `knowledge/domains/tracking/event-taxonomy.md`
- Capture runbook: `knowledge/runbooks/event-capture-workflow.md`
- Capture data: `analysis/data-health/event-captures/`
- Warehouse models: `context/dbt/models/staging/mixpanel/stg_events.sql`, `context/dbt/models/marts/core/dim_mixpanel_feature_events.sql`
