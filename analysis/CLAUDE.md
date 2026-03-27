# Analysis Workspace

Analytical outputs organized by domain and timestamped for tracking.

## Structure

- `analysis/<domain>/<YYYY-MM-DD>-<slug>.md` -- individual analyses
- `analysis/_templates/` -- output templates (do not modify without review)

## Conventions

- File naming: `YYYY-MM-DD-<descriptive-slug>.md`
- Every analysis must use a template from `_templates/` as starting structure
- Status tags in frontmatter: `draft` | `reviewed` | `final`
- Include the SQL queries that produced each finding
- Reference `knowledge/data-dictionary/` for metric definitions
- Cross-reference related analyses and KB articles
