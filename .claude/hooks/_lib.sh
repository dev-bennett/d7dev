#!/bin/bash
# Shared state functions for d7dev hooks.
# Sourced by all hook scripts. Never executed directly.

HOOKS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ERROR_LOG="${HOOKS_DIR}/errors.log"

# Read JSON from stdin — call exactly once per hook invocation
# Two jq calls: one for single-line fields, one for command (which may contain newlines/special chars)
read_input() {
  _HOOK_INPUT=$(cat)
  _simple=$(echo "$_HOOK_INPUT" | jq -r '(.session_id // "unknown"), (.tool_name // ""), (.tool_input.file_path // ""), (.tool_input.skill // "")' 2>/dev/null) || _simple=""
  SESSION_ID=$(echo "$_simple" | sed -n '1p')
  TOOL_NAME=$(echo "$_simple" | sed -n '2p')
  FILE_PATH=$(echo "$_simple" | sed -n '3p')
  SKILL_NAME=$(echo "$_simple" | sed -n '4p')
  COMMAND=$(echo "$_HOOK_INPUT" | jq -r '.tool_input.command // ""' 2>/dev/null) || COMMAND=""
  export STATE_DIR="/tmp/d7dev-hooks/${SESSION_ID:-unknown}"
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

# Standard hook wrapper — call this at the top of every hook.
# Usage: init_hook "hook-name"
# Sets up error trap that logs and exits 0.
init_hook() {
  _HOOK_NAME="$1"
  trap '_hook_error_handler' ERR
}

_hook_error_handler() {
  log_error "${_HOOK_NAME:-unknown}" "Unexpected error at line ${BASH_LINENO[0]:-?}: ${BASH_COMMAND:-?} (exit=$?)"
  exit 0
}
