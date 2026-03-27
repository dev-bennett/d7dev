# Python Scripts & Utilities

Automation scripts and utilities supporting the analytical workflow.

## Structure

- `scripts/<name>.py` -- standalone utility scripts
- `scripts/<domain>/` -- domain-specific script packages (if needed)

## Conventions

@../.claude/rules/python-standards.md

## Expected Scripts

- Repo snapshot ingestion helpers
- Data quality automation
- Report generation utilities
- Cross-reference validation tools

## Not For

- This is NOT an installable Python package
- Heavy data processing belongs in dbt/Snowflake
- One-off analysis queries belong in analysis/ as SQL
