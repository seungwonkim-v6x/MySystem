#!/bin/bash
# SessionStart hook: auto-update all skill submodules
# Runs in background to avoid blocking session start

export HOME="/Users/seungwonkim"
MYSYSTEM="$HOME/.claude"
LOG="$MYSYSTEM/.submodule-update.log"

(
  cd "$MYSYSTEM" || exit 0

  UPDATED=0
  for sub in $(git submodule status | awk '{print $2}'); do
    # Fetch latest from remote
    BEFORE=$(git -C "$sub" rev-parse HEAD 2>/dev/null)
    git -C "$sub" fetch --depth 1 origin HEAD 2>/dev/null
    AFTER=$(git -C "$sub" rev-parse FETCH_HEAD 2>/dev/null)

    if [ "$BEFORE" != "$AFTER" ] && [ -n "$AFTER" ]; then
      git -C "$sub" checkout FETCH_HEAD 2>/dev/null
      echo "$(date -u +%FT%TZ) Updated $sub: ${BEFORE:0:7} → ${AFTER:0:7}" >> "$LOG"
      UPDATED=$((UPDATED + 1))
    fi
  done

  # Restore any broken symlinks after update
  if [ $UPDATED -gt 0 ]; then
    "$MYSYSTEM/setup.sh" >> "$LOG" 2>&1
  fi
) &

# Report failures from last run (if any)
if [ -f "$LOG" ]; then
  ERRORS=$(grep -i "error\|fatal\|fail" "$LOG" 2>/dev/null | tail -3)
  if [ -n "$ERRORS" ]; then
    jq -n --arg err "$ERRORS" '{
      hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: ("⚠ Submodule update had errors:\n" + $err)
      }
    }'
  fi
fi

exit 0
