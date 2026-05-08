---
table: soundstripe_prod.content.dim_all_songs_v2
last_calibrated: 2026-05-05
schema_hash: fc3bdd9386320ecdc0da062878dd581e281ade902b234739b7ab632e2d4928ad
dbt_model: marts/content/dim_all_songs_v2.sql
row_count: 38164
bytes_gib: 0.0156
col_count: 57
---

# soundstripe_prod.content.dim_all_songs_v2 — Calibration

## Purpose (business meaning)

Canonical song-level dimension. One row per song across both Soundstripe-original and content-partner sources. Used for catalog reporting, song-level joins from sales/play/download fact tables, and genre/vocal-class analytics. Supersedes `content.dim_all_songs` (v1) — v2 adds vocal_degree and several Cyanite-derived metadata fields.

## Lineage

- **dbt model:** `context/dbt/models/marts/content/dim_all_songs_v2.sql`
- **Upstream sources:**
  - `source('soundstripe', 'audio_files')` — vocal_degree comes from here, deduped by song picking the highest vocal_degree for primary=true files within a 3-hour upload window, otherwise the most recent.
  - `source('soundstripe', 'songs')` — main song attributes (title, state, genre_tags, soundstripe_original_percentage, etc.)
  - Joined to artist tables (`artist_songs`, `artists`) via array_agg
- **Materialization:** `table` (full rebuild on each run, not incremental)
- **No incremental watermark concerns.**

## Columns (primary + frequently used)

| Column | Type | Source | Description | Known nulls / gotchas |
|---|---|---|---|---|
| id | NUMBER | songs.id | Primary key | not null |
| title | TEXT | songs.title | Song title | not null |
| state | TEXT | songs.state | Lifecycle state. Values: `released` (30,860), `archived` (5,264), `submitted` (1,499), `denied` (540), `approved` (1) | always populated |
| genre_tags | VARIANT | songs.genre_tags | Array of genre strings; `genre_tags[0]::varchar` is the primary genre | 78 rows have `<null>` first element across all states; **0 nulls in `released AND soundstripe_original_percentage = 100`** subset |
| has_vocals | BOOLEAN | songs.has_vocals | Song-level "has any vocal version" flag | Does NOT mirror vocal_degree exactly — has_vocals=true songs can have primary audio file with vocal_degree=0 (instrumental cut is the primary) |
| vocal_degree | NUMBER | audio_files.vocal_degree | 0/1/2 ordinal (see Known pitfalls for label mapping) | 1,002 nulls across all 38,164 rows; 0 nulls in released-state subset |
| soundstripe_original_percentage | NUMBER | songs.soundstripe_original_percentage | 100 = Soundstripe original; 0 = content partner; values 0<x<100 are extremely rare (1 song in released set) | not null |
| content_partner_id | NUMBER | songs.content_partner_id | FK to content_partners; **NOT a clean Soundstripe-vs-partner discriminator** — both Soundstripe-original songs and partner songs have non-null partner ids | 43 nulls in released set out of 30,860 |
| released_at | TIMESTAMP_NTZ | songs.released_at | Date the song went into the released state | populated for all `released` rows |
| archived_at | TIMESTAMP_NTZ | songs.archived_at | Date the song was archived (NULL for currently-released songs) | NULL for active catalog |
| approved_at, created_at, updated_at | TIMESTAMP_NTZ | songs.* | Lifecycle timestamps | — |
| mood_tags, instrument_tags, characteristic_tags, keywords | VARIANT | songs.* | Tag arrays; like genre_tags, position 0 is the primary | — |
| bpm, energy, key, explicit, single_instrument | NUMBER/TEXT/BOOLEAN | songs.* | Musical metadata | — |
| isrc, spotify_id, apple_id, daaci_id, soundmouse_track_id | TEXT/NUMBER | songs.* | External identifiers | trimmed to NULL when length=0 |
| cyanite_track_id, cyanite_metadata, cyanite_processed | NUMBER/VARIANT/BOOLEAN | songs.* | Cyanite AI metadata | — |
| sales_count, monthly_sales_count | NUMBER | songs.* | Pre-aggregated sales counters from the source | — |

Full schema: 57 columns. Run `SELECT * FROM soundstripe_prod.content.dim_all_songs_v2 LIMIT 1` for the full schema-peek.

## Canonical joins

| To table | On | Cardinality | Notes |
|---|---|---|---|
| `core.fct_song_monetization_allocated_summary` | `dim_all_songs_v2.id = fct.song_id` | 1:N | song-level monetization roll-up |
| `pc_stitch_db.soundstripe.sales` | `dim_all_songs_v2.id = sales.sellable_id AND sales.sellable_type = 'Song'` | 1:N | per-download / per-license event grain |
| `pc_stitch_db.soundstripe.artist_songs` → `artists` | already array_agg'd into the dim | — | artist names embedded as arrays inside the dim |

## Grain & identity

- **Grain:** one row per song (regardless of state — released, archived, etc.)
- **Primary key:** `id`
- **De-dup logic on audio_files:** the model picks one primary audio file per song using:
  - within a 3-hour upload window across primary files, take the one with the highest `vocal_degree`
  - across files >3 hours apart, take the most recent `created_at`
  - then keeps `row_number() over (partition by song_id order by created_at desc) = 1`

## Typical usage patterns

- **Catalog count for sales:** `WHERE state = 'released' AND soundstripe_original_percentage = 100` — the **only** filter pair that returns the Soundstripe-owned active catalog (11,320 rows as of 2026-05-05). Without the second predicate, you get content-partner songs too (~63% of the released set), which a sales prospect or partner would not consider part of "our catalog."
- **Primary genre:** `COALESCE(genre_tags[0]::varchar, '<no primary genre>')`. The released+SS subset has zero null primary-genre rows; full-table queries should still bucket nulls.
- **Vocal classification:** see Known pitfalls for the 0/1/2 → label mapping.
- **As-of-date catalog reconstruction:** `released_at <= D AND (archived_at IS NULL OR archived_at > D)` — verified to within 3% against an external Sept 22, 2025 snapshot (11,164 reconstructed vs 11,500 reported).
- **Date scoping:** not strictly necessary (38K rows is dim-grain), but date-scoping `released_at` is appropriate for as-of-date queries.

## Known pitfalls

- **`soundstripe_original_percentage` is the catalog-scope discriminator, NOT `content_partner_id`.** `content_partner_id` is non-null on essentially all songs (only 43 nulls of 30,860 released; just 2 distinct partner ids); both Soundstripe-original and partner songs carry partner ids. The clean discriminator is `soundstripe_original_percentage = 100` (Soundstripe-original) vs `= 0` (content partner). One song in the released set is intermediate (0 < x < 100). Verified 2026-05-05 against `analysis/enterprise/tasks/2026-05-05-catalog-genre-breakdown/`.
- **`vocal_degree` 0/1/2 → label mapping** (validated 2026-05-05 against Sept 22, 2025 reference distribution; mapping is **only stable on the `soundstripe_original_percentage = 100` subset** — including content-partner rows produces a different vd1/vd2 distribution that misleads label inference):
  - `vocal_degree = 0` → instrumental (no vocals)
  - `vocal_degree = 1` → background vocal
  - `vocal_degree = 2` → full vocal
  - Source schema (`pc_stitch_db.soundstripe.audio_files.vocal_degree`) has no docstring; the mapping is the natural ordinal reading and matches the Sept-22 distribution within decimal precision (instrumental 73.83% / 18.14% / 8.03% vs reference 73.55% / 18.08% / 8.37%).
- **`has_vocals` (BOOLEAN) does NOT cleanly correlate with `vocal_degree`.** A song with `has_vocals = true` may have its primary audio file at `vocal_degree = 0` (the instrumental cut was selected as primary). Use vocal_degree for catalog-distribution analytics, has_vocals only as a song-level marker.
- **Genre taxonomy expansion.** As of Sept 22, 2025 and 2026-05-05, the catalog uses 54 distinct primary genres on Soundstripe-only songs. The Sept-22 xlsx referenced in Asana ticket 1214517536022273 used 21 hand-rolled buckets — **this rollup is NOT in the warehouse.** Reverse-engineering the 21-bucket mapping from data alone is unreliable; obvious groupings (Rock family, Electronic family, Soundtrack family) reconcile poorly to the xlsx's per-bucket totals. Garrett (per Mike Zarrilli's Asana note) is the originator of the Sept 2025 mapping.
- **`dim_all_songs` (v1) coexists.** v1 has 67,471 rows (more permissive scope) and lacks vocal_degree. Always prefer v2 unless explicitly working on a historical comparison that needs v1's set.

## Cost profile (from query_history)

- Single-table aggregates against the full 38K rows: <1s elapsed, <50 MB scanned. Genuinely cheap.
- No date-scoping required.

## Prior analyses referencing this table

- [analysis/enterprise/tasks/2026-05-05-catalog-genre-breakdown/](../../../analysis/enterprise/tasks/2026-05-05-catalog-genre-breakdown/) — catalog refresh by primary genre × vocal class for an enterprise sales prospect; Soundstripe-original filter discovery.

## LookML semantics (if applicable)

- View: `context/lookml/views/Music/dim_soundstripe_production_songs.view.lkml` — exposes `vocal_degree` as `type: number` with no labelled enum (no decoder for 0/1/2 in LookML either; this calibration artifact is the canonical reference).
