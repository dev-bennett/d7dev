# d7dev -- Analytical Command Center

Orchestration brain for principal analyst workflow across dbt + Snowflake + Looker.

## What This Is

An AI-assisted analytical workspace that coordinates:
- **LookML development** -- model, view, explore, and dashboard creation
- **Analysis & modeling** -- business model building, metric analysis, signal detection
- **ETL / data engineering** -- SQL transforms, pipeline building, data quality
- **Knowledge capture** -- documentation, data dictionary, institutional knowledge

## Structure

- `analysis/` -- Analysis outputs organized by domain
- `context/` -- Ingested repo snapshots (dbt, LookML) for reference
- `knowledge/` -- Knowledge base (domains, data dictionary, runbooks, decisions)
- `lookml/` -- LookML development workspace
- `etl/` -- ETL / data engineering workspace
- `scripts/` -- Python utilities
- `tests/` -- Test suite for Python scripts

## Stack

- **Warehouse**: Snowflake
- **Transforms**: dbt (external repo)
- **Reporting**: Looker (external repo)
- **Scripts**: Python 3.12+
- **AI**: Claude Code with specialized agents

## Getting Started

1. Clone this repo
2. Install dev tools: `pip install -e ".[dev]"`
3. Ingest repo snapshots: `/ingest dbt` and `/ingest lookml`
4. Start working: `/status` for project health
