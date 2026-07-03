#!/bin/bash
# preflight.sh <owner/repo> <pr_number> [state_file] [session_id]
#
# Environment checks before an /ai-review-loop round. Judgment rules live in
# SKILL.md — this script only checks environment facts.
#
# Exit codes:
#   0 = go
#   2 = hard stop        (no PR / gh unauthenticated / PR not open)
#   3 = warnings         (printed as "WARN: ..." lines; autonomous chain
#                         converts to proceed-with-note, user-typed
#                         invocation pauses for acknowledgment — SKILL.md)
# Stdout: "CI_BASELINE: green|red|none", "SENSITIVE_PATHS: <globs>",
#         zero or more "WARN: ..." / "NOTE: ..." lines.
set -u

REPO="${1:?usage: preflight.sh <owner/repo> <pr> [state_file] [session_id]}"
PR="${2:?usage: preflight.sh <owner/repo> <pr> [state_file] [session_id]}"
STATE="${3:-}"
SESSION="${4:-}"

WARN=0

# ---- hard stops -------------------------------------------------------------
if ! command -v gh >/dev/null 2>&1; then
  echo "STOP: gh not installed"; exit 2
fi
if ! gh auth status >/dev/null 2>&1; then
  echo "STOP: gh not authenticated (run: gh auth login)"; exit 2
fi
PR_STATE=$(gh api "repos/$REPO/pulls/$PR" --jq '.state' 2>/dev/null) || {
  echo "STOP: PR $REPO#$PR not found"; exit 2
}
if [ "$PR_STATE" != "open" ]; then
  echo "STOP: PR $REPO#$PR is $PR_STATE (loop targets open PRs only)"; exit 2
fi

# ---- advisory lock (EA9) ----------------------------------------------------
if [ -n "$STATE" ] && [ -f "$STATE" ] && jq -e . "$STATE" >/dev/null 2>&1; then
  LOOP_STATUS=$(jq -r '.loop_status // "closed"' "$STATE")
  if [ "$LOOP_STATUS" = "active" ] || [ "$LOOP_STATUS" = "awaiting-user" ]; then
    OWNER_SESSION=$(jq -r '.session_id // ""' "$STATE")
    HB=$(jq -r '.heartbeat_ts // ""' "$STATE")
    if [ -n "$OWNER_SESSION" ] && [ "$OWNER_SESSION" != "$SESSION" ] && [ -n "$HB" ]; then
      HB_EPOCH=$(date -j -u -f "%Y-%m-%dT%H:%M:%SZ" "$HB" +%s 2>/dev/null \
        || date -u -d "$HB" +%s 2>/dev/null || echo 0)
      NOW=$(date -u +%s)
      AGE=$(( NOW - HB_EPOCH ))
      if [ "$AGE" -lt 1800 ]; then
        echo "WARN: state lock held by session $OWNER_SESSION (heartbeat ${AGE}s ago, <30min) — resume requires --take-over"
        WARN=1
      else
        echo "NOTE: stale lock (heartbeat ${AGE}s ago) — safe to resume"
      fi
    fi
  fi
  # schema version (DX9): active loop on a different schema fails closed.
  SV=$(jq -r '.schema_version // 0' "$STATE")
  if [ "$SV" != "1" ] && { [ "$LOOP_STATUS" = "active" ] || [ "$LOOP_STATUS" = "awaiting-user" ]; }; then
    echo "STOP: active loop state has schema_version=$SV (expected 1) — finish or --close it before upgrading"
    exit 2
  fi
fi

# ---- prettier drift (pitfall from 2026-07-02 Tapit session) ------------------
# Only when a Node lockfile pins prettier: lint-staged running a drifted
# local prettier can pollute commits with out-of-branch reformats.
LOCK=""
for f in pnpm-lock.yaml package-lock.json yarn.lock; do
  [ -f "$f" ] && { LOCK="$f"; break; }
done
if [ -n "$LOCK" ] && grep -q 'prettier' "$LOCK" 2>/dev/null && command -v node >/dev/null 2>&1; then
  LOCAL_VER=$(node -e 'try{console.log(require("prettier/package.json").version)}catch(e){process.exit(1)}' 2>/dev/null || echo "")
  LOCK_VER=""
  case "$LOCK" in
    pnpm-lock.yaml) LOCK_VER=$(grep -Eo '/prettier@[0-9]+\.[0-9]+\.[0-9]+' "$LOCK" 2>/dev/null | head -1 | cut -d@ -f2) ;;
    package-lock.json) LOCK_VER=$(jq -r '.packages["node_modules/prettier"].version // ""' "$LOCK" 2>/dev/null) ;;
    yarn.lock) LOCK_VER=$(grep -A1 '^prettier@' "$LOCK" 2>/dev/null | grep version | head -1 | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+') ;;
  esac
  if [ -n "$LOCAL_VER" ] && [ -n "$LOCK_VER" ] && [ "$LOCAL_VER" != "$LOCK_VER" ]; then
    echo "WARN: prettier drift — local $LOCAL_VER vs lockfile $LOCK_VER; pre-commit lint-staged can pollute commits with out-of-branch reformats"
    WARN=1
  fi
fi

# ---- tier-B availability note ------------------------------------------------
# stdout (like every other NOTE/WARN) so a caller parsing the documented
# stdout contract sees it.
if ! command -v codex >/dev/null 2>&1; then
  echo "NOTE: codex CLI absent — tier B row will be skipped (non-fatal)"
fi

# ---- CI baseline snapshot (OQ2) ----------------------------------------------
CHECKS=$(gh pr checks "$PR" --repo "$REPO" 2>/dev/null || echo "")
if [ -z "$CHECKS" ]; then
  echo "CI_BASELINE: none"
elif grep -qiE 'fail|error' <<<"$CHECKS"; then
  echo "CI_BASELINE: red"
  echo "NOTE: CI already red from pre-existing causes — loop continues; escalates only if a LOOP commit turns a check red"
else
  echo "CI_BASELINE: green"
fi

# ---- sensitive-path list (EA10 — surfaced here, ENFORCED in round-budget.sh) --
echo "SENSITIVE_PATHS: hooks/** settings.json .github/workflows/** **/*secret* **/*credential* **/.env* install.sh setup.sh"

[ "$WARN" -eq 1 ] && exit 3
exit 0
