#!/bin/bash
# loop-markers.sh <owner/repo> <pr_number> <loop_login>
#
# Emit the set of fingerprint hashes the loop has ALREADY replied/acted on,
# reconstructed from loop markers on the PR — used for corrupt-state recovery
# and `--status --verify`.
#
# Trust boundary (harness-enforced, not prompt-only): a marker is authoritative
# ONLY when the comment carrying it was authored by the loop's own account
# (<loop_login>). The gist algorithm is public, so any PR participant — incl.
# the untrusted bots being triaged — can forge a `<!-- ai-review-loop:v1
# fp=... -->` to suppress a reply and fake convergence. This filters by author
# BEFORE extracting any marker, so a forged marker on someone else's comment is
# ignored.
#
# Stdout: one line per recovered marker: "<fp> <round> <kind>".
# Exit: 0 ok (possibly empty), 1 usage, 2 fetch failure.
set -u

REPO="${1:?usage: loop-markers.sh <owner/repo> <pr> <loop_login>}"
PR="${2:?usage: loop-markers.sh <owner/repo> <pr> <loop_login>}"
LOOP_LOGIN="${3:?usage: loop-markers.sh <owner/repo> <pr> <loop_login>}"

fetch() { # $1 endpoint -> base64 bodies of loop-authored comments; rc 2 on fail
  local raw
  if ! raw=$(gh api "$1" --paginate 2>/dev/null); then return 2; fi
  # Keep only comments authored by the loop account, emit body (base64) to
  # keep untrusted text off the shell.
  jq -sr --arg who "$LOOP_LOGIN" \
    'add // [] | .[] | select(.user.login == $who) | (.body // "" | @base64)' <<<"$raw"
}

extract() { # reads base64 bodies on stdin, emits "fp round kind" per marker
  while IFS= read -r b64; do
    [ -z "$b64" ] && continue
    printf '%s' "$b64" | base64 -d 2>/dev/null | \
      grep -oE 'ai-review-loop:v1 fp=[^ ]+ round=[^ ]+ kind=[^ ]+' | \
      sed -E 's/ai-review-loop:v1 fp=([^ ]+) round=([^ ]+) kind=([^ ]+)/\1 \2 \3/'
  done
}

# Fetch into vars FIRST (a `{ } | extract` pipe would run the group in a
# subshell and lose the failure rc). Any surface failure → exit 2 so the
# caller never mistakes a fetch error for an empty (fully-replied) set.
BODIES_PR=$(fetch "repos/$REPO/pulls/$PR/comments")   || exit 2
BODIES_ISSUE=$(fetch "repos/$REPO/issues/$PR/comments") || exit 2

printf '%s\n%s\n' "$BODIES_PR" "$BODIES_ISSUE" | extract | sort -u
exit 0
