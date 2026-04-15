#!/bin/bash
# statusline-usage.sh — Claude Code statusLine hook
# Monitors 5-hour usage limit via rate_limits JSON from stdin.
# Writes /tmp/claude-usage-limit.json when threshold exceeded.
# ralph-smart.sh reads this flag to auto-pause.

THRESHOLD="${CLAUDE_USAGE_THRESHOLD:-95}"
LIMIT_FILE="/tmp/claude-usage-limit.json"

INPUT=$(cat)

# Extract rate limits
PCT=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.used_percentage // empty' 2>/dev/null)
RESETS=$(echo "$INPUT" | jq -r '.rate_limits.five_hour.resets_at // empty' 2>/dev/null)
PCT7=$(echo "$INPUT" | jq -r '.rate_limits.seven_day.used_percentage // empty' 2>/dev/null)
COST=$(echo "$INPUT" | jq -r '.cost.total_cost_usd // 0' 2>/dev/null)

# Before first API response, rate_limits may be absent
if [ -z "$PCT" ]; then
  printf '$%.2f' "${COST:-0}"
  exit 0
fi

# Write limit flag when threshold exceeded (once per cycle)
if [ "$PCT" -ge "$THRESHOLD" ] 2>/dev/null && [ ! -f "$LIMIT_FILE" ]; then
  printf '{"percentage":%d,"resets_at":%d,"timestamp":%d}' \
    "$PCT" "$RESETS" "$(date +%s)" > "$LIMIT_FILE"
fi

# Render status bar
if [ "$PCT" -ge "$THRESHOLD" ] 2>/dev/null; then
  printf 'LIMIT %d%% 7d:%s%% $%.2f' "$PCT" "${PCT7:-?}" "${COST:-0}"
else
  printf '5h:%d%% 7d:%s%% $%.2f' "$PCT" "${PCT7:-?}" "${COST:-0}"
fi
