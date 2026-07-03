#!/bin/bash
# detect-reviewers.sh <owner/repo> <pr_number>
#
# Detects the 3-tier AI reviewer registry for a PR. Registry JSON array on
# stdout; diagnostics on stderr. ALWAYS exits 0 — a failed tier never kills
# the loop (the tier just comes back empty).
#
# Tier A discovery: scan this PR + the repo's recent PRs for review/comment
# authors matching *[bot]; known logins map to their retrigger method,
# unknown bots get retrigger:"none" (collect + reply only, low-trust).
# Tier B: local cross-model CLIs found on PATH (registry table below).
# Tier C: fresh Claude subagent — always present.
set -u

REPO="${1:?usage: detect-reviewers.sh <owner/repo> <pr_number>}"
PR="${2:?usage: detect-reviewers.sh <owner/repo> <pr_number>}"

# Known tier-A bots: login|id|retrigger
KNOWN_A="copilot-pull-request-reviewer[bot]|copilot|cli-copilot
greptile-apps[bot]|greptile|push-triggered
coderabbitai[bot]|coderabbit|push-triggered"

# Tier-B CLI table: binary|id  (extension = add a row)
KNOWN_B="codex|codex"

rows="[]"

add_row() { # $1 = single row JSON
  rows=$(jq -c --argjson row "$1" '. + [$row]' <<<"$rows")
}

# ---- Tier A ---------------------------------------------------------------
# Two sources, different trust:
#   (a) bots that already posted on THIS PR → active rows.
#   (b) KNOWN bots the repo uses (learned from recent PRs) that have NOT yet
#       posted here → "expected" rows, so the loop waits for and re-triggers
#       them on a fresh PR (the primary auto-chain case, where bots post
#       1-3 min after /ship). Only logins that EXACTLY match KNOWN_A are
#       seeded — an unknown bot from another PR is never added (that was the
#       pollution/spoof risk), and the exact-field match defeats suffix
#       spoofing of a known login.
# Detection is idempotent and MUST be re-run each round (SKILL.md) so a bot
# that posts mid-loop is promoted expected→active.
pr_logins=""
repo_known_logins=""
if command -v gh >/dev/null 2>&1; then
  pr_logins=$(
    {
      gh api "repos/$REPO/pulls/$PR/reviews" --paginate --jq '.[].user.login' 2>/dev/null
      gh api "repos/$REPO/pulls/$PR/comments" --paginate --jq '.[].user.login' 2>/dev/null
      gh api "repos/$REPO/issues/$PR/comments" --paginate --jq '.[].user.login' 2>/dev/null
    } || true
  )
  pr_logins=$(printf '%s\n' "$pr_logins" | grep -E '\[bot\]$' | sort -u || true)

  repo_bot_authors=$(
    gh api "repos/$REPO/pulls?state=all&per_page=10" --jq '.[].number' 2>/dev/null \
      | while read -r n; do
          gh api "repos/$REPO/pulls/$n/reviews" --jq '.[].user.login' 2>/dev/null
        done || true
  )
  # Keep only logins that EXACTLY equal a KNOWN_A login (field 1).
  repo_known_logins=$(printf '%s\n' "$repo_bot_authors" | sort -u | while IFS= read -r l; do
    [ -z "$l" ] && continue
    awk -F'|' -v L="$l" '$1==L {print L; exit}' <<<"$KNOWN_A"
  done)
  [ -z "$pr_logins" ] && [ -z "$repo_known_logins" ] \
    && echo "detect: no tier-A bots on $REPO#$PR or recent repo PRs" >&2
else
  echo "detect: gh not available — tier A empty" >&2
fi

emit_a() { # $1 login, $2 reviewer_status
  local login="$1" status="$2" known id retrigger
  known=$(awk -F'|' -v L="$login" '$1==L {print; exit}' <<<"$KNOWN_A")
  if [ -n "$known" ]; then
    id=$(cut -d'|' -f2 <<<"$known"); retrigger=$(cut -d'|' -f3 <<<"$known")
  else
    id=$(sed 's/\[bot\]$//' <<<"$login" | tr -cd 'a-zA-Z0-9-'); retrigger="none"
  fi
  add_row "$(jq -nc --arg id "$id" --arg login "$login" --arg rt "$retrigger" --arg st "$status" \
    '{id:$id,tier:"A",login:$login,retrigger:$rt,reviewer_status:$st,last_reviewed_sha:"",requested_at:""}')"
}

seen_logins=""
if [ -n "$pr_logins" ]; then
  while IFS= read -r login; do
    [ -z "$login" ] && continue
    emit_a "$login" "active"
    seen_logins="$seen_logins$login
"
  done <<<"$pr_logins"
fi
# Seed known repo bots not already active on this PR as "expected".
if [ -n "$repo_known_logins" ]; then
  while IFS= read -r login; do
    [ -z "$login" ] && continue
    printf '%s\n' "$seen_logins" | grep -qxF "$login" && continue
    emit_a "$login" "expected"
  done <<<"$repo_known_logins"
fi

# ---- Tier B ---------------------------------------------------------------
while IFS= read -r entry; do
  [ -z "$entry" ] && continue
  bin=$(cut -d'|' -f1 <<<"$entry")
  id=$(cut -d'|' -f2 <<<"$entry")
  if command -v "$bin" >/dev/null 2>&1; then
    add_row "$(jq -nc --arg id "$id" \
      '{id:$id,tier:"B",login:"",retrigger:"local",reviewer_status:"active",last_reviewed_sha:"",requested_at:""}')"
  else
    echo "detect: tier-B CLI '$bin' not on PATH — row skipped" >&2
  fi
done <<<"$KNOWN_B"

# ---- Tier C ---------------------------------------------------------------
add_row "$(jq -nc \
  '{id:"claude-subagent",tier:"C",login:"",retrigger:"local",reviewer_status:"active",last_reviewed_sha:"",requested_at:""}')"

printf '%s\n' "$rows"
exit 0
