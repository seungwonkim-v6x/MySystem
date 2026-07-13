#!/usr/bin/env bash
# Adapted from https://github.com/mattpocock/skills
# Path: skills/misc/git-guardrails-claude-code/scripts/block-dangerous-git.sh
# Adapted: 2026-05-18 — added fail-open trap, MYSYSTEM_HOOKS_ENFORCE gating,
#          dry-run log integration, hard-refuse for force-push to main/master
#          regardless of MYSYSTEM_ALLOW_FORCE_PUSH (prompt-injection defense).
# License: see upstream repo (verify before vendor).
#
# Blocks destructive git verbs at PreToolUse Bash. Reads JSON payload from stdin
# via Claude Code hook protocol.
#
# Bypass mechanisms:
#   MYSYSTEM_ALLOW_FORCE_PUSH=1   — allow git push --force on feature branches
#                                    (HARD REFUSE for origin main/master regardless)
#
# Modes:
#   MYSYSTEM_HOOKS_ENFORCE=1      — actually block (exit 2). Default = dry-run (exit 0).
#
# Fail-open: any internal error is logged + exit 0 (never brick the user).

set +e  # never let an internal error bubble to exit code

LOG_DIR="$HOME/.claude/logs"
DRY_RUN_LOG="$LOG_DIR/hook-dry-run.log"
ERROR_LOG="$LOG_DIR/hook-errors.log"
HOOK_NAME="block-dangerous-git"

log_error() {
  local msg="$1"
  mkdir -p "$LOG_DIR" 2>/dev/null
  printf '%s %s ERROR: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$HOOK_NAME" "$msg" >> "$ERROR_LOG" 2>/dev/null
}

log_dry_run() {
  local reason="$1"
  local cmd_preview="$2"
  mkdir -p "$LOG_DIR" 2>/dev/null
  printf '%s %s WOULD BLOCK: %s | cmd: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$HOOK_NAME" "$reason" "$cmd_preview" >> "$DRY_RUN_LOG" 2>/dev/null
}

# Read payload safely; fail-open if jq missing or stdin malformed.
PAYLOAD=$(cat 2>/dev/null) || { log_error "could not read stdin"; exit 0; }
if ! command -v jq >/dev/null 2>&1; then
  log_error "jq not installed; cannot parse hook payload"
  exit 0
fi
COMMAND=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // ""' 2>/dev/null) || {
  log_error "jq failed to parse payload"
  exit 0
}

if [ -n "${MYSYSTEM_HOOK_CANARY_LOG:-}" ]; then
  printf '%s\n' "$HOOK_NAME" >> "$MYSYSTEM_HOOK_CANARY_LOG" 2>/dev/null
fi

if [ -z "$COMMAND" ]; then
  exit 0
fi

# Normalize: collapse whitespace
NORMALIZED=$(printf '%s' "$COMMAND" | tr -s '[:space:]' ' ')

REASON=""
HARD_REFUSE=0

# HARD REFUSE — force-push (including --force-with-lease) to origin main/master
# regardless of bypass env var. Prompt-injection defense: env var could be set by
# injected tool output, so we never honor the bypass for protected branches.
# --force-with-lease is included because it still rewrites protected history; the
# lease check only protects against concurrent updates, not against intentional
# unilateral force-push.
# GIT_VERB is "git" followed by zero-or-more `-c key=val` / `-C path` option pairs
# before the actual verb. Catches `git -c user.name=foo push --force origin main`
# style bypass attempts.
GIT_VERB='git(\s+(-c\s+\S+|-C\s+\S+))*'

# Hard-refuse main/master force-push across all refspec variants:
#   git push --force origin main
#   git push --force-with-lease origin main
#   git push origin main --force
#   git push origin HEAD:main           (with force flag or +prefix)
#   git push origin refs/heads/main     (with force flag or +prefix)
#   git push origin +main               (+ is a force-push refspec)
#   git push origin +refs/heads/main
# These are all well-documented git ways to rewrite a protected branch.
PROTECTED='(main|master)'
REFSPEC_MAIN="(\+(refs/heads/)?${PROTECTED}|(\S+:)?(refs/heads/)?${PROTECTED}|${PROTECTED})"
FORCE_FLAG='(--force(-with-lease)?|-f)'

if echo "$NORMALIZED" | grep -Eq "${GIT_VERB}\s+push\s+(\S+\s+)*\+(refs/heads/)?${PROTECTED}\b"; then
  REASON="force-push (refspec +${PROTECTED}) to origin main/master (hard refuse, no bypass)"
  HARD_REFUSE=1
elif echo "$NORMALIZED" | grep -Eq "${GIT_VERB}\s+push\s+${FORCE_FLAG}(\s|=|$).*\bref(s/heads)?/${PROTECTED}\b|${GIT_VERB}\s+push\s+\S+\s+\S*:?(refs/heads/)?${PROTECTED}\s+${FORCE_FLAG}\b"; then
  REASON="force-push (refs/heads/ syntax) to origin main/master (hard refuse, no bypass)"
  HARD_REFUSE=1
elif echo "$NORMALIZED" | grep -Eq "${GIT_VERB}\s+push\s+${FORCE_FLAG}(\s|=|$).*\bHEAD:${PROTECTED}\b|${GIT_VERB}\s+push\s+\S+\s+HEAD:${PROTECTED}\s+${FORCE_FLAG}\b"; then
  REASON="force-push (HEAD:${PROTECTED}) to origin main/master (hard refuse, no bypass)"
  HARD_REFUSE=1
elif echo "$NORMALIZED" | grep -Eq "${GIT_VERB}\s+push\s+${FORCE_FLAG}(\s|=|$).*origin\s+${PROTECTED}\b|${GIT_VERB}\s+push\s+\S+\s+${PROTECTED}\s+${FORCE_FLAG}\b"; then
  REASON="force-push (including --force-with-lease) to origin main/master (hard refuse, no bypass)"
  HARD_REFUSE=1
elif echo "$NORMALIZED" | grep -Eq "${GIT_VERB}\s+push\s+${FORCE_FLAG}\b"; then
  REASON="git push --force / --force-with-lease"
elif echo "$NORMALIZED" | grep -Eq "${GIT_VERB}\s+push\b"; then
  REASON="git push (use /ship to push)"
elif echo "$NORMALIZED" | grep -Eq "${GIT_VERB}\s+reset\s+--hard\b"; then
  REASON="git reset --hard"
elif echo "$NORMALIZED" | grep -Eq "${GIT_VERB}\s+clean\s+-[a-zA-Z]*f"; then
  REASON="git clean -f"
elif echo "$NORMALIZED" | grep -Eq "${GIT_VERB}\s+branch\s+-D\b"; then
  REASON="git branch -D"
elif echo "$NORMALIZED" | grep -Eq "${GIT_VERB}\s+checkout\s+\.\s*$"; then
  REASON="git checkout . (discards working tree)"
elif echo "$NORMALIZED" | grep -Eq "${GIT_VERB}\s+restore\s+\.\s*$"; then
  REASON="git restore . (discards working tree)"
fi

if [ -z "$REASON" ]; then
  exit 0
fi

ENFORCE="${MYSYSTEM_HOOKS_ENFORCE:-}"
BYPASS="${MYSYSTEM_ALLOW_FORCE_PUSH:-}"

# Hard refuse overrides everything.
if [ "$HARD_REFUSE" = "1" ]; then
  if [ "$ENFORCE" = "1" ]; then
    printf 'BLOCKED: %s refused: %s\n' "$HOOK_NAME" "$REASON" >&2
    exit 2
  else
    log_dry_run "$REASON" "${NORMALIZED:0:200}"
    printf '[DRY-RUN] %s WOULD HARD-REFUSE: %s\n' "$HOOK_NAME" "$REASON" >&2
    exit 0
  fi
fi

# Bypass — only soft refuses honor it.
if [ "$BYPASS" = "1" ]; then
  # User explicitly opted in; allow.
  exit 0
fi

if [ "$ENFORCE" = "1" ]; then
  printf 'BLOCKED: %s refused: %s. Set MYSYSTEM_ALLOW_FORCE_PUSH=1 for feature-branch force-push only.\n' "$HOOK_NAME" "$REASON" >&2
  exit 2
fi

log_dry_run "$REASON" "${NORMALIZED:0:200}"
printf '[DRY-RUN] %s WOULD BLOCK: %s\n' "$HOOK_NAME" "$REASON" >&2
exit 0
