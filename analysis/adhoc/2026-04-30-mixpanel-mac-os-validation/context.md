# Originating ask

## Slack — Dave Kart, 2026-04-30 14:11

> Hi Devon - we are building a target list to beta test Soundstripe LIve (previously Cue). I have a list of self serve and enterprise users. Are you able to confirm if they are using a Mac? Do we have that data?

## Interpretation

- **Goal:** identify which users on Dave's beta target list are Mac users, to filter the Soundstripe Live beta invite list.
- **Population:** mix of self-serve and enterprise users supplied by Dave.
- **Required signal:** is each user a Mac (desktop macOS) user.
- **Not yet supplied:** the user list itself. Dave will share it.

## Status

- Validation that the data exists: **DONE.** See `findings.md` — `mp_reserved_os IN ('Mac', 'Mac OS X')` on `pc_stitch_db.mixpanel.export` is the canonical filter; 99.4% fill, ~13% of recent active users are Mac.
- Lookup join against Dave's list: **PENDING** — awaiting list from Dave.

## Next step when list arrives

1. Determine the join key Dave provides (likely `user_id` / email / customer_id).
2. Resolve list identifiers → Mixpanel `distinct_id` (via `core.fct_subscriber_activity_mixpanel`, `dim_users`, or `identify` mapping table — pick the join that matches the list's grain).
3. Per-user modal `mp_reserved_os` over a recent window (e.g., last 30–90 days).
4. Return a single CSV: `<dave's identifier>, is_mac (Y/N), modal_os, last_event_date, event_count_in_window`.
5. Flag users with no Mixpanel events in the window — they will not get an OS classification.

## Open questions for Dave (resolve before/with the list)

- What identifier is on the list? (email, user_id, customer_id)
- What lookback window do you want — last 30 days? 90 days? Lifetime?
- For users with mixed OS history (e.g., Mac at home, Windows at work), do you want them flagged as Mac-eligible if Mac shows up in their history at all, or only if it's their primary OS?
- For users with no Mixpanel events in the window, should they be excluded from the beta or treated as "OS unknown"?
