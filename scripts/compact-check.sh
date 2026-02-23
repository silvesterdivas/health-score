#!/bin/bash
# compact-check.sh — Claude Code Stop hook
# Blocks Claude from going idle when context health score is critical (< 40).
# Recommends /compact to the user.
#
# Exit codes:
#   0 — allow Claude to stop (score is healthy, or state file missing)
#   0 + JSON decision "block" — warn Claude and keep it working

set -euo pipefail

input=$(cat)

# Prevent infinite loop: if this hook already triggered a continuation, let Claude stop.
ACTIVE=$(echo "$input" | jq -r '.stop_hook_active // false')
if [ "$ACTIVE" = "true" ]; then
  exit 0
fi

STATE_FILE="/tmp/claude-health-score.json"

# No state yet (session just started, statusline hasn't run) — allow stop.
if [ ! -f "$STATE_FILE" ]; then
  exit 0
fi

SCORE=$(jq -r '.score // 100' "$STATE_FILE")
PCT=$(jq -r '.pct // 0' "$STATE_FILE")

if [ "$SCORE" -lt 40 ]; then
  jq -n \
    --argjson score "$SCORE" \
    --argjson pct "$PCT" \
    '{
      decision: "block",
      reason: ("Context window is at " + ($pct | tostring) + "% (health score: " + ($score | tostring) + "/100). Quality may degrade. Run /compact to summarize the conversation before continuing.")
    }'
  exit 0
fi

exit 0
