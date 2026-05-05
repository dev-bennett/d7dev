# Legit Traffic — Tier Definitions

Companion to `findings_non_current_customer.md` in the same task folder.
Author: d7admin / Devon Bennett · 2026-04-27 · Stakeholder: Sourav (CFO)

## The question

What fraction of NC traffic represents real human prospects ("legit at-bats") vs technical artifacts (bots, pre-render, scrapers, ops noise)? The 2026-03-05→03-25 Fastly POP artifact and 2026-04-14→04-17 APAC spike are documented as obviously contaminated; what's the equivalent diagnostic for the steady-state baseline?

## §12 ALIGNMENT CHECK

```
INTERVENTION: filter NC traffic reporting to a "legit at-bat" cohort for KPI tracking,
              segment-share trending, and pre/post comparisons that need to net out noise
TEMPORAL MECHANIC OF INTERVENTION: state-driven (filter applied at reporting time)
TEMPORAL MECHANIC OF DEFINITION: per-session attribute (each session evaluated independently
                                  against a deterministic predicate over fct_sessions columns)
MATCH: YES — session-grain filter aligns with state-driven reporting
SIZING SANITY: NC Organic ~5,000 sessions/day post-clean window. Legit-at-bat fraction
               expected 30–70%. <20% suggests filter too tight; >90% suggests filter too loose.
```

## Signals available in `fct_sessions`

Per the calibration artifact at `knowledge/data-dictionary/calibration/core__fct_sessions.md`:

| Signal | Column(s) | What it indicates |
|---|---|---|
| Single-pageview bounce | `bounced_sessions = 1` (= `pageviews = 1`) | Pre-render artifacts and many scrapers fire one pageview and exit |
| Time-on-site near zero | `session_duration_seconds ≤ 1` | Instant-redirect bots, pre-render cache-fill, link-checker tools |
| Page depth | `pageviews ≥ 2` | Real humans typically navigate beyond the landing page when intent exists |
| Behavioral engagement | `played_songs_count`, `searched_songs_count`, `downloaded_songs_count`, `searched_sound_effects_count`, `played_sound_effects_count`, `downloaded_sound_effects_count` | Soundstripe-specific human-action signatures (a bot enumerating asset URLs doesn't fire Played Song / Downloaded Song) |
| High-intent funnel events | `enterprise_form_submissions`, `signed_up`, `signed_in`, `created_subscription`, `purchased_product` | Definitive prospect signal |
| Returning-visitor signal | `session_counter > 1` | This `distinct_id` has prior session history — bots typically present as session_counter = 1 (fresh ID per visit) |
| Country anomaly | `country` | Used for the documented contamination filters; could also be flagged as anomalous when concentration in non-target geos spikes |
| Channel | `last_channel_non_direct`, `channel`, `referrer` | NULL referrer post-cutover Direct sessions are the contamination signature; clean Organic should have a referring search engine |
| Identity | `user_id IS NULL`, `is_existing_subscriber` | Already used in NC segmentation |
| Asset-detail enumeration | `landing_page_path LIKE '%/library/sound-effects/%' OR LIKE '%/library/songs/%'` (high concentration) | The 2026-04-17 APAC spike concentrated on these paths; legitimate SEO traffic distributes across more landing types |

Not available in fct_sessions: IP, ASN, user-agent string. Without these, IP-based filters and bot-fingerprint detection are out of scope at this layer.

## Documented contamination signatures (date-bounded; carryover from parent task)

These are AUTHORITATIVE filters from `core__fct_sessions.md` pitfalls #1 and #2:

```
Contamination Window 1 (Fastly POP / pre-render artifact, engineer-confirmed):
  date BETWEEN 2026-03-05 AND 2026-03-25
  AND last_channel_non_direct = 'Direct'
  AND country IN ('DE','NL','CA')
  AND bounced_sessions = 1

Contamination Window 2 (APAC spike, root cause OPEN):
  date BETWEEN 2026-04-14 AND 2026-04-17
  AND last_channel_non_direct = 'Direct'
  AND country IN ('CN','SG','VN','HK','JP')
  AND bounced_sessions = 1
```

## Tier framework (nested — each tier is strictly more restrictive)

**T0 — All NC sessions.** Baseline. `is_existing_subscriber = false`.

**T1 — Documented contamination removed.** T0 minus the two date-bounded contamination signatures above. The known artifact tier.

**T2 — Generic technical-artifact filter (always applied, not date-bounded).** T1 minus sessions matching:

```
pageviews = 1 AND session_duration_seconds ≤ 1
```

Rationale: a real human takes more than one second to load a page and bounce — even an unintentional click registers a few seconds. This signature is consistent with pre-render bots, link-checker tools, instant-redirect events. Conservative threshold (≤ 1s); could be tightened to ≤ 3s as a sensitivity test.

**T3 — Engagement-positive prospect.** T2 AND at least one of:

```
pageviews >= 2
OR played_songs_count > 0
OR searched_songs_count > 0
OR downloaded_songs_count > 0
OR searched_sound_effects_count > 0
OR played_sound_effects_count > 0
OR downloaded_sound_effects_count > 0
OR enterprise_form_submissions > 0
OR signed_up > 0
OR signed_in > 0
OR created_subscription > 0
OR purchased_product > 0
```

Rationale: at least one meaningful interaction beyond the landing page. Real prospects either navigate further into the site OR fire a Soundstripe-specific human-action event. The action events are particularly hard to spoof — a scraper enumerating asset URLs doesn't fire `Played Song`.

**T4 — High-engagement prospect (sensitivity, not headline).** T3 AND `session_duration_seconds >= 30`. Optional stricter floor for "considered evaluation"; not the primary headline because a legitimate scan-and-decide visit can resolve in 15–25 seconds.

## Cross-cut: returning vs first-time (orthogonal to tier)

`session_counter` is the within-visitor ordinal session number. Within any tier, partition by:

- **First-time** (`session_counter = 1`) — top-of-funnel acquisition events; the dominant population for SEO acquisition reporting
- **Returning** (`session_counter >= 2`) — mid-funnel evaluation behavior; smaller absolute count, higher per-session intent

Bot/scraper traffic typically presents as `session_counter = 1` (fresh distinct_id per visit). Persistent `session_counter > 1` is a strong human signal. Worth reporting both fractions per tier, but it's not a tier filter on its own.

## Sizing queries

Drafted as q9–q12 in `console.sql`:

- **q9** — tier sizing: NC sessions/day per tier (T0/T1/T2/T3/T4) × channel × pre/post-clean windows. Produces the headline at-bat fractions.
- **q10** — tier × returning-vs-first-time cross-cut on NC Organic Search.
- **q11** — DID under each tier: re-runs the q4 DID construct (DoW-aligned 2025 anchors) at T1, T2, T3 for NC Organic. Confirms whether the +29.5/+49.6pp headline survives or tightens under noise removal.
- **q12** — known-bad-signature audit: distribution of NC sessions where (`pageviews = 1 AND session_duration_seconds ≤ 1`) by country × channel × week, surfacing any non-documented contamination patterns.

## Limitations

- **Sophisticated bots simulate human behavior** — sleep delays, multi-pageview crawls, even fake event firing. T2/T3 catches the cheap stuff; the residual bot tail is unbounded without IP/ASN data.
- **Engagement-positive ≠ prospect** — a free-tier user logging in to download a song is engagement-positive but may not be a meaningful "at-bat" for new-customer acquisition. Combine with NC-segment definitions where targeting matters.
- **Tier filters are session-level only** — visitor-grain quality (e.g., "this distinct_id only ever bounces") would require an additional aggregation layer.
- **Country concentration filters are authoritative ONLY for documented windows.** A new contamination event with a different geographic signature would not be caught until investigated.

## Open questions for review

1. T2 threshold (`pageviews = 1 AND duration ≤ 1`) — keep at ≤ 1s, or tighten to ≤ 3s? Would q12 results show a continuous duration distribution or a distinct cluster at near-zero?
2. T3's pageviews-OR-engagement is permissive (catches 2-pageview bouncers). Acceptable, or should T3 require BOTH `pageviews ≥ 2` AND at least one engagement event?
3. Should `is_mobile_app = 1` sessions be excluded from NC analysis entirely? They're authenticated app users — by definition signed-in, but Def A includes free-tier non-subscribers. Worth a side note rather than a tier filter.
4. Reporting cadence — is this a one-time sizing exercise, or a permanent reporting layer Sourav wants ongoing visibility into?

## Results — sizing under the proposed framework

### NC sessions per tier × channel × window (q9)

Post-clean window (2026-03-26 → 2026-04-13, 19d):

| Channel | T0 | T2 | T3 | T3 share |
|---|---:|---:|---:|---:|
| NC Organic Search | 95,234 | 68,286 | 54,605 | **57%** |
| NC Paid Search | 22,793 | 15,652 | 13,743 | **60%** |
| NC Referral | 8,960 | 5,590 | 3,828 | 43% |
| NC Organic Social | 1,585 | 874 | 522 | 33% |
| NC Affiliate | 1,239 | 426 | 301 | 24% |
| NC Direct | 135,800 | 67,620 | 25,307 | **19%** |
| NC Paid Content | 13 | 2 | 2 | 15% |
| NC Paid Social | 1,290 | 306 | 100 | **8%** |
| NC Email | 6,120 | 2,071 | 432 | **7%** |

**T3 share cross-validates with q7 conversion CVR:** Organic and Paid Search are the real-prospect channels (57–60% T3, moderate-to-high session-CVR). Direct, Email, Paid Social are noise-heavy (7–19% T3, low or zero CVR). NC Direct loses 81% of its volume to the T3 filter — most NC Direct is technical-artifact / pre-render / automated traffic, not real prospect traffic.

### NC Organic DID under tier filters (q11)

| Tier | 2025 pre | 2026 pre | YoY pre | 2025 post | 2026 post | YoY post | **DID** |
|---|---:|---:|---:|---:|---:|---:|---:|
| T0 raw | 5,326/d | 3,225/d | −39.4% | 4,547/d | 5,012/d | +10.2% | **+49.6pp** |
| T1 contam-removed | (same — windows are clean) | | | | | | +49.6pp |
| **T2** instant-bounce removed | 3,114/d | 2,196/d | −29.5% | 2,752/d | 3,594/d | +30.6% | **+60.1pp** |
| **T3** engaged only | 2,806/d | 1,773/d | −36.8% | 2,476/d | 2,874/d | +16.1% | **+52.9pp** |

The +49.6pp headline DID survives noise removal at every tier and strengthens at T2. Decomposing the post-cutover growth: T0 grew +55%/d, T2 grew +64%/d, the noise-only band (T0 − T2) grew only +38%/d. The consolidation lift is concentrated in the non-noise cohort, not in instant-bounce traffic. The headline understates real-prospect incrementality if anything.

### First-time vs returning on NC Organic (q10)

Post-cutover returning-visitor share dropped from 31% (pre) to 21% (post). New SEO traffic is overwhelmingly first-time visitors. Consistent with mix-shift: the broader landing-path surface is bringing in net-new humans, not driving return visits from a pre-existing audience.

### Previously undocumented pattern surfaced by q12

Persistent CN Direct instant-bounce baseline OUTSIDE the documented contamination windows: ~3–11K sessions/week throughout Jan–April, steady-state. Same shape at lower magnitude on DE, NL, SG, BD. The Tier 1 date-bounded contamination filter does not catch this — Tier 2 (instant-bounce predicate) does.

The documented windows captured spikes (e.g., week of 2026-03-16: DE 80,985 sessions, NL 42,348 sessions). The persistent baseline implies an always-on bot/scraper presence the Fastly mitigation hasn't addressed. Estimated ~5–10K CN Direct instant-bounce sessions/week × ~17 weeks in the pre-cutover Jan–March stretch ≈ 85–170K artifact sessions in baseline — material noise floor on Direct-channel reporting.

**Recommendation:** flag this for engineering follow-up alongside the 2026-04-17 spike investigation. The CN Direct steady-state baseline is a Tier-2-catchable artifact; not in headline scope but worth documenting.

## Recommended application

For Sourav's reporting and the next 12-week recheck:

- **Headline NC Organic incrementality:** report at T0 (current parent task convention) AND T3 (legit-at-bat). The DID is consistent across both; reporting both bounds the noise-impact assessment.
- **Channel-level acquisition KPIs:** use T3 (engaged-positive) as the headline filter. The 7–19% T3 share for Email/Paid Social/Direct surfaces noise that all-traffic reporting masks.
- **CVR reporting:** T3-filtered denominator paired with absolute conversions/day (per the parent CVR finding). T3 stabilizes the denominator against per-session quality drift.
- **Direct-channel persistent CN baseline:** flag for Luke / engineering as a follow-up to the 2026-04-17 spike investigation.

## Status

- 2026-04-27 — definitions framework drafted; q9–q12 executed; results integrated above.
- Open questions for Devon: (1) tier thresholds — keep T2 at duration ≤ 1s? (2) T3 OR vs AND? (3) treat is_mobile_app as a tier filter? (4) one-time vs ongoing reporting layer?
