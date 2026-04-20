#!/bin/bash
# PreToolUse hook for Write|Edit — detects retry loops on the same file+content region.
# Fingerprint = file_path + short hash of edit content, so distinct edits to the same
# file do not collide; two attempts at the *same* change do.
source "$(dirname "$0")/_lib.sh"
init_hook "retry-guard"
read_input
ensure_state_dir

[[ -z "$FILE_PATH" ]] && finish 0

# --- Exemptions ---
BASENAME=$(basename "$FILE_PATH")

# CLAUDE.md files: no limit (scaffolding accumulates edits)
[[ "$BASENAME" == "CLAUDE.md" ]] && finish 0

# CSV files: no limit (data exports may overwrite)
[[ "$FILE_PATH" == *.csv ]] && finish 0

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

# --- Fingerprint = path + short hash of edit content ---
# Rationale: two edits at different lines of the same file should count independently;
# only repeated attempts at the *same* change indicate a retry loop.
CONTENT_HASH=$(short_hash "${EDIT_CONTENT:-$FILE_PATH}")
FINGERPRINT="${FILE_PATH}#${CONTENT_HASH}"

EDIT_LOG="$(state_file edit_log)"
append_line "$EDIT_LOG" "$FINGERPRINT"
COUNT=$(count_occurrences "$EDIT_LOG" "$FINGERPRINT")

if [ "$COUNT" -ge "$BLOCK_AT" ] && ! $NEVER_BLOCK; then
  echo "BLOCKED: $BASENAME — same edit attempted ${COUNT} times this session. This is a retry loop on the same change. Stop. Read the file. Read the error. Try a fundamentally different approach. To override: delete $(state_file edit_log)" >&2
  finish 2 "block" "$(jq -cn --argjson n "$COUNT" '{reason:"retry_loop", count:$n}')"
fi

if [ "$COUNT" -ge "$WARN_AT" ]; then
  echo "WARNING: $BASENAME — same edit attempted ${COUNT} times this session. Guardrail: if the same approach fails twice with different symptoms, the approach is wrong. Step back and investigate." >&2
  finish 1 "warn" "$(jq -cn --argjson n "$COUNT" '{reason:"retry_loop", count:$n}')"
fi

finish 0
