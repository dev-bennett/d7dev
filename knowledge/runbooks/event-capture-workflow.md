# Event Capture Workflow

- **Last updated:** 2026-04-02
- **Author:** d7admin

## Purpose

Capture and catalog tracking events firing on www.soundstripe.com by intercepting requests to the tracking API. Produces a structured event log for taxonomy mapping, data quality audits, and instrumentation gap analysis.

## Prerequisites

- Chrome browser with access to www.soundstripe.com
- Chrome DevTools (Cmd+Option+J on Mac)
- Logged-in session if capturing authenticated flows

## Architecture

All tracking events are sent via XHR/fetch to:
```
POST https://api.soundstripe.com/app/tracking
```

Payload envelope (JSONAPI-style):
```json
{
  "data": {
    "type": "tracking",
    "attributes": {
      "event_name": "Event Name Here",
      "event_properties": { ... }
    }
  }
}
```

Common properties on every event:
- `$device_id` -- Mixpanel device identifier
- `Statsig Stable ID` -- Experimentation identifier
- `Client Event Timestamp` -- Epoch ms timestamp

## Step-by-Step

### 1. Initialize the Interceptor

Open DevTools console on www.soundstripe.com. Paste each block sequentially:

**Block 1 -- Initialize storage:**
```javascript
window.__e = [];
```

**Block 2 -- Hook fetch:**
```javascript
var _f = window.fetch; window.fetch = function(u, o) { var url = typeof u === 'string' ? u : (u && u.url) || ''; if (url.includes('/app/tracking') && o && o.body) { try { var d = JSON.parse(o.body); window.__e.push({event: d.data.attributes.event_name, props: d.data.attributes.event_properties}); console.log(d.data.attributes.event_name, d.data.attributes.event_properties); } catch(e) {} } return _f.apply(this, arguments); };
```

**Block 3 -- Hook XHR:**
```javascript
var _x = XMLHttpRequest.prototype.send; XMLHttpRequest.prototype.send = function(b) { if (b && typeof b === 'string' && b.includes('event_name')) { try { var d = JSON.parse(b); window.__e.push({event: d.data.attributes.event_name, props: d.data.attributes.event_properties}); console.log(d.data.attributes.event_name, d.data.attributes.event_properties); } catch(e) {} } return _x.apply(this, arguments); };
```

### 2. Navigate Target Flows

Walk through the user journeys you want to capture. Suggested flow groups:

| Flow Group | Pages/Actions |
|------------|---------------|
| Navigation | Homepage, nav links, footer links, logo click |
| Search | Text search, filter by genre/mood/tempo/vocals, clear filters |
| Browse | Collections, playlists, categories, artist pages |
| Playback | Play song, pause, skip, complete, play different version |
| Commerce | Pricing page, license selection, add to cart, download |
| Account | Avatar menu, notifications, settings, subscription pages |
| Modals | Sign-up gate, download preview, license purchase modal |
| Onboarding | Sign-up flow (use test account or stop before submission) |

### 3. Export the Event Log

When done navigating, run in console:
```javascript
copy(JSON.stringify(window.__e, null, 2))
```

### 4. Save the Capture

Save the JSON to:
```
analysis/data-health/event-captures/YYYY-MM-DD-<flow-group>.json
```

Example: `analysis/data-health/event-captures/2026-04-02-commerce-flow.json`

### 5. Reset for Next Flow Group

To capture a clean log for a different flow group:
```javascript
window.__e = [];
```

Then navigate the next flow group and export again.

## Output Conventions

- One JSON file per capture session or flow group
- File naming: `YYYY-MM-DD-<descriptor>.json`
- Each entry: `{event: string, props: object}`
- Do not edit raw captures -- they are source artifacts
- Analysis/taxonomy work goes in `knowledge/domains/tracking/`

## Troubleshooting

| Issue | Fix |
|-------|-----|
| Empty array after navigating | Page reload clears the hooks. Re-paste all 3 blocks. |
| Syntax error on paste | Paste each block separately, not all at once. |
| Missing events you expected | Some events may fire on page load before hooks are active. Navigate away and back. |
| Duplicate events | The interceptor captures every call. Deduplicate during analysis, not capture. |

## Related

- Tracking domain knowledge: `knowledge/domains/tracking/`
- Event taxonomy: `knowledge/domains/tracking/event-taxonomy.md`
- Tracking architecture: `knowledge/domains/tracking/overview.md`
