#!/bin/bash
# post-reply.sh <owner/repo> <pr_number> --body-file <file> \
#               (--comment-id <id> | --issue) [--fp <hash>] [--round <n>] [--kind <reply|lifecycle>]
#
# The ONLY path by which the loop posts to a PR (SEC2/EA2). Bodies arrive
# via FILE — inline body strings are forbidden, so untrusted quoted bot text
# never touches a shell-interpolated argument.
#
#   --comment-id <id>  reply to a TOP-LEVEL inline review comment
#                      (POST /pulls/N/comments/<id>/replies)
#   --issue            post a PR conversation comment
#                      (POST /issues/N/comments) — used for replies to
#                      review-summary bodies and for lifecycle comments (DX1)
#
# Embeds the loop marker (EA5) before posting:
#   <!-- ai-review-loop:v1 fp=<hash> round=<n> kind=<kind> -->
# Rate limits (F6): >=1s spacing before every POST; on 403/429 honor
# Retry-After (default 60s) and retry ONCE. On 404 for a reply target,
# re-resolve the thread root via in_reply_to_id and retry ONCE (E2).
#
# Stdout: "COMMENT_ID: <id>" on success.
# Exit: 0 ok, 2 usage, 6 unrecoverable (after retries) — caller logs and
# continues; reply failure never crashes the loop.
set -u

REPO="${1:?usage: post-reply.sh <owner/repo> <pr> --body-file <f> (--comment-id <id>|--issue) [--fp <h>] [--round <n>] [--kind <k>]}"
PR="${2:?usage}"
shift 2

BODY_FILE="" COMMENT_ID="" ISSUE_MODE="" FP="" ROUND="" KIND="reply"
while [ $# -gt 0 ]; do
  case "$1" in
    --body-file)  BODY_FILE="$2"; shift 2 ;;
    --comment-id) COMMENT_ID="$2"; shift 2 ;;
    --issue)      ISSUE_MODE=1; shift ;;
    --fp)         FP="$2"; shift 2 ;;
    --round)      ROUND="$2"; shift 2 ;;
    --kind)       KIND="$2"; shift 2 ;;
    *) echo "unknown arg: $1" >&2; exit 2 ;;
  esac
done
[ -z "$BODY_FILE" ] || [ ! -f "$BODY_FILE" ] && { echo "STOP: --body-file required and must exist" >&2; exit 2; }
[ -z "$COMMENT_ID" ] && [ -z "$ISSUE_MODE" ] && { echo "STOP: need --comment-id or --issue" >&2; exit 2; }

# Marker append (file-level — body content itself is never a shell arg)
MARKED=$(mktemp)
trap 'rm -f "$MARKED"' EXIT
cat "$BODY_FILE" > "$MARKED"
printf '\n\n<!-- ai-review-loop:v1 fp=%s round=%s kind=%s -->\n' \
  "${FP:-none}" "${ROUND:-0}" "$KIND" >> "$MARKED"

post() { # $1 endpoint -> response JSON on stdout; rc = gh's rc
  gh api -X POST "$1" -F "body=@$MARKED" 2>"$ERRFILE"
}

do_post() { # $1 endpoint; echoes comment id on success, returns 0/1
  local ep="$1" out rc
  ERRFILE=$(mktemp)
  # >=1s spacing between content-creating POSTs (secondary limits). Tests set
  # AI_REVIEW_LOOP_MIN_SPACING=0 to keep the suite under its <5s budget.
  sleep "${AI_REVIEW_LOOP_MIN_SPACING:-1}"
  out=$(post "$ep"); rc=$?
  if [ $rc -ne 0 ]; then
    if grep -qE 'HTTP 4(03|29)' "$ERRFILE"; then
      # Retry-After parse is best-effort — gh surfaces response headers on
      # errors inconsistently; when absent we fall back to a fixed backoff.
      local wait
      wait=$(grep -io 'retry-after: *[0-9]*' "$ERRFILE" | grep -o '[0-9]*' | head -1)
      wait="${wait:-${AI_REVIEW_LOOP_RETRY_BACKOFF:-60}}"
      sleep "$wait"
      out=$(post "$ep"); rc=$?
    elif grep -q 'HTTP 404' "$ERRFILE" && [ -n "$COMMENT_ID" ]; then
      # reply-to-a-reply or stale id: re-resolve thread root (E2)
      local root
      root=$(gh api "repos/$REPO/pulls/comments/$COMMENT_ID" --jq '.in_reply_to_id // empty' 2>/dev/null)
      if [ -n "$root" ]; then
        out=$(post "repos/$REPO/pulls/$PR/comments/$root/replies"); rc=$?
      fi
    fi
  fi
  rm -f "$ERRFILE"
  [ $rc -ne 0 ] && return 1
  jq -r '"COMMENT_ID: \(.id)"' <<<"$out"
}

if [ -n "$ISSUE_MODE" ]; then
  do_post "repos/$REPO/issues/$PR/comments" || { echo "STOP: post failed after retries" >&2; exit 6; }
else
  do_post "repos/$REPO/pulls/$PR/comments/$COMMENT_ID/replies" || { echo "STOP: post failed after retries" >&2; exit 6; }
fi
exit 0
