# Statsig Identifier Mapping and Pulse Exclusions

Last updated: 2026-04-20
Author: Devon Bennett
Status: open (active issue — Finding 6 in `analysis/experimentation/2026-04-18-wcpm-test-audit/findings.md`)

## Purpose

Canonical reference for how Statsig's identifier-mapping rules cause users to be excluded from Pulse results, how to detect the exclusions in our own warehouse, and the current Soundstripe-specific context that makes the issue material.

## Background: Statsig's Enforced 1:1 identifier mapping

Statsig supports multiple identifier-mapping modes. The default, `Enforced 1:1`, requires that each primary identifier (usually `statsig_stable_id`) map to exactly one secondary identifier (usually `user_id`), and vice versa. Records that violate this invariant — a `user_id` with 2+ `statsig_stable_id` values, or a `statsig_stable_id` with 2+ `user_id` values — are disqualified from the analysis population used in Pulse.

Statsig documentation: *"Choosing this mode will change the exposures on the primary ID as it disqualifies any records outside of a 1:1 mapping."*

Statsig's per-experiment diagnostics expose a **Deduplication Rate Check** that reports the share of exposures removed by this filter. Values exceeding a few percent are worth investigating; experiments where the rate is in the double digits indicate systemic identity instability upstream.

## Soundstripe context

### Why this matters for us

Domain consolidation (www.soundstripe.com + app.soundstripe.com → soundstripe.com via Fastly, launched March 2026) introduced widespread `statsig_stable_id` churn. A single logged-in user now commonly carries 2+ stable_ids across surfaces, visits, and browsers. Any experiment that exposes such a user on more than one of their stable_ids trips the 1:1 filter — all of that user's exposures are dropped from Pulse.

### Observed scale (as of 2026-04-20, `wcpm_pricing_test` audit)

| Metric | Value | Source |
|---|---|---|
| Total logged-in user_ids exposed to `wcpm_pricing_test` | 20,072 | q21 |
| → exposed to exactly 1 arm | 17,363 | q21 |
| → exposed to 2 arms | 2,216 | q21 |
| → exposed to 3 arms | 493 | q21 |
| **user_ids 1:1-dropped from Pulse** | **2,709 (~13.5%)** | q21 |
| User_ids with 2+ distinct stable_ids (sprawl) | 3,601 | q21 |
| Maximum stable_ids per user_id | 106 | q21 |

The 13.5% drop rate is at the exposed-population level — every metric read off any Statsig experiment carries a proportional undercount at minimum, and potentially larger bias if sprawl rates differ across arms.

### Raw exposures table behavior

`soundstripe_prod._external_statsig.exposures` is deduped at the stable_id level before landing in the warehouse (no stable_id appears in two arms) but retains user_id-level sprawl. This lets us observe user_id-level conflicts directly — the key fact that makes the 1:1 hypothesis testable against our own data.

`soundstripe_prod._external_statsig."first_exposures_<experiment>"` is the Pulse-facing table; arm sizes match Statsig's Pulse export exactly. Any user dropped by 1:1 enforcement will be present in `exposures` but absent from `first_exposures_<experiment>`.

## Detection queries

See `analysis/experimentation/2026-04-18-wcpm-test-audit/console.sql` for the working versions. Key patterns:

### Global scale check (q21 pattern)

```sql
SELECT
    COUNT(DISTINCT stable_id) AS stable_ids,
    COUNT(DISTINCT user_id) AS user_ids,
    SUM(CASE WHEN arm_count >= 2 THEN 1 ELSE 0 END) AS user_ids_with_multi_arm
FROM (
    SELECT
        user_id,
        COUNT(DISTINCT LOWER(group_name)) AS arm_count
    FROM soundstripe_prod._external_statsig.exposures
    WHERE LOWER(experiment_id) = '<experiment_slug>'
      AND user_id IS NOT NULL
    GROUP BY 1
);
```

If `user_ids_with_multi_arm / user_ids > ~5%`, 1:1 enforcement is materially biasing the experiment.

### Per-user conflict check (q22 pattern)

For a specific user (identified by `user_id` or `stable_id`), list all exposures that match either:

```sql
SELECT
    stable_id,
    user_id,
    LOWER(group_name) AS arm,
    timestamp
FROM soundstripe_prod._external_statsig.exposures
WHERE LOWER(experiment_id) = '<experiment_slug>'
  AND (stable_id = '<suspect_stable_id>' OR user_id = <suspect_user_id>)
ORDER BY timestamp;
```

Multi-arm output → user is 1:1-dropped. Multi-stable_id same-arm output → also 1:1-dropped per Statsig policy (any ambiguity disqualifies).

### Identity sprawl check (q23 pattern)

Independent of Statsig's retention policy — tests whether the necessary condition for 1:1 exclusion exists in our own data:

```sql
SELECT
    user_id,
    COUNT(DISTINCT statsig_stable_id) AS distinct_stable_ids
FROM soundstripe_prod.core.fct_events
WHERE user_id = <suspect_user_id>
  AND statsig_stable_id IS NOT NULL
  AND event_ts::date BETWEEN <pre_experiment> AND <current>
GROUP BY 1;
```

Returns `distinct_stable_ids >= 2` → sprawl present. This is a necessary (not sufficient) condition for 1:1 exclusion.

## Interpretation decision tree

1. User absent from Pulse → query `first_exposures_<experiment>` for their stable_id. If absent, continue.
2. Query raw `exposures` for their stable_id OR user_id.
3. If raw exposures returns >1 arm or >1 stable_id → 1:1 exclusion confirmed.
4. If raw exposures returns exactly 1 row in the expected arm → NOT a 1:1 exclusion. Investigate unit-quality filter, bot classification, or exposure timestamp vs. pulse snapshot cutoff. Check Statsig's console diagnostics for per-user exclusion reason.
5. If raw exposures returns nothing → exposure never fired. Check client-side trigger wiring.

## Mitigation options

Two independent levers, neither yet adopted as of 2026-04-20:

### Lever 1 — Change Statsig mapping mode

Alternative modes: `Most Recent`, `user_id-primary`, `stable_id-primary without enforcement`. Each has a different bias profile. Recommended path:

1. Export the current `wcpm_pricing_test` data and request Statsig to re-run Pulse under each alternative mode.
2. Compare retained-unit count, per-arm effect sizes, and variance.
3. Select the mode that maximizes retained population without introducing a compensating bias (e.g., `Most Recent` may over-weight frequent-visit users).
4. Apply the selected mode as the default for future Soundstripe experiments.

### Lever 2 — Stabilize stable_id at source

Product-engineering work on the Soundstripe client to keep a single `statsig_stable_id` stable across the consolidated domain. Candidates:

- Cookie domain scope (ensure cookie is set at `.soundstripe.com` not the subdomain)
- Cookie `SameSite` and `Secure` attributes
- Statsig SDK init order relative to any user-identification call
- Pre-consolidation stable_ids stored in localStorage vs. cookie — audit which survived the Fastly cutover

Either lever, or both in combination, should bring the 1:1 drop rate below ~2–3% (typical baseline).

## Related artifacts

- `analysis/experimentation/2026-04-18-wcpm-test-audit/findings.md` — primary case study; Finding 6 has the full evidence
- `analysis/experimentation/2026-04-18-wcpm-test-audit/console.sql` q21 (global scale), q22 / q22a (per-suspect), q23 / q23a (sprawl check)
- `.claude/projects/.../memory/project_domain_consolidation.md` — domain consolidation timeline and effects
- `.claude/projects/.../memory/project_wcpm_1to1_mapping_exclusion.md` — open-issue tracker
- `.claude/projects/.../memory/project_statsig_model_late_arrival_open.md` — related but distinct structural finding (Finding 4 of the same audit)
- `knowledge/domains/experimentation/overview.md` — program overview; links here
- `knowledge/domains/experimentation/metrics.md` — metric definitions; applies the undercount caveat surfaced here

## Open questions

- What is Statsig's Deduplication Rate Check reporting for `wcpm_pricing_test` in their console? If it matches ~13.5%, our warehouse-side calculation is corroborated. If it materially differs, we have a second gap to investigate.
- For the 2 residual unexplained purchasers in Finding 6 (e4ba58b5, 2fc757ce), what does Statsig's per-user diagnostics show as the exclusion reason?
- Are other domains (e.g., `marketplace.soundstripe.com`, if applicable) also affected by stable_id churn, or was the Fastly cutover scoped to www+app only?
