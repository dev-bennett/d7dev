#!/bin/bash
# =============================================================================
# C8 -- dbt submodule git-log audit around Feb 2026
# =============================================================================
# Purpose: enumerate every commit to scoring-pipeline models between 2026-01-01
#   and 2026-03-15 with diff summaries. Confirms or expands the seven-commit
#   Feb 2026 cluster (discovery turned these up: 2026-02-02, -09, -10, -19, -25).
# Output: writes to c8-git-audit.txt in the same directory.
# Run from the d7dev repo root: ./analysis/enterprise/pql/tasks/2026-04-15-knowledge-discovery/ryan-feb-score-shift/C8-git-audit.sh
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DBT_SUBMODULE="$SCRIPT_DIR/../../../../../../context/dbt"
OUTPUT="$SCRIPT_DIR/c8-git-audit.txt"

if [[ ! -d "$DBT_SUBMODULE/.git" && ! -f "$DBT_SUBMODULE/.git" ]]; then
    echo "dbt submodule not found at $DBT_SUBMODULE; pull the submodule first." >&2
    exit 1
fi

cd "$DBT_SUBMODULE"

{
    echo "C8 -- dbt Scoring-Pipeline Commit Audit"
    echo "Window: 2025-10-01 .. 2026-03-15 (extended from Nov-20 model shift)"
    echo "Repo: $DBT_SUBMODULE"
    echo "Generated: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo ""
    echo "=============================================================="
    echo "Commits touching scoring-pipeline paths in window"
    echo "=============================================================="
    git log --since='2025-10-01' --until='2026-03-15' \
        --pretty=format:'%h %ad %an %s' --date=short -- \
        'models/marts/core/dim_enterprise_leads.sql' \
        'models/marts/model_output/enterprise_lead_scoring.sql' \
        'models/marts/_external_polytomic/polytomic_sync_hubspot_leads*.sql' \
        'models/marts/_external_polytomic/hubspot_leads_with_scores.sql' \
        'models/marts/_external_polytomic/hubspot_leads_for_enrichment.sql' \
        'models/marts/data_enrichment/pql_pre_append.sql' \
        'models/marts/data_enrichment/dtc_upsell_pre_append.sql' \
        'models/staging/hubspot/stg_contacts.sql' \
        'models/staging/hubspot/stg_contacts_2.sql' \
        'models/transformations/python/enterprise_lead_scoring_model.py' \
        'models/transformations/python/leads_for_training.sql' \
        'models/transformations/python/leads_for_scoring.sql'
    echo ""
    echo ""
    echo "=============================================================="
    echo "Per-commit diff stats for each commit above"
    echo "=============================================================="
    git log --since='2025-10-01' --until='2026-03-15' \
        --pretty=format:'%n--- %h %s ---' --stat -- \
        'models/marts/core/dim_enterprise_leads.sql' \
        'models/marts/model_output/enterprise_lead_scoring.sql' \
        'models/marts/_external_polytomic/polytomic_sync_hubspot_leads*.sql' \
        'models/marts/_external_polytomic/hubspot_leads_with_scores.sql' \
        'models/marts/_external_polytomic/hubspot_leads_for_enrichment.sql' \
        'models/marts/data_enrichment/pql_pre_append.sql' \
        'models/marts/data_enrichment/dtc_upsell_pre_append.sql' \
        'models/staging/hubspot/stg_contacts.sql' \
        'models/staging/hubspot/stg_contacts_2.sql' \
        'models/transformations/python/enterprise_lead_scoring_model.py' \
        'models/transformations/python/leads_for_training.sql' \
        'models/transformations/python/leads_for_scoring.sql'
} > "$OUTPUT"

echo "Wrote $OUTPUT"
