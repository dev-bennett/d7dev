# Retention Sizing -- Ramp-Up Model

@../CLAUDE.md

Initial deployment (ramp-up) retention model with adjustable funnel parameters for the 5 lifecycle email flows.

## Key Files

- `build_model.py` -- Generates the retention model Excel workbook
- `build_diagram.py` -- Generates the ramp-up flow diagram
- `retention_model.xlsx` -- Scenario planning model (delivery, open, click, retention rates by plan/segment)
- `lifecycle_flow.png/svg` -- Aggregate ramp-up flow diagram
- `notion_exec_summary.md` -- 1-page executive summary for stakeholders
- `notion_full.md` -- Detailed ramp-up design document
- `arpu_tenure_query.sql`, `remaining_tenure_query.sql`, `new_subs_query.sql` -- Supporting Snowflake queries
- `r0.csv`, `r1.csv`, `r2.csv`, `r0-1.csv` -- ARPU, tenure, and new subscriber data
