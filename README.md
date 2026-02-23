# health-score

**Real-time session health score for Claude Code.**
Scores context degradation 0–100 and warns before quality collapses.

```
▓▓▓▓▓▓▓░░░  77 🟢   ← healthy, keep going
▓▓▓▓░░░░░░  47 🟡   ← caution, plan to /compact
▓░░░░░░░░░  15 🔴   ← critical, Claude will warn you
```

---

## Why

Context rot is real. Claude gets measurably worse past ~73% context fill (≈147K tokens on a 200K window). Quality doesn't degrade linearly — it drifts slowly at first, then collapses suddenly in the final 27%.

No tool surfaces this in real time. [GitHub issue #5547](https://github.com/anthropics/claude-code/issues/5547) requested exactly this and went unfilled. `health-score` fills it.

---

## What it does

- **Status line score** — a live `▓▓▓▓▓░░░░░  54 🟡` bar at the bottom of every Claude Code session, updated after every assistant message
- **Stop hook** — when score drops below 40, blocks Claude from going idle and prompts you to run `/compact` before continuing
- **No daemon, no polling** — pure bash + jq, reads `context_window.used_percentage` from Claude Code's native statusline JSON

---

## Score formula

The curve is non-linear, matching how LLM quality actually degrades:

```
0–73% fill  →  score 100 → 50   (gentle linear decay)
73–100% fill →  score 50 → 0    (accelerated collapse)
```

The 73% threshold corresponds to ~147K tokens on a 200K context window — the point where performance degradation was empirically observed to accelerate.

| Score | Indicator | Meaning | Action |
|-------|-----------|---------|--------|
| 70–100 | 🟢 | Healthy | Keep going |
| 40–69 | 🟡 | Caution | Plan to `/compact` soon |
| 0–39 | 🔴 | Critical | Stop hook blocks + warns |

---

## Install

```bash
# 1. Add the marketplace
claude plugin marketplace add silvesterdivas/health-score

# 2. Install the plugin
claude plugin install health-score@health-score-marketplace

# 3. Wire the status line
~/.claude/plugins/cache/health-score-marketplace/health-score/1.0.1/install.sh
```

Then **restart Claude Code**. The score bar appears at the bottom immediately.

> `install.sh` copies `health-score.sh` to `~/.claude/scripts/` and adds the `statusLine` config to `~/.claude/settings.json`.

---

## Manual setup

If you prefer not to use the plugin manager:

```bash
# Copy the script
mkdir -p ~/.claude/scripts
cp scripts/health-score.sh ~/.claude/scripts/health-score.sh
chmod +x ~/.claude/scripts/health-score.sh
```

Add to `~/.claude/settings.json`:

```json
{
  "statusLine": {
    "type": "command",
    "command": "~/.claude/scripts/health-score.sh"
  }
}
```

---

## How it works

```
Claude Code fires statusLine update (after every assistant message)
        ↓
health-score.sh reads from stdin:
  context_window.used_percentage   ← provided natively, no parsing needed
        ↓
computes 0–100 score with two-segment non-linear formula
        ↓
writes /tmp/claude-health-score.json  { score, pct }  ← for Stop hook
        ↓
outputs to status bar:  ▓▓▓▓▓░░░░░  54 🟡

── separately ──────────────────────────────────────────────

Claude Code fires Stop event (when Claude finishes responding)
        ↓
compact-check.sh reads /tmp/claude-health-score.json
        ↓
score < 40  →  { "decision": "block", "reason": "Run /compact." }
```

### Files

| File | Role |
|------|------|
| `scripts/health-score.sh` | Statusline script — reads `used_percentage`, outputs score bar |
| `scripts/compact-check.sh` | Stop hook — blocks Claude when score < 40 |
| `hooks/hooks.json` | Registers the Stop hook via `${CLAUDE_PLUGIN_ROOT}` |
| `install.sh` | Copies script to `~/.claude/scripts/` and writes `statusLine` to settings |

---

## Testing

```bash
# Direct invocation (no stdin) — expect clean output, no errors
./scripts/health-score.sh
# ▓▓▓▓▓▓▓▓▓▓  100 🟢

# Fresh session (9% fill) — expect 🟢
echo '{"context_window":{"used_percentage":9}}' | ./scripts/health-score.sh
# ▓▓▓▓▓▓▓▓▓░  95 🟢

# Caution zone (75% fill) — expect 🟡
echo '{"context_window":{"used_percentage":75}}' | ./scripts/health-score.sh
# ▓▓▓▓░░░░░░  47 🟡

# Critical (92% fill) — expect 🔴
echo '{"context_window":{"used_percentage":92}}' | ./scripts/health-score.sh
# ▓░░░░░░░░░  15 🔴

# Stop hook — critical score — expect block decision
echo '{"score":15,"pct":92}' > /tmp/claude-health-score.json
echo '{"stop_hook_active":false}' | ./scripts/compact-check.sh

# Stop hook — stop_hook_active guard — expect silent exit
echo '{"stop_hook_active":true}' | ./scripts/compact-check.sh
```

---

## Uninstall

```bash
# Remove statusLine from settings
jq 'del(.statusLine)' ~/.claude/settings.json > /tmp/s.json && mv /tmp/s.json ~/.claude/settings.json

# Remove the script
rm ~/.claude/scripts/health-score.sh

# Uninstall the plugin
claude plugin uninstall health-score
```

---

## License

MIT — [Silvester Divas](https://github.com/silvesterdivas)
