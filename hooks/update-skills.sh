#!/bin/bash
# SessionStart hook: keep external skill repos fresh.
# Delegates to setup.sh (the SSOT for clone_or_pull on EXTERNAL_REPOS).
# Replaces the legacy submodule-auto-update.sh from v7.3 and earlier.

export HOME="/Users/seungwonkim"
MYSYSTEM="$HOME/.claude"
LOG="$MYSYSTEM/.skill-update.log"
LOCK_DIR="$MYSYSTEM/.skill-update.lock.d"

(
  # Single-flight via atomic mkdir (portable; macOS has no flock).
  # If another session beat us to it, exit silently.
  if ! mkdir "$LOCK_DIR" 2>/dev/null; then
    exit 0
  fi
  trap 'rmdir "$LOCK_DIR" 2>/dev/null' EXIT

  # Truncate log every run so stale errors don't get reported forever.
  echo "=== $(date -u +%FT%TZ) ===" > "$LOG"
  "$MYSYSTEM/setup.sh" >> "$LOG" 2>&1
) &

# Surface errors from the previous run (if any) at session start.
if [ -f "$LOG" ] && grep -qiE "error|fatal|fail" "$LOG"; then
  ERRORS=$(grep -iE "error|fatal|fail" "$LOG" | tail -3)
  jq -n --arg err "$ERRORS" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: ("⚠ Skill update had errors:\n" + $err)
    }
  }'
fi

exit 0
