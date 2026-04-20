#!/bin/bash
# Shared state functions for d7dev hooks.
# Sourced by all hook scripts. Never executed directly.

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERROR_LOG="${HOOKS_DIR}/errors.log"
SESSION_LOG="${HOOKS_DIR}/session-log.jsonl"

# Shared marker names — single source of truth for hook/skill coordination
MARKER_PREFLIGHT_DONE="preflight_done"
MARKER_REVIEW_DONE="review_done"

# Read JSON from stdin — call exactly once per hook invocation
# Parses the fields hooks commonly need. Edit content slice used for fingerprinting.
read_input() {
  _HOOK_INPUT=$(cat)
  _simple=$(echo "$_HOOK_INPUT" | jq -r '(.session_id // "unknown"), (.tool_name // ""), (.tool_input.file_path // ""), (.tool_input.skill // ""), (.prompt // "")' 2>/dev/null) || _simple=""
  SESSION_ID=$(echo "$_simple" | sed -n '1p')
  TOOL_NAME=$(echo "$_simple" | sed -n '2p')
  FILE_PATH=$(echo "$_simple" | sed -n '3p')
  SKILL_NAME=$(echo "$_simple" | sed -n '4p')
  USER_PROMPT=$(echo "$_simple" | sed -n '5p')
  COMMAND=$(echo "$_HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null) || COMMAND=""
  # For Edit: new_string. For Write: content. Used by retry-guard for fingerprinting.
  EDIT_CONTENT=$(echo "$_HOOK_INPUT" | jq -r '.tool_input.new_string // .tool_input.content // ""' 2>/dev/null) || EDIT_CONTENT=""
  export STATE_DIR="/tmp/d7dev-hooks/${SESSION_ID:-unknown}"
  HOOK_START_EPOCH_MS=$(_now_ms)
}

# Millisecond epoch; falls back to seconds*1000 if no hi-res source available.
_now_ms() {
  if command -v perl >/dev/null 2>&1; then
    perl -MTime::HiRes=time -e 'printf "%d\n", time()*1000' 2>/dev/null && return
  fi
  echo $(( $(date +%s) * 1000 ))
}

# Compact SHA-1 of a string; used for edit fingerprinting. Falls back if shasum missing.
short_hash() {
  if command -v shasum >/dev/null 2>&1; then
    printf '%s' "$1" | shasum | awk '{print substr($1, 1, 8)}'
  elif command -v sha1sum >/dev/null 2>&1; then
    printf '%s' "$1" | sha1sum | awk '{print substr($1, 1, 8)}'
  else
    # Last-resort: size-based (not a real hash, but better than nothing)
    printf '%s' "$1" | wc -c | awk '{print $1}'
  fi
}

ensure_state_dir() {
  mkdir -p "$STATE_DIR" 2>/dev/null || true
}

state_file() {
  echo "${STATE_DIR}/${1}"
}

has_marker() {
  [ -f "$(state_file "$1")" ]
}

set_marker() {
  ensure_state_dir
  touch "$(state_file "$1")"
}

count_occurrences() {
  local file="$1" val="$2"
  [ -f "$file" ] && grep -cFx "$val" "$file" 2>/dev/null || echo "0"
}

append_line() {
  local file="$1" val="$2"
  ensure_state_dir
  echo "$val" >> "$file"
}

append_unique() {
  local file="$1" val="$2"
  ensure_state_dir
  grep -qFx "$val" "$file" 2>/dev/null || echo "$val" >> "$file"
}

remove_line() {
  local file="$1" val="$2"
  [ -f "$file" ] || return 0
  local tmp
  tmp=$(mktemp)
  grep -vFx "$val" "$file" > "$tmp" 2>/dev/null || true
  mv "$tmp" "$file"
}

# Log an error to the persistent error log (survives across sessions)
log_error() {
  local hook_name="$1" message="$2"
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] ${hook_name}: ${message}" >> "$ERROR_LOG" 2>/dev/null || true
}

# Append one JSON line to the session log for retrospectives.
# Usage: log_event <outcome> [extra_json]
#   outcome: pass|warn|block|info
#   extra_json: optional compact JSON object (e.g. '{"count":5}') merged into the record
log_event() {
  local outcome="${1:-info}" extra="${2:-}"
  local elapsed=0
  if [ -n "${HOOK_START_EPOCH_MS:-}" ]; then
    elapsed=$(( $(_now_ms) - HOOK_START_EPOCH_MS ))
  fi
  # Use jq to build the JSON safely (handles escaping of paths/commands).
  jq -cn \
    --arg ts "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" \
    --arg session "${SESSION_ID:-unknown}" \
    --arg hook "${_HOOK_NAME:-unknown}" \
    --arg tool "${TOOL_NAME:-}" \
    --arg file "${FILE_PATH:-}" \
    --arg skill "${SKILL_NAME:-}" \
    --arg outcome "$outcome" \
    --argjson elapsed "$elapsed" \
    --argjson extra "${extra:-null}" \
    '{ts:$ts, session:$session, hook:$hook, tool:$tool, file:$file, skill:$skill, outcome:$outcome, elapsed_ms:$elapsed, extra:$extra}' \
    >> "$SESSION_LOG" 2>/dev/null || true
}

# Standard hook wrapper — call this at the top of every hook.
# Usage: init_hook "hook-name"
# Sets up error trap that logs and exits 0.
init_hook() {
  _HOOK_NAME="$1"
  trap '_hook_error_handler' ERR
}

_hook_error_handler() {
  log_error "${_HOOK_NAME:-unknown}" "Unexpected error at line ${BASH_LINENO[0]:-?}: ${BASH_COMMAND:-?} (exit=$?)"
  log_event "crash"
  exit 0
}

# finish <exit_code> [outcome] [extra_json]
# Log telemetry then exit. Default outcome derived from exit code: 0=pass, 1=warn, 2=block.
finish() {
  local code="${1:-0}" outcome="${2:-}" extra="${3:-}"
  if [ -z "$outcome" ]; then
    case "$code" in
      0) outcome="pass" ;;
      1) outcome="warn" ;;
      2) outcome="block" ;;
      *) outcome="info" ;;
    esac
  fi
  log_event "$outcome" "$extra"
  exit "$code"
}
