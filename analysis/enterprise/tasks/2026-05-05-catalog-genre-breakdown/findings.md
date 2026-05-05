# Catalog Genre Breakdown — 2026-05-05 refresh

Updated catalog distribution by genre and vocal class for sharing with
the prospective enterprise client. Refreshes the September 22, 2025
snapshot attached to Asana ticket
[1214517536022273](https://app.asana.com/1/411777761188590/project/1205525083743256/task/1214517536022273).

## Headlines

- Soundstripe-original released catalog: **11,320 songs** (Sept 22, 2025
  snapshot: 11,500 — 180-song net decline over ~7 months).
- Top 5 genres cover 41.8% of the catalog: Electronic (10.7%),
  Hip Hop (9.9%), Soundtrack / Cinematic (7.2%), Acoustic (7.2%),
  Rock (6.9%).
- Top 10 covers 65.5%; the long tail is spread across 44 finer genres.
- Vocal split: instrumental 73.83% / background vocal 18.14% /
  full vocal 8.03%. Within decimal precision of Sept 2025
  (instrumental 73.55% / background 18.08% / full 8.37%).

## Methodology

- Source: `soundstripe_prod.content.dim_all_songs_v2`, the canonical
  song-level dimension (38,164 rows total).
- Filter: `state = 'released' AND soundstripe_original_percentage = 100`.
  The first predicate scopes to active catalog (excludes archived 5,264 /
  submitted 1,499 / denied 540). The second predicate scopes to
  Soundstripe-original songs only — 11,320 of 30,860 released rows
  (~37%); the remaining 19,540 are content-partner songs that the
  enterprise prospect would not see as part of Soundstripe's owned
  catalog.
- Primary genre: `genre_tags[0]` (first tag in the variant array). The
  Soundstripe-only set has zero `<no primary genre>` rows.
- Vocal class: `vocal_degree` ∈ {0, 1, 2}. Mapping confirmed against
  the Sept 2025 distribution: 0 = instrumental, 1 = background vocal,
  2 = full vocal.

## Genre × catalog (Soundstripe-original released, 54 genres)

Full table in `q01_genre_breakdown.csv`. Top 20:

| Genre | Songs | % of catalog |
|---|---:|---:|
| Electronic | 1,209 | 10.68% |
| Hip Hop | 1,118 | 9.88% |
| Soundtrack / Cinematic | 815 | 7.20% |
| Acoustic | 810 | 7.16% |
| Rock | 775 | 6.85% |
| Indie | 641 | 5.66% |
| Pop | 600 | 5.30% |
| Corporate / Jingle | 553 | 4.89% |
| EDM | 514 | 4.54% |
| Ambient | 458 | 4.05% |
| Classical | 416 | 3.67% |
| R&B | 321 | 2.84% |
| Underscore | 292 | 2.58% |
| Cinematic | 292 | 2.58% |
| World | 290 | 2.56% |
| Score | 240 | 2.12% |
| Jazz | 237 | 2.09% |
| Lo-Fi | 206 | 1.82% |
| Country | 193 | 1.70% |
| Funk | 149 | 1.32% |

(34 additional genres make up the remaining 8.4%; full list in CSV.)

## Genre × vocal class

Full per-genre cross-tab in `q02_genre_x_vocal.csv`. Headline totals:

| Vocal class | Songs | % of catalog |
|---|---:|---:|
| Instrumental | 8,358 | 73.83% |
| Background vocal | 2,053 | 18.14% |
| Full vocal | 909 | 8.03% |
| (unclassified) | 0 | 0.00% |

## Comparison to Sept 22, 2025

The genre taxonomy has shifted. The Sept 2025 file used 21 genre
buckets; today's catalog reports 54 primary genres on Soundstripe-only
songs. Some 2025 buckets split into multiple modern ones (Soundtrack
into Soundtrack / Cinematic + Score + Underscore + Modern Orchestral +
Orchestral; Electronic into Electronic + EDM + Dub Step + Drum & Bass;
World into World + Latin + East Asian + Tribal + African + Bollywood +
Caribbean + Celtic + Middle East). New genre tags also appear in 2026
(Synthwave, Lo-Fi, Ambient, 8-Bit, Soundscape, etc.) that are not in
the 2025 file, suggesting taxonomy expansion during the period.

Direct comparisons where the 2025 bucket maps cleanly:

| Genre | Sept 22, 2025 | 2026-05-05 |
|---|---:|---:|
| Catalog total | 11,500 | 11,320 |
| Acoustic | 5.3% | 7.16% |
| Ballad | 1.3% | 0.80% |
| Blues | 0.6% | 0.37% |
| Cinematic | 2.0% | 2.58% |
| Classical | 5.3% | 3.67% |
| Corporate | 5.8% | 4.89% (Corporate / Jingle) + 0.99% (Corporate) = 5.88% |
| Country | 1.8% | 1.70% (+ 0.08% Traditional Country) |
| Electronic | 13.8% | 10.68% (+ 4.54% EDM, 0.29% Dub Step, 0.12% Drum & Bass) = 15.63% |
| Experimental | 1.3% | 0.54% |
| Folk | 2.2% | 0.39% |
| Funk | 1.5% | 1.32% |
| Gospel | 0.2% | 0.19% |
| Hip Hop | 8.3% | 9.88% (+ 0.58% Rap) = 10.46% |
| Holiday | 0.2% | 0.32% |
| Indie | 6.8% | 5.66% |
| Jazz | 1.7% | 2.09% |
| Pop | 9.9% | 5.30% |
| R&B | 4.2% | 2.84% |
| Rock | 6.7% | 6.85% (+ 0.36% Southern Rock + 0.14% Classic Rock) = 7.35% |
| Soundtrack | 17.5% | 7.20% (Soundtrack / Cinematic) + 2.12% Score + 2.58% Underscore + 1.10% Modern Orchestral + 1.07% Orchestral = 14.07% |
| World | 3.6% | 2.56% (+ 0.70% Latin + 0.18% East Asian + 0.13% Middle East + 0.11% Tribal + 0.10% Celtic + 0.04% African + 0.07% Bollywood + 0.03% Caribbean) = 3.92% |
| Instrumental share | 73.55% | 73.83% |
| Background vocal | 18.08% | 18.14% |
| Full vocal | 8.37% | 8.03% |

Largest moves over the 7-month period (after rolling up split buckets):

- **Pop –4.6pp** (9.9% → 5.3%): biggest mover. Worth a quick check to
  confirm this is curation rather than re-tagging — 540 Pop songs went
  somewhere.
- **Soundtrack –3.4pp** (17.5% → 14.07% rolled up).
- **Folk –1.8pp** (2.2% → 0.39%).
- **R&B –1.4pp** (4.2% → 2.84%).
- **Hip Hop +2.2pp** (8.3% → 10.46% incl. Rap).
- **Electronic +1.8pp** (13.8% → 15.63% incl. EDM family).
- **Acoustic +1.9pp** (5.3% → 7.16%).
- Vocal mix essentially unchanged.

## Output medium

CSVs in this directory match the cross-tab shape of the 2025 xlsx.
Confirm whether to package as xlsx for Mike (xlsx not currently
generated; CSVs open directly in Excel and produce the same shape).

## Files

- `q01_genre_breakdown.csv` — full 54-genre table with song count and %.
- `q02_genre_x_vocal.csv` — per-genre × vocal-class cross-tab.
- `console.sql` — q01–q04 source queries (q04 documents the
  Soundstripe-only filter discovery).
- `Catalog Percentages 0922 (1).xlsx` — Sept 22, 2025 reference
  (imported).
