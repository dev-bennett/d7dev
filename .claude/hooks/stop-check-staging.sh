#!/bin/bash
# Stop hook: warn if modified/new files are unstaged
# Returns empty (allow stop) or JSON block decision

# Check for unstaged modifications or untracked files in working tree
UNSTAGED=$(git diff --name-only 2>/dev/null)
UNTRACKED=$(git ls-files --others --exclude-standard 2>/dev/null | head -5)

if [[ -n "$UNSTAGED" || -n "$UNTRACKED" ]]; then
  FILES=""
  [[ -n "$UNSTAGED" ]] && FILES="Modified: ${UNSTAGED//$'\n'/, }"
  [[ -n "$UNTRACKED" ]] && FILES="${FILES:+$FILES | }Untracked: ${UNTRACKED//$'\n'/, }"

  # Output JSON to block stop
  cat <<EOF
{"decision": "block", "reason": "Unstaged changes detected. ${FILES}. Stage with git add or confirm these should remain unstaged."}
EOF
else
  # No output = allow stop
  exit 0
fi
