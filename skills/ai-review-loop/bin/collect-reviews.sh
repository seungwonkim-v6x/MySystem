#!/bin/bash
# collect-reviews.sh <owner/repo> <pr_number> <state_file>
#
# Incremental collector over the THREE comment surfaces of a PR:
#   1. reviews         GET /pulls/N/reviews        (ETag-cached; 304 = no change)
#   2. inline_comments GET /pulls/N/comments       (always fully paged, id-filtered)
#   3. issue_comments  GET /issues/N/comments      (always fully paged, id-filtered
#                                                   + edited-in-place detection via body hash)
#
# ETag is trusted ONLY on the reviews surface: list ETags are per page URL,
# so a page-1 304 on a paginated surface can mask appended comments. Comment
# surfaces are therefore always fully paged — the full walk IS the positive
# confirmation that nothing was missed.
#
# Pure reader: never writes the state file. Increment JSON on stdout:
#   { new_reviews:[], new_inline:[], new_issue:[], edited:[],
#     etags:{reviews:"..."}, head_sha:"...", comment_hashes:{...} }
# Exit codes: 0 ok, 1 usage, 2 fetch failure (caller: retry once, then
# escalate — a broken collector must NEVER count as "no new findings").
set -u

# --gist "<finding title>" : pure-function mode (OQ3 normalization).
# Emits the normalized gist on stdout and exits. lowercase → strip
# punctuation (non-alnum → space; CJK and other letters pass through) →
# drop stopwords → first 8 tokens. Fingerprint identity = "<path>#<gist>".
if [ "${1:-}" = "--gist" ]; then
  title="${2:?usage: collect-reviews.sh --gist \"<title>\"}"
  printf '%s' "$title" | tr '[:upper:]' '[:lower:]' \
    | sed -E 's/[^[:alnum:][:space:]]+/ /g' \
    | tr -s '[:space:]' ' ' \
    | awk '{
        n=0
        for (i=1; i<=NF && n<8; i++) {
          w=$i
          if (w ~ /^(a|an|the|is|are|be|to|of|in|on|for|this|that|it|should|could|may|might)$/) continue
          printf (n>0 ? " %s" : "%s"), w; n++
        }
      }'
  echo ""
  exit 0
fi

REPO="${1:?usage: collect-reviews.sh <owner/repo> <pr> <state_file>}"
PR="${2:?usage: collect-reviews.sh <owner/repo> <pr> <state_file>}"
STATE="${3:?usage: collect-reviews.sh <owner/repo> <pr> <state_file>}"

if [ -f "$STATE" ] && jq -e . "$STATE" >/dev/null 2>&1; then
  LAST_REVIEW_ID=$(jq -r '.cursors.reviews.last_id // 0' "$STATE")
  REVIEWS_ETAG=$(jq -r '.cursors.reviews.etag // ""' "$STATE")
  LAST_INLINE_ID=$(jq -r '.cursors.inline_comments.last_id // 0' "$STATE")
  LAST_ISSUE_ID=$(jq -r '.cursors.issue_comments.last_id // 0' "$STATE")
  HASHES=$(jq -c '.comment_hashes // {}' "$STATE")
else
  LAST_REVIEW_ID=0; REVIEWS_ETAG=""; LAST_INLINE_ID=0; LAST_ISSUE_ID=0
  HASHES="{}"
fi

TMPDIR_C=$(mktemp -d)
trap 'rm -rf "$TMPDIR_C"' EXIT

fetch_paged() { # $1 endpoint -> all items as one JSON array on stdout; rc 2 on failure
  # Capture gh separately from jq: a pipe would surface jq's exit status, so a
  # gh network/rate-limit failure with empty stdout would become `[]` + rc 0 —
  # silently reporting "no new comments", the exact failure the header forbids.
  local raw
  if ! raw=$(gh api "$1" --paginate 2>"$TMPDIR_C/err"); then
    echo "collect: fetch failed for $1: $(head -1 "$TMPDIR_C/err")" >&2
    return 2
  fi
  if ! jq -sc 'add // []' <<<"$raw" 2>/dev/null; then
    echo "collect: malformed JSON for $1" >&2
    return 2
  fi
}

# ---- head SHA -------------------------------------------------------------
HEAD_SHA=$(gh api "repos/$REPO/pulls/$PR" --jq '.head.sha' 2>/dev/null) || {
  echo "collect: cannot read PR head (PR closed/deleted or network down)" >&2
  exit 2
}

# ---- surface 1: reviews (FULL page walk, id-filtered) -----------------------
# NOT ETag-cached: list ETags are per-page, and reviews arrive in ascending
# id order (new ones land on the LAST page), so a page-1 304 on a PR with
# >100 reviews would mask appended reviews → false convergence. The full
# walk IS the positive confirmation. (Same rule the comment surfaces use.)
REVIEWS_ALL=$(fetch_paged "repos/$REPO/pulls/$PR/reviews?per_page=100") || exit 2
NEW_REVIEWS=$(jq -c --argjson last "$LAST_REVIEW_ID" \
  '[.[] | select(.id > $last)]' <<<"$REVIEWS_ALL")
NEW_ETAG=""  # reviews surface no longer ETag-cached (kept for output shape compat)

# ---- surface 2: inline review comments (full page walk) --------------------
INLINE_ALL=$(fetch_paged "repos/$REPO/pulls/$PR/comments?per_page=100&sort=created&direction=asc") || exit 2
NEW_INLINE=$(jq -c --argjson last "$LAST_INLINE_ID" \
  '[.[] | select(.id > $last)]' <<<"$INLINE_ALL")

# ---- surface 3: issue comments (full walk + edited-in-place detection) -----
ISSUE_ALL=$(fetch_paged "repos/$REPO/issues/$PR/comments?per_page=100") || exit 2
NEW_ISSUE=$(jq -c --argjson last "$LAST_ISSUE_ID" \
  '[.[] | select(.id > $last)]' <<<"$ISSUE_ALL")

# Edited detection: already-seen issue comments whose body hash changed.
# Bodies are processed inside jq/files only — never shell-interpolated (SEC2).
EDITED="[]"
NEW_HASHES="{}"
while IFS=$'\t' read -r cid body_b64; do
  [ -z "$cid" ] && continue
  hash=$(printf '%s' "$body_b64" | base64 -d 2>/dev/null | shasum -a 256 | cut -d' ' -f1)
  NEW_HASHES=$(jq -c --arg id "$cid" --arg h "$hash" '. + {($id): $h}' <<<"$NEW_HASHES")
  old=$(jq -r --arg id "$cid" '.[$id] // ""' <<<"$HASHES")
  if [ -n "$old" ] && [ "$old" != "$hash" ]; then
    row=$(jq -c --argjson id "$cid" '[.[] | select(.id == $id)] | .[0]' <<<"$ISSUE_ALL")
    EDITED=$(jq -c --argjson row "$row" '. + [$row]' <<<"$EDITED")
  fi
done < <(jq -r '.[] | [(.id|tostring), (.body // "" | @base64)] | @tsv' <<<"$ISSUE_ALL")

jq -nc \
  --argjson new_reviews "$NEW_REVIEWS" \
  --argjson new_inline "$NEW_INLINE" \
  --argjson new_issue "$NEW_ISSUE" \
  --argjson edited "$EDITED" \
  --arg etag "$NEW_ETAG" \
  --arg head "$HEAD_SHA" \
  --argjson hashes "$NEW_HASHES" \
  '{new_reviews:$new_reviews, new_inline:$new_inline, new_issue:$new_issue,
    edited:$edited, etags:{reviews:$etag}, head_sha:$head, comment_hashes:$hashes}'
exit 0
