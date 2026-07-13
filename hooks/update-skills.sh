#!/usr/bin/env bash
# SessionStart hook: keep external skill repos fresh.
# Delegates to setup.sh (the SSOT for clone_or_pull on EXTERNAL_REPOS).
# Replaces the legacy submodule-auto-update.sh from v7.3 and earlier.

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

  # Promote the new log only after the run finishes so readers never see a
  # partially-written status. External refresh remains enabled; the Codex
  # parity phase itself is read-only in --session-start mode.
  NEXT_LOG="$LOG.next.$$"
  trap 'rm -f "$NEXT_LOG"; rmdir "$LOCK_DIR" 2>/dev/null' EXIT
  echo "=== $(date -u +%FT%TZ) ===" > "$NEXT_LOG"
  if "$MYSYSTEM/setup.sh" --session-start >> "$NEXT_LOG" 2>&1; then
    STATUS=0
  else
    STATUS=$?
  fi
  printf 'MYSYSTEM_SETUP_EXIT=%s\n' "$STATUS" >> "$NEXT_LOG"
  mv "$NEXT_LOG" "$LOG"
  exit "$STATUS"
) &

# Surface errors from the previous run (if any) at session start.
LAST_STATUS=$(sed -n 's/^MYSYSTEM_SETUP_EXIT=//p' "$LOG" 2>/dev/null | tail -1)
if [[ "$LAST_STATUS" =~ ^[0-9]+$ ]] && [ "$LAST_STATUS" -ne 0 ]; then
  ERRORS=$(grep -iE '^FAIL |error:|fatal:' "$LOG" | tail -3)
  [ -n "$ERRORS" ] || ERRORS="setup exited with status $LAST_STATUS"
  jq -n --arg err "$ERRORS" '{
    hookSpecificOutput: {
      hookEventName: "SessionStart",
      additionalContext: ("⚠ Skill update had errors:\n" + $err)
    }
  }'
fi

exit 0
