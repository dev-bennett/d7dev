#!/bin/bash
# PostToolUse hook — tracks session state for other hooks to read.
# Always exits 0. Never warns or blocks.
source "$(dirname "$0")/_lib.sh"
init_hook "workflow-tracker"
read_input
ensure_state_dir

case "$TOOL_NAME" in
  Skill)
    # Track /preflight and /review invocations
    case "$SKILL_NAME" in
      preflight*) set_marker "$MARKER_PREFLIGHT_DONE" ;;
      review*)    set_marker "$MARKER_REVIEW_DONE" ;;
    esac
    ;;

  Write|Edit)
    # Track chart scripts that need visual verification
    if [[ "$FILE_PATH" == *.py ]] && [[ "$FILE_PATH" == */analysis/* ]]; then
      if [ -f "$FILE_PATH" ] && grep -q "savefig" "$FILE_PATH" 2>/dev/null; then
        append_unique "$(state_file charts_pending)" "$FILE_PATH"
      fi
    fi
    ;;

  Bash)
    # If a chart script in charts_pending was executed, mark it verified
    if [ -f "$(state_file charts_pending)" ] && [ -n "$COMMAND" ]; then
      while IFS= read -r pending; do
        if echo "$COMMAND" | grep -qF "$(basename "$pending" .py)" 2>/dev/null; then
          remove_line "$(state_file charts_pending)" "$pending"
          append_unique "$(state_file charts_verified)" "$pending"
        fi
      done < "$(state_file charts_pending)"
    fi
    ;;
esac

finish 0
