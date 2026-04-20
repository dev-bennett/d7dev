#!/bin/bash
# PreToolUse hook for Write|Edit — lints stakeholder-facing markdown against §10 writing standards.
# Scans the incoming content (not the whole file) for banned rhetorical patterns.
# Advisory only: warns on exit 1, never blocks. The analyst is responsible for the final scrub.
source "$(dirname "$0")/_lib.sh"
init_hook "writing-scrub"
read_input
ensure_state_dir

# Only lint stakeholder-facing markdown in analysis/ or initiatives/
[[ -z "$FILE_PATH" ]] && finish 0
case "$FILE_PATH" in
  *.md) : ;;
  *) finish 0 ;;
esac
case "$FILE_PATH" in
  */analysis/*|*/initiatives/*) : ;;
  *) finish 0 ;;
esac

# Skip CLAUDE.md governance files, templates, and checkpoints
BASENAME=$(basename "$FILE_PATH")
case "$BASENAME" in
  CLAUDE.md|checkpoint.md|README.md) finish 0 ;;
esac
case "$FILE_PATH" in
  */_templates/*) finish 0 ;;
esac

# Nothing to scan
[ -z "$EDIT_CONTENT" ] && finish 0

# --- Banned phrases from .claude/rules/writing-standards.md ---
# Each pattern is a grep -iE regex. Case-insensitive. Matches whole-word boundaries where useful.
declare -a PATTERNS=(
  '\bsurprisingly\b'
  '\binterestingly\b'
  '\bnotably\b'
  '\bthis reveals\b'
  '\bthis suggests\b'
  '\bthis indicates\b'
  '\bthe key takeaway\b'
  '"?it'\''s worth noting'
  '\bit bears mentioning\b'
  '\brobust\b'
  'not [A-Za-z]+ -- but'
  'not [A-Za-z]+ — but'
)

HITS=()
for pat in "${PATTERNS[@]}"; do
  # -n for line numbers so the warning is actionable
  if MATCH=$(echo "$EDIT_CONTENT" | grep -inE "$pat" 2>/dev/null | head -2); then
    [ -n "$MATCH" ] && HITS+=("  phrase /${pat}/:" "$(echo "$MATCH" | sed 's/^/    /')")
  fi
done

# Bare $ (LaTeX/math reinterpretation on some platforms)
if echo "$EDIT_CONTENT" | grep -qE '(^|[^\\$])\$[A-Za-z0-9]' 2>/dev/null; then
  SAMPLE=$(echo "$EDIT_CONTENT" | grep -nE '(^|[^\\$])\$[A-Za-z0-9]' | head -1)
  HITS+=("  bare \$ (platform-unsafe):" "    ${SAMPLE}")
fi

if [ "${#HITS[@]}" -gt 0 ]; then
  {
    echo "WRITING SCRUB WARNING: stakeholder-facing prose contains banned phrasing (see .claude/rules/writing-standards.md):"
    for h in "${HITS[@]}"; do echo "$h"; done
    echo "Rewrite as observation, not reaction. Run the §10 Sentence Audit before finalizing."
  } >&2
  finish 1 "warn" "$(jq -cn --argjson n "${#HITS[@]}" '{reason:"banned_phrases", hits:$n}')"
fi

finish 0
