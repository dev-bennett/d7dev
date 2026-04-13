# LookML Repo Improvement Parking Lot

- **Last updated:** 2026-04-02
- **Author:** d7admin
- **Status:** Backlog -- items identified during notification dashboard build

## Structural Issues

1. **All 76 explores defined in model files, not dedicated explore files.** `General.model.lkml` alone has 62 explores at 746 lines. Should be refactored into per-domain `.explore.lkml` files per LookML standards.

2. **No data tests exist.** Zero `.test.lkml` files, zero `test:` blocks. Every explore should have at least one data test validating row counts or key constraints.

3. **No refinement files.** All customization is inline. Refinements would allow cleaner separation between base views and per-model overrides.

4. **Temp explores/views accumulating.** `Temp_Explores.model.lkml` (5 explores) and `_TEMP_VIEWS/` (9 views) should be reviewed for promotion or removal.

## Documentation Gaps

5. **Finance views lack descriptions.** `fct_kpis_music`, `fct_kpis_enterprise`, `fct_kpis_partnerships` -- measures have no descriptions, no drill fields.

6. **Production views are raw table dumps.** `songs.view.lkml` (50+ dimensions, zero descriptions), `users.view.lkml` -- no business context on any field.

7. **Missing descriptions on most dimensions across the repo.** Well-documented views (sst_sales, fct_sessions) are the exception, not the rule.

## Code Quality

8. **Syntax error in fct_sessions.view.lkml line 542:** `${TABLE}.enterprise)_form_submissions` -- unmatched parenthesis.

9. **Inconsistent SQL casing:** Mix of `pc_stitch_db` (lowercase) and `PC_STITCH_DB` (uppercase) across views.

10. **Missing explicit type declarations on some dimensions.** Standards require `type` on every dimension.

11. **Missing primary keys on several views.** `artist_metrics` derived table has no primary key defined.

## Architecture

12. **Single connection for everything.** All 6 models use `soundstripe_prod`. Consider whether read-heavy dashboards should use a dedicated warehouse/connection.

13. **Cross-database joins without documentation.** Multiple explores join across `soundstripe_prod` and `PC_STITCH_DB` without noting the performance implications.

14. **Dashboard adoption.** Only 1 LookML dashboard exists (`ad_content_performance`). The rest are presumably user-defined in Looker and not version-controlled.
