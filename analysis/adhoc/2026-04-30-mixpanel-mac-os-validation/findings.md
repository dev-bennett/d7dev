---
title: Mixpanel device/OS validation — Mac users
date: 2026-04-30
status: final
source_table: pc_stitch_db.mixpanel.export
window: 2026-04-22 to 2026-04-28 (7 days)
---

# Validation: Mac users distinguishable from `pc_stitch_db.mixpanel.export`

## Question

Does the warehouse carry device-level data sufficient to identify Mac (desktop macOS) users, so that a Mac-only cohort can be defined?

## Answer

Yes. `mp_reserved_os` on the raw Mixpanel export carries the OS label, with 99.4% fill across 11.27M event rows over the 7-day validation window.

Mac users are identified by:

```sql
mp_reserved_os IN ('Mac', 'Mac OS X')
```

Two distinct strings (`Mac`, `Mac OS X`) both correspond to desktop macOS — confirmed via user-agent spot-check (`Macintosh; Intel Mac OS X 10_15_7` UA across both label values). Likely artifact of different Mixpanel SDK versions writing the OS label differently.

## Coverage (window: 2026-04-22 to 2026-04-28)

- Total rows: 11,267,602
- Distinct users (`distinct_id`): 157,114
- Mac users: 19,754 (12.77% of users)
  - `Mac`: 15,503 (10.02%)
  - `Mac OS X`: 4,251 (2.75%)

User-grain methodology: per-user modal `mp_reserved_os` over the 7-day window (most-frequent OS label per `distinct_id`).

## Column inventory

`mp_reserved_os`-ranked by usefulness for desktop OS identification, fill rates from `console.sql` q2:

| Column | Fill rate | Notes |
|---|---|---|
| `mp_reserved_os` | 99.4% | Primary OS label. Discrete values: `Mac`, `Mac OS X`, `Windows`, `iOS`, `iPadOS`, `Android`, `Linux`, `GNU/Linux`, `Ubuntu`, `Chrome OS`, etc. |
| `mp_reserved_browser` | 99.8% | `Chrome`, `Safari`, `Firefox`, etc. — not OS, but useful as cross-check. |
| `mp_reserved_device` | 90.4% | Device family string (often empty for desktop). |
| `user_agent` | 88.6% | Raw UA; can parse `Macintosh; Intel Mac OS X` or `Macintosh; Apple M` substrings as a fallback. |
| `mp_reserved_user_agent` | 0% | Effectively unused — do not query. |
| `platform` | 0.00004% | 5 rows out of 11.27M — do not query. |
| `mobile_app_os` | 1.1% | Mobile app events only; irrelevant for desktop Mac. |
| `source_platform` | 0% | Unused. |
| `host_application` | 0% | Unused. |

## Distinct OS values (window: 2026-04-22 to 2026-04-28)

| `mp_reserved_os` | Users | Share |
|---|---:|---:|
| Windows | 91,033 | 58.84% |
| Android | 21,535 | 13.92% |
| iOS | 16,211 | 10.48% |
| **Mac** | **15,503** | **10.02%** |
| **Mac OS X** | **4,251** | **2.75%** |
| Chrome OS | 4,054 | 2.62% |
| Linux | 1,248 | 0.81% |
| GNU/Linux | 736 | 0.48% |
| iPadOS | 93 | 0.06% |
| HarmonyOS | 32 | 0.02% |
| Ubuntu | 14 | 0.01% |
| (12 more, all < 5 users) | | |

## Constraints / caveats

1. **Source table only.** `mp_reserved_os`, `mp_reserved_browser`, `mp_reserved_device`, `user_agent`, and `mp_lib` are all dropped from `core.fct_events`. Mac-cohort analyses must query `pc_stitch_db.mixpanel.export` directly. Calibration: `knowledge/data-dictionary/calibration/pc_stitch_db__mixpanel__export.md`.
2. **Date-scope mandatory.** 2.18B rows / 233.5 GiB in the raw table. Every query must include a `time::date` predicate.
3. **"Mac" excludes iOS and iPadOS.** If the question is "Apple devices" rather than "Mac computers", expand the filter to include `iOS` (10.48%) and `iPadOS` (0.06%).
4. **Two-string OS labeling is a minor data-quality nit.** Both `Mac` and `Mac OS X` map to desktop macOS — the difference appears to be SDK-driven, not platform-driven. Always include both in the filter.

## Adversarial check

- **Q1 — what would a skeptic challenge first?** The split between `Mac` and `Mac OS X` strings. Addressed: q4 user-agent spot-check shows both label values carry `Macintosh; Intel Mac OS X` UA strings, confirming both are desktop macOS.
- **Q2 — what assumption would flip the conclusion?** If `mp_reserved_os` fill on Mac users specifically were systematically lower than the 99.4% global rate, Mac coverage would be undercounted. q3's user-grain methodology requires `mp_reserved_os IS NOT NULL`, so the 19,754 figure is a floor; the true Mac count could be marginally higher among the ~700 users (0.6%) with no OS label in the window.
- **Q3 — what's the next question?** Whether `mp_reserved_os` is stable across a single user's session history (e.g., a user on Mac at home and Windows at work). For cohorting, recommend treating any user whose modal OS in the analysis window is `Mac`/`Mac OS X` as a Mac user; cross-device users will be a small mix-attribution cost.
- **Q4 — intervention class?** INFORMATIONAL. The data exists, fill is high, the filter is clean. No structural fix required.
