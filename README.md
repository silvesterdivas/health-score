# health-score

> Real-time session health score for Claude Code. Scores context degradation 0–100 and warns before quality collapses.

```
▓▓▓▓▓▓░░░░  72 🟡
```

## Why

Context rot is real. Claude gets measurably worse past ~73% context fill (≈147K tokens on a 200K window). No tool tells you this is happening until it's too late.

`health-score` adds a live score to the Claude Code status bar — updated after every assistant message — so you always know where you stand.

## Score guide

| Score | Color | Meaning | Action |
|-------|-------|---------|--------|
| 70–100 | 🟢 | Healthy | Keep going |
| 40–69 | 🟡 | Caution | Plan to `/compact` soon |
| 0–39 | 🔴 | Critical | Claude will warn you to `/compact` |

The score curve is non-linear: it decays gently from 100→50 over the first 73% of context, then accelerates to 0 in the final 27%. This matches how LLM quality actually degrades — slowly at first, then suddenly.

## Install

```bash
claude plugin marketplace add silvesterdivas/health-score
claude plugin install health-score@health-score-marketplace
~/.claude/plugins/cache/silvesterdivas/health-score/install.sh
```

Restart Claude Code. The score appears in the bottom status bar.

## How it works

- **Status line script** (`scripts/health-score.sh`): reads `context_window.used_percentage` from Claude Code's native JSON input, computes score, renders the bar
- **Stop hook** (`scripts/compact-check.sh`): when score drops below 40, blocks Claude from stopping and recommends `/compact`
- **No background processes, no polling, no daemon** — pure shell + jq

## Uninstall

1. Remove `statusLine` from `~/.claude/settings.json`
2. Delete `~/.claude/scripts/health-score.sh`
3. `claude plugin uninstall health-score`

## Manual setup (no plugin manager)

```bash
# Copy the script
mkdir -p ~/.claude/scripts
cp scripts/health-score.sh ~/.claude/scripts/health-score.sh
chmod +x ~/.claude/scripts/health-score.sh

# Add to ~/.claude/settings.json
# "statusLine": { "type": "command", "command": "~/.claude/scripts/health-score.sh" }
```

## Testing

```bash
# Test the statusline script directly
echo '{"context_window":{"used_percentage":34}}' | ./scripts/health-score.sh
# → ▓▓▓▓░░░░░░  77 🟢

echo '{"context_window":{"used_percentage":75}}' | ./scripts/health-score.sh
# → ▓▓▓▓░░░░░░  48 🟡

echo '{"context_window":{"used_percentage":92}}' | ./scripts/health-score.sh
# → ▓░░░░░░░░░  18 🔴

# Test the Stop hook (healthy — should exit 0 silently)
echo '{"stop_hook_active":false}' | ./scripts/compact-check.sh
```
