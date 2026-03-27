Data quality and anomaly monitoring:

1. Check etl/quality/ for existing quality checks
2. Check context/dbt/ for model test definitions
3. Assess current state:
   - List all defined quality checks and their targets
   - Flag tables/models without quality coverage
   - Check context/ snapshot freshness
4. If "$ARGUMENTS" specifies a table or metric:
   - Write targeted quality queries (null rates, distribution checks, freshness)
   - Compare against known baselines in knowledge/data-dictionary/
   - Flag anomalies with severity assessment
5. Output findings to analysis/_monitoring/<YYYY-MM-DD>-monitor.md
6. Recommend new quality checks to add to etl/quality/

Present results as a concise dashboard. Prioritize by business impact.
