#!/usr/bin/env bash
# Isolated, recoverable installer for MySystem's Codex parity assets.

set -euo pipefail

SCRIPT_DIR=$(CDPATH= cd -- "$(dirname "$0")" && pwd)
REPO_ROOT=${MYSYSTEM_REPO_ROOT:-$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)}
MYSYSTEM_REPO_ROOT=$REPO_ROOT
CONTRACT="$REPO_ROOT/codex/parity-contract.json"
RENDERER="$REPO_ROOT/scripts/render-codex-agents.sh"
DOCTOR="$REPO_ROOT/scripts/codex-parity-doctor.sh"
# shellcheck source=scripts/codex-parity-lib.sh
. "$REPO_ROOT/scripts/codex-parity-lib.sh"

MODE=install
INSTALL_STARTED=$SECONDS
EXPLICIT_HOMES_FILE=$(mktemp "${TMPDIR:-/tmp}/mysystem-explicit-homes.XXXXXX")
RECORDS_FILE=$(mktemp "${TMPDIR:-/tmp}/mysystem-install-records.XXXXXX")
HOMES_FILE=$(mktemp "${TMPDIR:-/tmp}/mysystem-codex-homes.XXXXXX")
trap 'parity_release_lock; rm -f "$EXPLICIT_HOMES_FILE" "$RECORDS_FILE" "$HOMES_FILE"' EXIT HUP INT TERM

usage() {
  cat <<'EOF'
Usage: scripts/install-codex-parity.sh [--check|--recover] [--codex-home PATH]...

Default mode renders and installs managed parity links. --check is read-only.
--recover restores the most recent approved legacy backup when its destination
still points at the expected MySystem target.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check)
      [ "$MODE" = install ] || { usage >&2; exit 2; }
      MODE=check
      shift
      ;;
    --recover)
      [ "$MODE" = install ] || { usage >&2; exit 2; }
      MODE=recover
      shift
      ;;
    --codex-home)
      [ "$#" -ge 2 ] || { usage >&2; exit 2; }
      printf '%s\n' "$2" >> "$EXPLICIT_HOMES_FILE"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      usage >&2
      exit 2
      ;;
  esac
done

command -v jq >/dev/null 2>&1 || { parity_fail INSTALL_JQ_MISSING jq "Required installer dependency is missing" "jq is not on PATH" "Install jq using the prerequisites section" parity-contract; exit 1; }
command -v python3 >/dev/null 2>&1 || { parity_fail INSTALL_PYTHON_MISSING python3 "Required installer dependency is missing" "python3 is not on PATH" "Install Python 3 using the prerequisites section" parity-contract; exit 1; }
jq -e '.schema_version == 1' "$CONTRACT" >/dev/null || { parity_fail CONTRACT_INVALID "$CONTRACT" "Parity contract is invalid" "The contract is missing or has an unsupported schema" "Restore the contract from the reviewed release" parity-contract; exit 1; }

add_home() {
  local path=$1 kind=$2 allow_missing=$3 normalized existing
  parity_validate_home "$path" "$REPO_ROOT" "$allow_missing" 2>/dev/null || {
    parity_fail CODEX_HOME_UNSAFE "$path" "Codex home is unsafe" "The path is missing, linked, unowned, protected, or group/world-writable" "Pass an existing private user-owned Codex home" codex-home-unsafe
    return 1
  }
  normalized=$(python3 - "$path" <<'PY'
import os
import sys
print(os.path.normpath(os.path.abspath(sys.argv[1])))
PY
)
  existing=$(awk -F '\t' -v path="$normalized" '$1 == path { print $1; exit }' "$HOMES_FILE")
  [ -n "$existing" ] || printf '%s\t%s\n' "$normalized" "$kind" >> "$HOMES_FILE"
}

discover_homes() {
  local default_home orca_home explicit
  default_home="$HOME/.codex"
  add_home "$default_home" default 1
  if [ -n "${CODEX_HOME:-}" ]; then
    add_home "$CODEX_HOME" alternate 0
  fi
  orca_home="$HOME/Library/Application Support/orca/codex-runtime-home/home"
  if [ -d "$(dirname "$orca_home")" ]; then
    add_home "$orca_home" orca 0
  fi
  while IFS= read -r explicit; do
    [ -n "$explicit" ] || continue
    add_home "$explicit" alternate 0
  done < "$EXPLICIT_HOMES_FILE"
}

validate_parent() {
  parity_validate_path_chain "$(dirname "$1")" 1
}

add_record() {
  local kind=$1 destination=$2 target=$3 link_target=${4:-$3}
  case "$destination$target$link_target" in
    *$'\t'*|*$'\n'*|*$'\r'*) parity_fail MANAGED_PATH_CONTROL_CHARACTER "$destination" "Managed path contains a control character" "The contract cannot represent this path safely" "Use a normal absolute path without control characters" managed-links; return 1 ;;
  esac
  printf '%s\t%s\t%s\t%s\n' "$kind" "$destination" "$target" "$link_target" >> "$RECORDS_FILE"
}

build_records() {
  local home kind name mode source project_agents default_agents default_hooks default_hook_registration user_skills
  : > "$RECORDS_FILE"
  project_agents=$(parity_managed_path "$CONTRACT" project_agents "$REPO_ROOT")
  default_agents=$(parity_managed_path "$CONTRACT" default_agents "$REPO_ROOT")
  default_hooks=$(parity_managed_path "$CONTRACT" default_hooks "$REPO_ROOT")
  default_hook_registration=$(parity_managed_path "$CONTRACT" default_hook_registration "$REPO_ROOT")
  user_skills=$(parity_managed_path "$CONTRACT" user_skills "$REPO_ROOT")
  add_record project_agents "$project_agents" "$REPO_ROOT/codex/AGENTS.project.md" "codex/AGENTS.project.md"
  while IFS=$'\t' read -r home kind; do
    [ -n "$home" ] || continue
    if [ "$kind" = default ]; then
      add_record default_agents "$default_agents" "$REPO_ROOT/codex/AGENTS.global.md"
    else
      add_record alternate_agents "$home/AGENTS.md" "$REPO_ROOT/codex/AGENTS.global.md"
    fi
  done < "$HOMES_FILE"
  add_record default_hooks "$default_hooks" "$REPO_ROOT/hooks"
  add_record default_hook_registration "$default_hook_registration" "$REPO_ROOT/codex/hooks.json"

  jq -r '.skills[] | select(.mode == "portable-local" or .mode == "portable-sparse") | [.name,.mode,.source] | @tsv' "$CONTRACT" \
    | while IFS=$'\t' read -r name mode source; do
        add_record "skill:$name" "$user_skills/$name" "$REPO_ROOT/$source"
      done
}

preflight_records() {
  local kind destination target link_target state failed=0
  while IFS=$'\t' read -r kind destination target link_target; do
    [ -n "$kind" ] || continue
    if [ ! -e "$target" ]; then
      case "$kind" in
        project_agents|default_agents|alternate_agents) ;;
        *)
          parity_fail MANAGED_SOURCE_MISSING "$target" "Managed source is missing" "The required $kind source was not installed" "Run full ./setup.sh and inspect its earlier stages" managed-links
          failed=1
          continue
          ;;
      esac
    fi
    if ! validate_parent "$destination"; then
      parity_fail MANAGED_PARENT_UNSAFE "$(dirname "$destination")" "Managed parent is unsafe" "A path component is linked, unowned, or group/world-writable" "Move it aside or correct ownership before retrying" managed-links
      failed=1
      continue
    fi
    state=$(parity_path_state "$destination" "$target")
    case "$state" in
      absent|correct-link|wrong-link|empty-dir) ;;
      real-file)
        if ! parity_approved_file "$CONTRACT" "$kind" "$destination"; then
          parity_fail MANAGED_PATH_CONFLICT "$destination" "Unknown real content blocks installation" "$kind is not an approved legacy $state" "Inspect and move the path aside manually" managed-links
          failed=1
        fi
        ;;
      real-dir)
        if ! parity_approved_tree "$CONTRACT" "$kind" "$destination"; then
          parity_fail MANAGED_PATH_CONFLICT "$destination" "Unknown directory content blocks installation" "$kind does not match an exact approved legacy manifest" "Inspect and move the path aside manually" managed-links
          failed=1
        fi
        ;;
      *)
        parity_fail MANAGED_PATH_CONFLICT "$destination" "Unsupported destination state blocks installation" "$kind was classified as $state" "Inspect the path and follow managed-link remediation" managed-links
        failed=1
        ;;
    esac
  done < "$RECORDS_FILE"
  [ "$failed" -eq 0 ]
}

ensure_managed_parents() {
  local home kind
  umask 077
  mkdir -p "$HOME/.codex" "$HOME/.agents/skills"
  while IFS=$'\t' read -r home kind; do
    [ -n "$home" ] || continue
    [ -d "$home" ] || mkdir -p "$home"
  done < "$HOMES_FILE"
}

install_record() {
  local kind=$1 destination=$2 target=$3 link_target=$4 state backup stamp existing_link
  state=$(parity_path_state "$destination" "$target")
  if [ "$kind" = project_agents ] && [ "$state" = correct-link ] && [ "$(readlink "$destination")" != "$link_target" ]; then
    state=wrong-link
  fi
  case "$state" in
    correct-link)
      printf 'PASS LINK_CURRENT %s\n' "$destination"
      ;;
    absent)
      parity_atomic_link "$link_target" "$destination" absent
      printf 'PASS LINK_INSTALLED %s -> %s\n' "$destination" "$link_target"
      ;;
    wrong-link)
      existing_link=$(readlink "$destination")
      parity_atomic_link "$link_target" "$destination" wrong-link "$existing_link"
      printf 'PASS LINK_INSTALLED %s -> %s\n' "$destination" "$link_target"
      ;;
    empty-dir)
      rmdir "$destination"
      parity_fsync_parent "$destination"
      parity_atomic_link "$link_target" "$destination" absent
      printf 'PASS EMPTY_PLACEHOLDER_REPLACED %s -> %s\n' "$destination" "$link_target"
      ;;
    real-file|real-dir)
      if { [ "$state" = real-file ] && ! parity_approved_file "$CONTRACT" "$kind" "$destination"; } || \
         { [ "$state" = real-dir ] && ! parity_approved_tree "$CONTRACT" "$kind" "$destination"; }; then
        parity_fail MANAGED_STATE_CHANGED "$destination" "Approved content changed during installation" "The migration digest no longer matches preflight" "Inspect the path and retry only after it is stable" managed-links
        return 1
      fi
      stamp=$(date -u +%Y%m%dT%H%M%SZ)
      backup="$destination.mysystem-backup.$stamp.$$.$PARITY_LINK_COUNTER"
      parity_write_transaction "$destination" "$backup" "$target" "$kind"
      mv "$destination" "$backup"
      parity_fsync_parent "$destination"
      chmod -R go-rwx "$backup"
      parity_atomic_link "$link_target" "$destination" absent
      parity_record_migration "$destination" "$backup" "$target" "$kind" "$PARITY_TRANSACTION_ID" "$PARITY_BACKUP_IDENTITY"
      parity_remove_durable "$PARITY_TRANSACTION"
      printf 'PASS LEGACY_MIGRATED %s backup=%s\n' "$destination" "$backup"
      ;;
    *)
      parity_fail MANAGED_STATE_CHANGED "$destination" "Managed destination changed during installation" "$kind is now classified as $state" "Inspect the concurrent change before retrying" managed-links
      return 1
      ;;
  esac
}

recover_latest_migration() {
  local entry destination backup target state backup_identity
  parity_acquire_lock
  parity_validate_state "$RECORDS_FILE" "$CONTRACT"
  parity_recover_pending "$RECORDS_FILE" "$CONTRACT"
  if [ ! -s "$PARITY_MIGRATIONS" ]; then
    echo "PASS RECOVERY_NOT_NEEDED: no retained managed migration"
    return 0
  fi
  entry=$(tail -n 1 "$PARITY_MIGRATIONS")
  destination=$(printf '%s' "$entry" | jq -r '.destination')
  backup=$(printf '%s' "$entry" | jq -r '.backup')
  target=$(printf '%s' "$entry" | jq -r '.target')
  backup_identity=$(printf '%s' "$entry" | jq -c '.backup_identity // empty')
  state=$(parity_path_state "$destination" "$target")
  if { [ ! -e "$backup" ] && [ ! -L "$backup" ]; } && [ "$state" != correct-link ] && [ "$state" != absent ]; then
    if [ -n "$backup_identity" ] && parity_identity_matches "$destination" "$backup_identity"; then
      parity_remove_last_migration "$entry"
      echo "PASS RECOVERY_FINALIZED: $destination"
      return 0
    fi
    parity_fail RECOVERY_CONFLICT "$destination" "Recovery cannot prove the prior atomic restore completed" "The backup is missing and destination identity does not match the migration record" "Retain the migration record and inspect the destination manually" interrupted-migration
    return 1
  fi
  if [ "$state" != correct-link ] || { [ ! -e "$backup" ] && [ ! -L "$backup" ]; }; then
    parity_fail RECOVERY_CONFLICT "$destination" "Recovery preconditions no longer hold" "The expected link or adjacent backup changed; state is $state" "Inspect destination and backup manually" interrupted-migration
    return 1
  fi
  if [ -z "$backup_identity" ]; then
    backup_identity=$(parity_approved_identity "$CONTRACT" "$(printf '%s' "$entry" | jq -r '.kind')" "$backup") || {
      parity_fail RECOVERY_BACKUP_UNVERIFIABLE "$backup" "Legacy backup identity cannot be verified" "The retained backup does not match an approved legacy manifest" "Inspect the backup manually" interrupted-migration
      return 1
    }
  elif ! parity_identity_matches "$backup" "$backup_identity"; then
    parity_fail RECOVERY_BACKUP_MISMATCH "$backup" "Recovery backup changed after migration" "Backup content, type, or mode differs from its recorded identity" "Restore the reviewed backup before retrying" interrupted-migration
    return 1
  fi
  python3 - "$destination" "$backup" "$target" <<'PY'
import os
import stat
import sys
destination, backup, target = sys.argv[1:]
st = os.lstat(destination)
if not stat.S_ISLNK(st.st_mode) or os.path.realpath(destination) != os.path.realpath(target):
    raise SystemExit("managed destination changed before recovery")
if os.path.dirname(destination) != os.path.dirname(backup):
    raise SystemExit("backup is not adjacent to destination")
os.replace(backup, destination)
fd = os.open(os.path.dirname(destination), os.O_RDONLY)
try:
    os.fsync(fd)
finally:
    os.close(fd)
PY
  parity_remove_last_migration "$entry"
  echo "PASS RECOVERY_RESTORED: $destination"
}

parity_remove_last_migration() {
  local expected=$1 tmp="$PARITY_MIGRATIONS.tmp.$$"
  python3 - "$PARITY_MIGRATIONS" "$tmp" "$expected" <<'PY'
import os
import sys
source_path, temp_path, expected = sys.argv[1:]
with open(source_path, "rb") as source:
    lines = source.readlines()
if not lines or lines[-1].rstrip(b"\n").decode("utf-8") != expected:
    raise SystemExit("migration log changed before recovery commit")
with open(temp_path, "wb") as target:
    target.writelines(lines[:-1])
    target.flush()
    os.fsync(target.fileno())
os.replace(temp_path, source_path)
fd = os.open(os.path.dirname(source_path), os.O_RDONLY)
try:
    os.fsync(fd)
finally:
    os.close(fd)
PY
}

doctor_args() {
  local home kind
  while IFS=$'\t' read -r home kind; do
    [ -n "$home" ] || continue
    printf '%s\n' "$home"
  done < "$HOMES_FILE"
}

discover_homes
build_records

if [ "$MODE" = recover ]; then
  if recover_latest_migration; then status=0; else status=$?; fi
  printf 'TIMING stage=recovery seconds=%s\n' "$((SECONDS - INSTALL_STARTED))"
  exit "$status"
fi

if [ "$MODE" = check ]; then
  set --
  while IFS= read -r home; do set -- "$@" --codex-home "$home"; done < <(doctor_args)
  if "$DOCTOR" "$@"; then status=0; else status=$?; fi
  printf 'TIMING stage=check seconds=%s\n' "$((SECONDS - INSTALL_STARTED))"
  exit "$status"
fi

parity_acquire_lock
parity_validate_state "$RECORDS_FILE" "$CONTRACT"
parity_recover_pending "$RECORDS_FILE" "$CONTRACT"
preflight_records
STAGE_STARTED=$SECONDS
"$RENDERER"
printf 'TIMING stage=render seconds=%s\n' "$((SECONDS - STAGE_STARTED))"
ensure_managed_parents

STAGE_STARTED=$SECONDS
while IFS=$'\t' read -r kind destination target link_target; do
  [ -n "$kind" ] || continue
  install_record "$kind" "$destination" "$target" "$link_target"
done < "$RECORDS_FILE"
printf 'TIMING stage=install seconds=%s\n' "$((SECONDS - STAGE_STARTED))"

parity_release_lock
set --
while IFS= read -r home; do set -- "$@" --codex-home "$home"; done < <(doctor_args)
STAGE_STARTED=$SECONDS
if "$DOCTOR" "$@"; then status=0; else status=$?; fi
printf 'TIMING stage=doctor seconds=%s\n' "$((SECONDS - STAGE_STARTED))"
printf 'TIMING stage=parity-total seconds=%s\n' "$((SECONDS - INSTALL_STARTED))"
exit "$status"
