#!/bin/bash
# PreToolUse hook for Write|Edit — detects retry loops via per-file edit counts.
source "$(dirname "$0")/_lib.sh"
init_hook "retry-guard"
read_input
ensure_state_dir

[[ -z "$FILE_PATH" ]] && exit 0

# --- Exemptions ---
BASENAME=$(basename "$FILE_PATH")

# CLAUDE.md files: no limit (scaffolding accumulates edits)
[[ "$BASENAME" == "CLAUDE.md" ]] && exit 0

# CSV files: no limit (data exports may overwrite)
[[ "$FILE_PATH" == *.csv ]] && exit 0

# --- Determine thresholds ---
WARN_AT=5
BLOCK_AT=8

# SQL files in analysis/: higher thresholds (queries iterate more)
if [[ "$FILE_PATH" == *.sql ]] && [[ "$FILE_PATH" == */analysis/* ]]; then
  WARN_AT=8
  BLOCK_AT=12
fi

# knowledge/ files: warn only, never block
NEVER_BLOCK=false
case "$FILE_PATH" in
  */knowledge/*) NEVER_BLOCK=true ;;
esac

# --- Count edits to this file ---
EDIT_LOG="$(state_file edit_log)"
append_line "$EDIT_LOG" "$FILE_PATH"
COUNT=$(count_occurrences "$EDIT_LOG" "$FILE_PATH")

if [ "$COUNT" -ge "$BLOCK_AT" ] && ! $NEVER_BLOCK; then
  echo "BLOCKED: $BASENAME edited ${COUNT} times this session — this is a retry loop. Stop. Read the file. Read the error. Try a fundamentally different approach. To override: delete $(state_file edit_log)" >&2
  exit 2
fi

if [ "$COUNT" -ge "$WARN_AT" ]; then
  echo "WARNING: $BASENAME edited ${COUNT} times this session. Guardrail: if the same approach fails twice with different symptoms, the approach is wrong. Step back and investigate." >&2
  exit 1
fi

exit 0
