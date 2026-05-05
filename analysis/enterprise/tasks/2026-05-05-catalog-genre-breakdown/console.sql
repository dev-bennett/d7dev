-- =====================================================================
-- console.sql — Catalog Genre Breakdown (2026-05-05 refresh)
-- Source ticket: Asana 1214517536022273
-- Reference:    Catalog Percentages 0922 (1).xlsx (snapshot Sept 22, 2025;
--               11,500 songs)
-- Source table: soundstripe_prod.content.dim_all_songs_v2
--   - 38,164 rows total
--   - state = 'released' AND soundstripe_original_percentage = 100
--     → 11,320 songs (Soundstripe-original catalog only; excludes
--     content-partner songs which represent ~64% of total released rows)
--   - genre_tags VARIANT (array)  → genre_tags[0] = primary genre
--   - vocal_degree NUMBER {0,1,2,null}  → ordinal mapping confirmed
--     against Sept-22 reference distribution:
--         0 → instrumental (73.83% vs Sept-22 73.55%)
--         1 → background vocal (18.14% vs Sept-22 18.08%)
--         2 → full vocal (8.03% vs Sept-22 8.37%)
-- =====================================================================

-- =====================================================================
-- q01: Catalog distribution by primary genre (Soundstripe-original only)
--   Filter: state = 'released' AND soundstripe_original_percentage = 100
--   Grain : 1 row per primary-genre value
--   Output: genre, song_count, pct_of_catalog
-- RATE: pct_of_catalog
--   NUMERATOR  : COUNT(*) songs WHERE filter AND primary_genre = X
--   DENOMINATOR: COUNT(*) songs WHERE filter (Soundstripe-original released)
--   TYPE       : songs_in_genre / total_soundstripe_released_songs
--   NOT        : COUNT(*) over all states or all partners — that would
--                count content-partner songs the prospect doesn't get
-- =====================================================================
WITH released_ss AS (
    SELECT
        id,
        COALESCE(genre_tags[0]::varchar, '<no primary genre>') AS primary_genre,
        vocal_degree
    FROM soundstripe_prod.content.dim_all_songs_v2
    WHERE state = 'released'
      AND soundstripe_original_percentage = 100
)
SELECT
    primary_genre
  , COUNT(*) AS song_count
  , ROUND(COUNT(*) / SUM(COUNT(*)) OVER (), 4) AS pct_of_catalog
FROM released_ss
GROUP BY primary_genre
ORDER BY song_count DESC;

-- TYPE AUDIT — q01:
--   Declared denominator: total Soundstripe-original released songs (11,320)
--   JOIN chain: none (single-table)
--   Column used as denominator: SUM(COUNT(*)) OVER ()
--   Does denominator match declared? YES — window over the same grouped
--     set equals filtered-row total
--   RESULT: PASS

-- =====================================================================
-- q02: Catalog distribution by primary genre × vocal class
--   Same filter; pivot vocal_degree to labelled columns
-- =====================================================================
WITH released_ss AS (
    SELECT
        COALESCE(genre_tags[0]::varchar, '<no primary genre>') AS primary_genre,
        vocal_degree
    FROM soundstripe_prod.content.dim_all_songs_v2
    WHERE state = 'released'
      AND soundstripe_original_percentage = 100
)
SELECT
    primary_genre
  , COUNT_IF(vocal_degree = 0) AS instrumental_count
  , COUNT_IF(vocal_degree = 1) AS background_vocal_count
  , COUNT_IF(vocal_degree = 2) AS full_vocal_count
  , COUNT_IF(vocal_degree IS NULL) AS vd_null_count
  , COUNT(*) AS total
FROM released_ss
GROUP BY primary_genre
ORDER BY total DESC;

-- TYPE AUDIT — q02:
--   Declared denominator: per-genre Soundstripe-released count (`total`)
--   JOIN chain: none
--   Columns: COUNT(*) per group; vocal-class buckets sum to total
--   RESULT: PASS

-- =====================================================================
-- q03: Top-line totals — Soundstripe-original released catalog + vocal mix
-- =====================================================================
WITH r AS (
    SELECT vocal_degree
    FROM soundstripe_prod.content.dim_all_songs_v2
    WHERE state = 'released'
      AND soundstripe_original_percentage = 100
)
SELECT
    COUNT(*) AS released_ss_songs
  , COUNT_IF(vocal_degree = 0) AS instrumental_songs
  , COUNT_IF(vocal_degree = 1) AS background_vocal_songs
  , COUNT_IF(vocal_degree = 2) AS full_vocal_songs
  , COUNT_IF(vocal_degree IS NULL) AS vd_null_songs
  , ROUND(COUNT_IF(vocal_degree = 0)/COUNT(*),4) AS instrumental_pct
  , ROUND(COUNT_IF(vocal_degree = 1)/COUNT(*),4) AS background_pct
  , ROUND(COUNT_IF(vocal_degree = 2)/COUNT(*),4) AS full_vocal_pct
FROM r;

-- =====================================================================
-- q04: Filter discovery — content-partner / Soundstripe-original split
--   Documents how the soundstripe_original_percentage filter was chosen.
--   Validation: SS-only released = 11,320 ≈ Sept-22 reference 11,500
--               (180-song net decline over ~7 months).
-- =====================================================================
WITH r AS (
    SELECT content_partner_id, soundstripe_original_percentage
    FROM soundstripe_prod.content.dim_all_songs_v2
    WHERE state = 'released'
)
SELECT 'cp_null' AS bucket, COUNT(*) AS n FROM r WHERE content_partner_id IS NULL
UNION ALL SELECT 'cp_not_null', COUNT(*) FROM r WHERE content_partner_id IS NOT NULL
UNION ALL SELECT 'distinct_cp_ids', COUNT(DISTINCT content_partner_id) FROM r
UNION ALL SELECT 'sop_100 (soundstripe original)', COUNT(*) FROM r WHERE soundstripe_original_percentage = 100
UNION ALL SELECT 'sop_0 (content partner)',         COUNT(*) FROM r WHERE soundstripe_original_percentage = 0
UNION ALL SELECT 'sop_intermediate (0<x<100)',      COUNT(*) FROM r WHERE soundstripe_original_percentage > 0 AND soundstripe_original_percentage < 100
UNION ALL SELECT 'total_released', COUNT(*) FROM r;
