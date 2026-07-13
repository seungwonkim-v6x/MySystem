#!/usr/bin/env bash
# Adapted from https://github.com/mattpocock/skills
# Path: skills/misc/git-guardrails-claude-code/scripts/block-dangerous-git.sh
# Adapted: 2026-05-18 — added fail-open trap, MYSYSTEM_HOOKS_ENFORCE gating,
#          dry-run log integration, hard-refuse for force-push to main/master
#          regardless of MYSYSTEM_ALLOW_FORCE_PUSH (prompt-injection defense).
# Revised: 2026-07-13 (ADR-0015 harness diet) —
#          * hard-refuse tier now exits 2 UNCONDITIONALLY (no ENFORCE gate);
#            soft tier keeps the dry-run default.
#          * command-start anchoring + quoted-segment stripping so echoed /
#            grepped / heredoc'd / commit-message text never false-positives.
#          * new hard refuses: `git commit --no-verify` (incl. bundled -n) and
#            `git reset --hard` while on main/master.
#          * hard tier fails CLOSED when the payload cannot be parsed (jq →
#            python3 fallback first); soft path stays fail-open.
# License: see upstream repo (verify before vendor).
#
# Blocks destructive git verbs at PreToolUse Bash. Reads JSON payload from stdin
# via Claude Code hook protocol.
#
# Bypass mechanisms:
#   MYSYSTEM_ALLOW_FORCE_PUSH=1   — allow git push --force on feature branches
#                                    (HARD REFUSE for origin main/master regardless)
#   Hard refuses have NO env bypass. Human operators bypass by editing this
#   hook (deliberate friction; see TESTING.md) — that remedy is intentionally
#   NOT printed to the agent.
#
# Modes:
#   MYSYSTEM_HOOKS_ENFORCE=1      — soft tier actually blocks (exit 2).
#                                    Default = soft tier dry-runs (exit 0).
#                                    Hard tier ignores this flag entirely.

set +e  # never let an internal error bubble to exit code

LOG_DIR="$HOME/.claude/logs"
DRY_RUN_LOG="$LOG_DIR/hook-dry-run.log"
ERROR_LOG="$LOG_DIR/hook-errors.log"
BLOCK_LOG="$LOG_DIR/hook-blocks.log"
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

log_block() {
  # Enforced blocks get their own log so /retro can measure real (not
  # hypothetical) friction — the rail-abandonment early-warning signal.
  local reason="$1"
  local cmd_preview="$2"
  mkdir -p "$LOG_DIR" 2>/dev/null
  printf '%s %s BLOCKED: %s | cmd: %s\n' "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$HOOK_NAME" "$reason" "$cmd_preview" >> "$BLOCK_LOG" 2>/dev/null
}

# Read payload. The hard-refuse tier is only "unconditional" if we can always
# evaluate it, so an unparseable payload fails CLOSED (loud, with the real
# cause named — this is an environment failure, not a judgment on the command).
PAYLOAD=$(cat 2>/dev/null) || { log_error "could not read stdin"; exit 0; }
COMMAND=""
if command -v jq >/dev/null 2>&1; then
  COMMAND=$(printf '%s' "$PAYLOAD" | jq -r '.tool_input.command // ""' 2>/dev/null)
  PARSE_OK=$?
elif command -v python3 >/dev/null 2>&1; then
  COMMAND=$(printf '%s' "$PAYLOAD" | python3 -c 'import json,sys;print(json.load(sys.stdin).get("tool_input",{}).get("command",""))' 2>/dev/null)
  PARSE_OK=$?
else
  PARSE_OK=1
fi
if [ "${PARSE_OK:-1}" != "0" ]; then
  log_error "cannot parse hook payload (jq and python3 unavailable or payload malformed)"
  printf 'BLOCKED: %s fails closed: cannot parse the hook payload (jq missing or malformed input).\nCause: this is an ENVIRONMENT failure, not a judgment on your command.\nFix: install jq (brew install jq) or repair the hook input; then retry.\n' "$HOOK_NAME" >&2
  exit 2
fi

if [ -n "${MYSYSTEM_HOOK_CANARY_LOG:-}" ]; then
  printf '%s\n' "$HOOK_NAME" >> "$MYSYSTEM_HOOK_CANARY_LOG" 2>/dev/null
fi

if [ -z "$COMMAND" ]; then
  exit 0
fi

# ── Build the matching text (order matters; each step closes a bypass or a
#    false-positive class, both pinned by tests/hooks.bats) ──────────────────
# 1. Strip heredoc BODIES (docs/tests written via heredoc must not trip rules;
#    the body is data, not a command). Fail direction: if parsing misses, the
#    body is kept and may over-block — never under-block.
HEREDOC_STRIPPED=$(printf '%s\n' "$COMMAND" | awk '
  BEGIN { ind = 0 }
  ind == 0 {
    if (match($0, /<<-?[ \t]*["'"'"']?[A-Za-z0-9_][A-Za-z0-9_.-]*/)) {
      tag = substr($0, RSTART, RLENGTH)
      sub(/<<-?[ \t]*["'"'"']?/, "", tag)
      print; ind = 1; next
    }
    print; next
  }
  ind == 1 {
    line = $0; gsub(/^[ \t]+/, "", line)
    if (line == tag) { ind = 0 }
    next
  }
  END { if (ind == 1) print "MYSYSTEM_UNTERMINATED_HEREDOC" }
' 2>/dev/null)
# Fail-safe direction: a tag-parse miss must never DROP later real commands
# (under-block). If the heredoc never terminated, keep the original text and
# accept possible over-blocking of body lines instead.
case "$HEREDOC_STRIPPED" in
  *MYSYSTEM_UNTERMINATED_HEREDOC*|"") HEREDOC_STRIPPED="$COMMAND" ;;
esac
# 2. Newlines are command separators — a multi-line Bash call must not demote
#    line 2 to "prose position". Then collapse whitespace.
NORMALIZED=$(printf '%s' "$HEREDOC_STRIPPED" | tr '\n' ';' | tr -s '[:space:]' ' ')
# 3. Remove commit-message arguments (-m/--message "…") so message TEXT can
#    never trip a rule.
MSGLESS=$(printf '%s' "$NORMALIZED" | sed -E "s/(-m|--message)[= ]('[^']*'|\"[^\"]*\")//g")
# 4. Drop remaining quote CHARACTERS but keep contents: quoting a real
#    argument (git push --force origin \"main\", git commit \"--no-verify\")
#    must not defeat a rule, while prose mentions (echo/grep bodies) stay
#    non-matching because they never sit at a command-start position.
MATCHTEXT=$(printf '%s' "$MSGLESS" | tr -d "\"'")

REASON=""
HARD_REFUSE=0
FIX_HINT=""

# GIT_VERB anchors "git" to a command-start position: start of string, after a
# separator (; | ( & or a backtick — backticks in unquoted/double-quoted text
# EXECUTE), optionally behind a sh/bash/zsh -c wrapper, VAR=x assignment
# prefixes, `env`, and `-c key=val` / `-C path` git option pairs. Catches
# `git -c user.name=foo push --force origin main`, `GIT_TRACE=1 git push …`,
# and `bash -c "git push …"` style bypasses.
CMD_START='(^|[;|({&`]) ?'
# Exec-prefix words that RUN their argument as a command (sudo git …,
# command git …, xargs git …, then git … inside control flow, brace groups).
# Flags may carry one non-dash argument (sudo -u root git …, env -i git …).
# String-consuming words (echo, printf, grep) are deliberately NOT listed so
# mentions stay non-matching.
EXEC_PREFIX='((sudo|command|nohup|time|xargs|builtin|exec|eval|env|do|then|else)( -[A-Za-z-]+( [^ -][^ ]*)?)* )*'
# sh -c in any spelling: bash -c, bash -lc, bash -o pipefail -c, zsh -c …
SH_WRAP='((ba|z|da)?sh( -o [A-Za-z]+| -[a-zA-Z]+)* -[a-zA-Z]*c[a-zA-Z]* )?'
ASSIGN_PREFIX='([A-Za-z_][A-Za-z0-9_]*=[^ ]* )*'
GIT_OPTS='( (-c [^ ]+|-C [^ ]+|--[a-z][a-z-]*(=[^ ]+)?))*'
GIT_VERB="${CMD_START}${EXEC_PREFIX}${SH_WRAP}${ASSIGN_PREFIX}(env( [A-Za-z_][A-Za-z0-9_]*=[^ ]*)* )?git${GIT_OPTS}"

# Hard-refuse main/master force-push across all refspec variants:
#   git push --force origin main
#   git push --force-with-lease origin main
#   git push origin main --force
#   git push origin HEAD:main           (with force flag or +prefix)
#   git push origin refs/heads/main     (with force flag or +prefix)
#   git push origin +main               (+ is a force-push refspec)
#   git push origin +refs/heads/main
PROTECTED='(main|master)'
FORCE_FLAG='(--force(-with-lease)?|-f)'

# Current branch for the reset --hard rule; empty when not in a repo or
# undeterminable (detached HEAD prints "HEAD" — treated as not-protected).
CURRENT_BRANCH=$(git rev-parse --abbrev-ref HEAD 2>/dev/null)

if echo "$MATCHTEXT" | grep -Eq "${GIT_VERB} push (\S+ )*\+(refs/heads/)?${PROTECTED}\b"; then
  REASON="force-push (refspec +${PROTECTED}) to origin main/master (hard refuse, no bypass)"
  FIX_HINT="Fix: push to a feature branch and open a PR instead."
  HARD_REFUSE=1
elif echo "$MATCHTEXT" | grep -Eq "${GIT_VERB} push ${FORCE_FLAG}( |=|$).*\bref(s/heads)?/${PROTECTED}\b|${GIT_VERB} push \S+ \S*:?(refs/heads/)?${PROTECTED} ${FORCE_FLAG}\b"; then
  REASON="force-push (refs/heads/ syntax) to origin main/master (hard refuse, no bypass)"
  FIX_HINT="Fix: push to a feature branch and open a PR instead."
  HARD_REFUSE=1
elif echo "$MATCHTEXT" | grep -Eq "${GIT_VERB} push ${FORCE_FLAG}( |=|$).*\bHEAD:${PROTECTED}\b|${GIT_VERB} push \S+ HEAD:${PROTECTED} ${FORCE_FLAG}\b"; then
  REASON="force-push (HEAD:${PROTECTED}) to origin main/master (hard refuse, no bypass)"
  FIX_HINT="Fix: push to a feature branch and open a PR instead."
  HARD_REFUSE=1
elif echo "$MATCHTEXT" | grep -Eq "${GIT_VERB} push ${FORCE_FLAG}( |=|$).*origin ${PROTECTED}\b|${GIT_VERB} push \S+ ${PROTECTED} ${FORCE_FLAG}\b"; then
  REASON="force-push (including --force-with-lease) to origin main/master (hard refuse, no bypass)"
  FIX_HINT="Fix: push to a feature branch and open a PR instead."
  HARD_REFUSE=1
elif echo "$MATCHTEXT" | grep -Eq "${GIT_VERB} push[^;|&]* ${FORCE_FLAG}[^;|&]*[ :+/=](${PROTECTED})( |;|$)" \
  || echo "$MATCHTEXT" | grep -Eq "${GIT_VERB} push[^;|&]*[ :+/](${PROTECTED})[^;|&]* ${FORCE_FLAG}( |=|;|$)"; then
  # Catch-all for flag/refspec orderings the specific rules above miss
  # (e.g. `git push origin --force main`). Segment-scoped ([^;|&]*) so a
  # force-push to a feature branch followed by an unrelated mention of main
  # in another command cannot combine into a false positive.
  REASON="force-push to origin main/master (flag/refspec reordered — hard refuse, no bypass)"
  FIX_HINT="Fix: push to a feature branch and open a PR instead."
  HARD_REFUSE=1
elif echo "$MATCHTEXT" | grep -Eq "${GIT_VERB} commit\b[^;|&]* --no-verify\b" \
  || echo "$MATCHTEXT" | grep -Eq "${GIT_VERB} commit\b[^;|&]* -[a-zA-Z]*n[a-zA-Z]*\b"; then
  REASON="git commit --no-verify / -n bypasses repo pre-commit hooks (hard refuse)"
  FIX_HINT="Fix: rerun the same commit without --no-verify; if a pre-commit hook is failing, fix the failure it reports. Bypass is human-only."
  HARD_REFUSE=1
elif echo "$MATCHTEXT" | grep -Eq "${GIT_VERB} reset --hard\b"; then
  if [ "$CURRENT_BRANCH" = "main" ] || [ "$CURRENT_BRANCH" = "master" ]; then
    REASON="git reset --hard on ${CURRENT_BRANCH} (hard refuse)"
    FIX_HINT="Fix: switch to a feature branch first, or use git stash to set work aside."
    HARD_REFUSE=1
  else
    REASON="git reset --hard"
  fi
elif echo "$MATCHTEXT" | grep -Eq "${GIT_VERB} push ${FORCE_FLAG}\b"; then
  REASON="git push --force / --force-with-lease"
elif echo "$MATCHTEXT" | grep -Eq "${GIT_VERB} push\b"; then
  REASON="git push (use /ship to push)"
elif echo "$MATCHTEXT" | grep -Eq "${GIT_VERB} clean -[a-zA-Z]*f"; then
  REASON="git clean -f"
elif echo "$MATCHTEXT" | grep -Eq "${GIT_VERB} branch -D\b"; then
  REASON="git branch -D"
elif echo "$MATCHTEXT" | grep -Eq "${GIT_VERB} checkout \. ?($|;)"; then
  REASON="git checkout . (discards working tree)"
elif echo "$MATCHTEXT" | grep -Eq "${GIT_VERB} restore \. ?($|;)"; then
  REASON="git restore . (discards working tree)"
fi

if [ -z "$REASON" ]; then
  exit 0
fi

ENFORCE="${MYSYSTEM_HOOKS_ENFORCE:-}"
BYPASS="${MYSYSTEM_ALLOW_FORCE_PUSH:-}"

# Hard refuse: unconditional (ADR-0015). No ENFORCE gate, no env bypass.
if [ "$HARD_REFUSE" = "1" ]; then
  log_block "$REASON" "${NORMALIZED:0:200}"
  printf 'BLOCKED: %s refused: %s\n%s\n' "$HOOK_NAME" "$REASON" "$FIX_HINT" >&2
  exit 2
fi

# Bypass — only soft refuses honor it.
if [ "$BYPASS" = "1" ]; then
  # User explicitly opted in; allow.
  exit 0
fi

if [ "$ENFORCE" = "1" ]; then
  log_block "$REASON" "${NORMALIZED:0:200}"
  printf 'BLOCKED: %s refused: %s. Set MYSYSTEM_ALLOW_FORCE_PUSH=1 for feature-branch force-push only.\n' "$HOOK_NAME" "$REASON" >&2
  exit 2
fi

log_dry_run "$REASON" "${NORMALIZED:0:200}"
printf '[DRY-RUN] %s WOULD BLOCK: %s\n' "$HOOK_NAME" "$REASON" >&2
exit 0
