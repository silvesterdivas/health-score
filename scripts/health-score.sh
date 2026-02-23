#!/bin/bash
# health-score.sh — Claude Code status line script
# Reads context_window.used_percentage from stdin, outputs a 0–100 health score.
#
# Output format:  ▓▓▓▓▓▓░░░░  72 🟡
#
# Score curve (two-segment non-linear):
#   0–73% fill  → score 100→50  (gentle decay, linear)
#   73–100% fill → score 50→0   (accelerated collapse)
# Threshold matches Geoffrey Huntley's 147K degradation finding on 200K window.

set -euo pipefail

input=$(cat)

# Extract context window data; fall back to 0 if null/missing/invalid JSON
PCT=$(echo "$input" | jq -r '.context_window.used_percentage // 0' 2>/dev/null | cut -d. -f1)
PCT=${PCT:-0}

# Guard: clamp to 0–100
[ "$PCT" -lt 0 ]   && PCT=0
[ "$PCT" -gt 100 ] && PCT=100

# Two-segment non-linear score formula
if [ "$PCT" -le 73 ]; then
  # Linear zone: 100 → 50 over 0–73%
  SCORE=$(( 100 - (PCT * 50 / 73) ))
else
  # Collapse zone: 50 → 0 over 73–100%
  SCORE=$(( 50 - ((PCT - 73) * 50 / 27) ))
fi
[ "$SCORE" -lt 0 ]   && SCORE=0
[ "$SCORE" -gt 100 ] && SCORE=100

# Write state file for compact-check.sh Stop hook
STATE_FILE="/tmp/claude-health-score.json"
printf '{"score":%d,"pct":%d}\n' "$SCORE" "$PCT" > "$STATE_FILE"

# Build 10-block progress bar
FILLED=$(( SCORE / 10 ))
EMPTY=$(( 10 - FILLED ))
BAR=""
if [ "$FILLED" -gt 0 ]; then
  BAR=$(printf "%${FILLED}s" | tr ' ' '▓')
fi
if [ "$EMPTY" -gt 0 ]; then
  BAR="${BAR}$(printf "%${EMPTY}s" | tr ' ' '░')"
fi

# Color indicator
if   [ "$SCORE" -ge 70 ]; then DOT="🟢"
elif [ "$SCORE" -ge 40 ]; then DOT="🟡"
else                            DOT="🔴"
fi

printf '%s  %d %s\n' "$BAR" "$SCORE" "$DOT"
