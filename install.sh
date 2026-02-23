#!/bin/bash
# install.sh — Wires the health-score statusline into ~/.claude/settings.json
#
# Run this after installing the plugin:
#   claude plugin install health-score@health-score-marketplace
#   ~/.claude/plugins/cache/<path>/install.sh
#
# What it does:
#   1. Copies health-score.sh to ~/.claude/scripts/health-score.sh
#   2. Adds statusLine config to ~/.claude/settings.json
#   3. Prints instructions

set -euo pipefail

PLUGIN_DIR="$(cd "$(dirname "$0")" && pwd)"
SCRIPT_SRC="${PLUGIN_DIR}/scripts/health-score.sh"
SCRIPTS_DIR="${HOME}/.claude/scripts"
SCRIPT_DEST="${SCRIPTS_DIR}/health-score.sh"
SETTINGS="${HOME}/.claude/settings.json"

# ── 1. Copy script to a stable path ──────────────────────────────────────────
mkdir -p "$SCRIPTS_DIR"
cp "$SCRIPT_SRC" "$SCRIPT_DEST"
chmod +x "$SCRIPT_DEST"
echo "✓ Copied health-score.sh → $SCRIPT_DEST"

# ── 2. Update settings.json ───────────────────────────────────────────────────
if [ ! -f "$SETTINGS" ]; then
  echo '{}' > "$SETTINGS"
fi

# Use jq to merge statusLine config (preserves all existing settings)
UPDATED=$(jq \
  --arg cmd "${SCRIPT_DEST}" \
  '. + {"statusLine": {"type": "command", "command": $cmd}}' \
  "$SETTINGS")

echo "$UPDATED" > "$SETTINGS"
echo "✓ Added statusLine config to $SETTINGS"

# ── 3. Done ───────────────────────────────────────────────────────────────────
echo ""
echo "✅ health-score installed!"
echo ""
echo "   Restart Claude Code to activate the status line."
echo "   You should see:  ▓▓▓▓▓▓░░░░  72 🟡  at the bottom."
echo ""
echo "   Score guide:"
echo "   🟢 70–100  Healthy — continue working"
echo "   🟡 40–69   Caution — plan to /compact soon"
echo "   🔴 0–39    Critical — /compact now to preserve quality"
echo ""
echo "   To uninstall, remove the statusLine key from $SETTINGS"
echo "   and delete $SCRIPT_DEST"
