#!/bin/bash
# round-budget.sh [--staged | --range <A..B>]
#
# Budget + sensitive-path gate for a round's fixes (EA8/EA10/EA11/DX3).
# Default mode --staged: measures the STAGED diff (fixes are staged, never
# committed, until this gate passes). --range exists for auditing already-
# pushed loop commits (e.g. resume verification), same rules.
#
# Stdout:  "LINES: <n>"  plus zero or more "SENSITIVE: <path>" / "BINARY: <path>"
# Exit codes:
#   0 = within round budget (<= 20 changed lines), no sensitive/binary paths
#   3 = over round budget (> 20) — approve / split / decline-all gate
#   4 = binary file in diff — escalate (bot-suggested binary change is suspicious)
#   5 = sensitive path in diff — always escalate, line count irrelevant
#   2 = usage / not a git repo
#
# Cumulative accounting is the SKILL layer's job (sum of APPROVED rounds'
# LINES values, cap 40) — this script measures one round.
set -u

MODE="${1:---staged}"
RANGE="${2:-}"

case "$MODE" in
  --staged) DIFF_ARGS=(--cached) ;;
  --range)
    [ -z "$RANGE" ] && { echo "usage: round-budget.sh --range <A..B>"; exit 2; }
    DIFF_ARGS=("$RANGE") ;;
  *) echo "usage: round-budget.sh [--staged | --range <A..B>]"; exit 2 ;;
esac

git rev-parse --git-dir >/dev/null 2>&1 || { echo "STOP: not a git repo"; exit 2; }

SENSITIVE_GLOBS=(
  "hooks/*" "settings.json" ".github/workflows/*"
  "*secret*" "*credential*" ".env*" "*/.env*" "install.sh" "setup.sh"
)

is_sensitive() { # $1 = path (rename-normalized)
  local p="$1" g
  for g in "${SENSITIVE_GLOBS[@]}"; do
    # shellcheck disable=SC2254
    case "$p" in $g|*/$g) return 0 ;; esac
  done
  return 1
}

total=0
rc=0
binary_hit=""
sensitive_hit=""

# -z: NUL-delimited records — robust for tabs/renames. Record shape per file:
#   added \t deleted \t <path>            (normal)
#   added \t deleted \t\0 old \0 new      (rename/copy: empty path, then two NUL fields)
while IFS=$'\t' read -r -d '' added deleted path; do
  if [ -z "$path" ]; then
    # rename: consume the two NUL-delimited path fields, keep the NEW path
    IFS= read -r -d '' _old || true
    IFS= read -r -d '' path || true
  fi
  [ -z "${path:-}" ] && continue
  if [ "$added" = "-" ] || [ "$deleted" = "-" ]; then
    echo "BINARY: $path"
    binary_hit=1
    continue
  fi
  total=$(( total + added + deleted ))
  if is_sensitive "$path"; then
    echo "SENSITIVE: $path"
    sensitive_hit=1
  fi
done < <(git diff --numstat -z "${DIFF_ARGS[@]}" 2>/dev/null)

echo "LINES: $total"

if [ -n "$sensitive_hit" ]; then rc=5
elif [ -n "$binary_hit" ]; then rc=4
elif [ "$total" -gt 20 ]; then rc=3
fi
exit "$rc"
