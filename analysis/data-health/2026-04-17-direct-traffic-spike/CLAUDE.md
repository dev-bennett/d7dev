# Direct Traffic Spike -- 2026-04-17

@../CLAUDE.md

## Status

**OPEN.** Root cause not confirmed. Scraping hypothesis proposed but unsubstantiated against the leading infrastructure hypothesis carried over from the 2026-04-01 predecessor investigation.

## Observation

- 4/1–4/13 baseline: direct ~5–8K/day, other ~7–12K/day
- 4/14: direct 14,729 (other 12,352)
- 4/15: direct 16,291 (other 12,085)
- 4/16: direct 30,622 (other 10,924)

Other_sessions stable → isolated to Direct attribution. Concentrated on www.soundstripe.com/library/sound-effects/{id}, /library/songs/{id}, /library/video* paths. APAC-sourced (CN dominant, SG/VN/HK/JP). 97% bounce, 33s avg duration, 95% of spike events on asset-detail URLs vs ~12–19% for US control populations.

## Related prior investigation

`../2026-04-01-direct-traffic-spike/` — 16 days earlier, near-identical signature (Chrome, Direct, www host, ~98% bounce, flat coverage). Confirmed root cause (via engineering): Fastly shield POP IP leakage + pre-rendering service cache clears during domain consolidation rollout + Google sitemap resubmission driving aggressive re-crawling. Geo concentration on 04-01 was DE/NL/CA (Fastly shield POP locations); current spike's CN/SG/VN/HK/JP concentration is different but the mechanism (infrastructure-origin traffic classified as Direct) may be the same.

## Leading hypothesis (untested)

A pre-render cache clear, sitemap resubmission, or CDN-config event on or around 2026-04-13 triggered infrastructure-sourced recrawling. Confirm with engineering before pursuing external-scraper hypotheses. Fastly access logs would show UA/IP/ASN that Mixpanel does not.

## Conventions

- Table reference: `soundstripe_prod.core.fct_sessions` (Direct defined as `last_channel_non_direct = 'Direct'`); `pc_stitch_db.mixpanel.export` for raw-source fingerprinting
- Join bridge for fct_events ↔ fct_sessions: `dim_session_mapping`
- All queries appended to `console.sql` in order (q1–q15)
- Result exports land as `qN.csv` alongside the SQL
