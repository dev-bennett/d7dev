# Catalog Genre Breakdown

**Status:** complete — handed off to user for Asana ticket close-out. Deliverable: Soundstripe-original released catalog (11,320 songs) at 54-primary-genre detail; output-medium and 21-bucket rollup deferred to user discretion.
**Asana ticket:** [1214517536022273](https://app.asana.com/1/411777761188590/project/1205525083743256/task/1214517536022273)
**Requester:** Mike Zarrilli
**Assignee:** Devon Bennett
**Department:** Enterprise
**Created:** 2026-05-04
**Original due:** 2026-05-04
**Hours estimate:** 2

## Ask (verbatim from ticket)

> Devon, I have this collection data (attached) from back in September
> from I think Garrett. Do you happen to have an updated look at our
> collection by genre that I could share with a potential client?
> — Mike Zarrilli

## Reference attachment

`Catalog Percentages 0922 (1).xlsx` (13 KB, Asana attachment gid
`1214517536022281`). Snapshot date: **September 22, 2025**. Imported
2026-05-05.

### Sept 22, 2025 reference format (decoded from xlsx)

**Total catalog at the time:** 11,500 songs (Soundstripe-original).

**Table 1 — Genre × catalog (cols A:C):**
- one row per genre (21 genres, listed below)
- columns: genre, percent_of_catalog, song_count
- 100% sum check in row 24

**Table 2 — Genre × vocal classification (cols G:K, M:P):**
- one row per genre × {background_vocal, full_vocal, instrumental, total}
- left half (H:K): percentage of total catalog
- right half (M:P): song counts
- column total split (Sept 2022): background_vocal 18.08%,
  full_vocal 8.37%, instrumental 73.55%

**Genre enumeration (21):** Acoustic, Ballad, Blues, Cinematic,
Classical, Corporate, Country, Electronic, Experimental, Folk, Funk,
Gospel, Hip Hop, Holiday, Indie, Jazz, Pop, R&B, Rock, Soundtrack, World.

## Resolved during build

- **Source table:** `soundstripe_prod.content.dim_all_songs_v2`.
- **Filter:** `state = 'released' AND soundstripe_original_percentage = 100`
  (Soundstripe-original active catalog only; excludes content-partner
  songs).
- **Vocal-class mapping:** `vocal_degree` 0=instrumental, 1=background,
  2=full vocal — confirmed by distributional match to Sept 22, 2025
  reference within decimal precision.
- **Genre taxonomy:** expanded from 21 (2025 file) to 54 (2026 catalog)
  primary genres. Comparison rollups inline in `findings.md`.

## Open question

- **Output medium:** xlsx vs CSV. Sept 22, 2025 reference is xlsx; this
  workspace ships CSVs that open directly in Excel with the same shape.
  Confirm preference before sending to Mike.

## Status log
- 2026-05-05: Workspace scaffolded; attachment imported and decoded.
- 2026-05-05: Source identified
  (`soundstripe_prod.content.dim_all_songs_v2`); first run included
  content-partner songs (30,860 released) — wrong scope.
- 2026-05-05: Filter corrected to Soundstripe-original
  (`soundstripe_original_percentage = 100` → 11,320 released);
  reference date corrected to Sept 22, 2025; vocal-degree mapping
  confirmed against the 2025 distribution; q01–q04 in `console.sql`,
  CSVs and findings.md regenerated.
- 2026-05-05: Investigated 21-bucket rollup question — the 2025 file's
  21 buckets are a hand-rolled grouping (not a warehouse dimension);
  catalog has had 54 distinct primary genres on both dates. Closing
  task here; user owns the Asana ticket reply.
