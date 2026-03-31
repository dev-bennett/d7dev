# dbt Repo -- Commit / PR Materials

## Commit Message

```
Add Searched Songs properties to fct_events (Has Vocals, Result Count, Supe)
```

## PR Title

Add Searched Songs properties to fct_events

## PR Description

### Summary

- Add 3 columns to fct_events for new Mixpanel "Searched Songs" event properties shipped by engineering to support Music team search insights
- `search_has_vocals`: vocal filter selection (All / Vocals / Instrumental). CASE expression filters out pre-3/25 boolean values from prior property format.
- `search_result_count`: number of search results returned (TRY_CAST from TEXT to INTEGER)
- `is_supe_search`: whether search was triggered from Supe AI chat sidebar (TRY_CAST from TEXT to BOOLEAN)

### Test Plan

- [ ] Schema check confirms columns populating in Stitch export (~90% population rate since 3/26)
- [ ] Backfill from 2026-03-25: `dbt run --select fct_events --vars '{"backfill_from": "2026-03-25"}'`
- [ ] Validation queries confirm columns populated for Searched Songs events and NULL for unrelated events
- [ ] dim_mixpanel_feature_events unaffected (already references HAS_VOCALS independently in filter_json)
