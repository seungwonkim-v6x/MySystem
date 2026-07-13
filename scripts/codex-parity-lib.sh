#!/usr/bin/env bash
# Shared portable helpers for the MySystem Codex parity installer and doctor.

parity_fail() {
  local id=$1 subject=$2 problem=$3 cause=$4 fix=$5 anchor=$6
  printf 'FAIL %s subject=%s Problem=%s Cause=%s Fix=%s Docs=SETUP.md#%s\n' \
    "$id" "$subject" "$problem" "$cause" "$fix" "$anchor" >&2
}

parity_hash_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    sha256sum "$1" | awk '{print $1}'
  fi
}

parity_file_mode() {
  # GNU stat first: BSD stat -f exits 0 with garbage under GNU coreutils,
  # so the BSD form must be the fallback, never the probe.
  stat -c '%a' "$1" 2>/dev/null || stat -f '%Lp' "$1"
}

parity_tree_digest() {
  local directory=$1
  python3 - "$directory" <<'PY'
import hashlib
import json
import os
import stat
import sys

root = os.path.abspath(sys.argv[1])
records = []
for current, dirs, files in os.walk(root, topdown=True, followlinks=False):
    names = dirs + files
    dirs[:] = [name for name in dirs if not os.path.islink(os.path.join(current, name))]
    for name in names:
        path = os.path.join(current, name)
        st = os.lstat(path)
        rel = os.path.relpath(path, root)
        record = {
            "path_hex": os.fsencode(rel).hex(),
            "mode": stat.S_IMODE(st.st_mode),
        }
        if stat.S_ISREG(st.st_mode):
            digest = hashlib.sha256()
            with open(path, "rb") as source:
                for chunk in iter(lambda: source.read(1024 * 1024), b""):
                    digest.update(chunk)
            record.update(type="file", sha256=digest.hexdigest())
        elif stat.S_ISDIR(st.st_mode):
            record.update(type="directory")
        elif stat.S_ISLNK(st.st_mode):
            record.update(type="symlink", target_hex=os.fsencode(os.readlink(path)).hex())
        else:
            raise SystemExit(f"unsupported tree entry: {rel}")
        records.append(record)

digest = hashlib.sha256()
for record in sorted(records, key=lambda item: bytes.fromhex(item["path_hex"])):
    digest.update(json.dumps(record, sort_keys=True, separators=(",", ":")).encode("ascii"))
    digest.update(b"\n")
print(digest.hexdigest())
PY
}

parity_realpath() {
  if command -v realpath >/dev/null 2>&1; then
    realpath "$1"
    return
  fi
  python3 - "$1" <<'PY'
import os
import sys
print(os.path.realpath(sys.argv[1]))
PY
}

parity_managed_path() {
  local contract=$1 key=$2 repo_root=$3 raw
  raw=$(jq -er --arg key "$key" '.managed_paths[$key] | select(type == "string" and length > 0)' "$contract") || return 1
  case "$raw" in
    *$'\t'*|*$'\n'*|*$'\r'*|/*|*..*) return 1 ;;
    '$HOME/'*) printf '%s/%s\n' "$HOME" "${raw#\$HOME/}" ;;
    *) printf '%s/%s\n' "$repo_root" "$raw" ;;
  esac
}

parity_link_matches() {
  local destination=$1 target=$2
  [ -L "$destination" ] || return 1
  [ "$(parity_realpath "$destination")" = "$(parity_realpath "$target")" ]
}

parity_path_state() {
  local destination=$1 target=$2
  if [ -L "$destination" ]; then
    if parity_link_matches "$destination" "$target"; then
      printf '%s\n' correct-link
    else
      printf '%s\n' wrong-link
    fi
  elif [ -d "$destination" ]; then
    if [ -z "$(find "$destination" -mindepth 1 -maxdepth 1 -print -quit 2>/dev/null)" ]; then
      printf '%s\n' empty-dir
    else
      printf '%s\n' real-dir
    fi
  elif [ -f "$destination" ]; then
    printf '%s\n' real-file
  elif [ -e "$destination" ]; then
    printf '%s\n' special
  else
    printf '%s\n' absent
  fi
}

parity_validate_path_chain() {
  local path=$1 allow_missing=${2:-0}
  python3 - "$path" "$HOME" "$allow_missing" <<'PY'
import os
import stat
import sys

path, user_home, allow_missing = sys.argv[1:]
if not path or not os.path.isabs(path) or any(c in path for c in "\n\r\t"):
    raise SystemExit("path must be absolute and contain no control characters")
path = os.path.normpath(path)
user_home = os.path.normpath(os.path.abspath(user_home))
try:
    if os.path.commonpath([path, user_home]) != user_home:
        raise SystemExit("managed paths must remain inside the user home")
except ValueError:
    raise SystemExit("managed path is outside the user home")

probe = path
if not os.path.lexists(probe):
    if allow_missing != "1":
        raise SystemExit("managed path does not exist")
    while not os.path.lexists(probe):
        parent = os.path.dirname(probe)
        if parent == probe:
            raise SystemExit("managed path has no existing parent")
        probe = parent

relative = os.path.relpath(probe, user_home)
parts = [] if relative == "." else relative.split(os.sep)
current = user_home
for part in [None] + parts:
    if part is not None:
        current = os.path.join(current, part)
    st = os.lstat(current)
    if stat.S_ISLNK(st.st_mode) or not stat.S_ISDIR(st.st_mode):
        raise SystemExit("symlinked or non-directory path component")
    if st.st_uid != os.getuid():
        raise SystemExit("managed path component is not user-owned")
    if st.st_mode & (stat.S_IWGRP | stat.S_IWOTH):
        raise SystemExit("managed path component is group/world-writable")
    if not os.access(current, os.X_OK):
        raise SystemExit("managed path component is not searchable")
PY
}

parity_validate_home() {
  local home=$1 repo_root=$2 allow_missing=${3:-0}
  parity_validate_path_chain "$home" "$allow_missing" || return 1
  python3 - "$home" "$HOME" "$repo_root" <<'PY'
import os
import sys

path, user_home, repo_root = map(os.path.normpath, sys.argv[1:])
protected = {"/", user_home, repo_root, os.path.join(user_home, ".claude")}
if path in protected:
    raise SystemExit("Codex home is a protected path")
try:
    if os.path.commonpath([path, repo_root]) == repo_root:
        raise SystemExit("Codex home cannot be inside the MySystem repository")
except ValueError:
    pass
PY
}

parity_atomic_link() {
  local target=$1 destination=$2 expected_state=${3:-absent} expected_link=${4:-}
  PARITY_LINK_COUNTER=$((PARITY_LINK_COUNTER + 1))
  python3 - "$target" "$destination" "$expected_state" "$expected_link" "$$.$PARITY_LINK_COUNTER" <<'PY'
import os
import stat
import sys

target, destination, expected_state, expected_link, suffix = sys.argv[1:]
parent = os.path.dirname(destination)
if expected_state == "absent":
    if os.path.lexists(destination):
        raise SystemExit("destination changed before link creation")
    os.symlink(target, destination)
else:
    before = os.lstat(destination)
    if not stat.S_ISLNK(before.st_mode) or os.readlink(destination) != expected_link:
        raise SystemExit("destination symlink changed before replacement")
    temp = os.path.join(parent, f".mysystem-link.{suffix}")
    if os.path.lexists(temp):
        os.unlink(temp)
    os.symlink(target, temp)
    current = os.lstat(destination)
    if (current.st_dev, current.st_ino) != (before.st_dev, before.st_ino) or os.readlink(destination) != expected_link:
        os.unlink(temp)
        raise SystemExit("destination symlink changed during replacement")
    os.replace(temp, destination)
fd = os.open(parent, os.O_RDONLY)
try:
    os.fsync(fd)
finally:
    os.close(fd)
PY
}

parity_fsync_parent() {
  python3 - "$1" <<'PY'
import os
import sys
fd = os.open(os.path.dirname(sys.argv[1]), os.O_RDONLY)
try:
    os.fsync(fd)
finally:
    os.close(fd)
PY
}

parity_remove_durable() {
  local path=$1
  [ -e "$path" ] || [ -L "$path" ] || return 0
  rm -f "$path"
  parity_fsync_parent "$path"
}

parity_approved_file() {
  local contract=$1 kind=$2 path=$3 digest
  digest=$(parity_hash_file "$path")
  jq -e --arg kind "$kind" --arg digest "$digest" \
    '.approved_migrations.files[$kind] // [] | index($digest) != null' \
    "$contract" >/dev/null
}

parity_approved_tree() {
  local contract=$1 kind=$2 path=$3 digest
  digest=$(parity_tree_digest "$path")
  jq -e --arg kind "$kind" --arg digest "$digest" \
    '.approved_migrations.trees[$kind] // [] | index($digest) != null' \
    "$contract" >/dev/null
}

parity_content_identity() {
  python3 - "$1" <<'PY'
import hashlib
import json
import os
import stat
import sys

path = os.path.abspath(sys.argv[1])
root_st = os.lstat(path)
if stat.S_ISREG(root_st.st_mode):
    digest = hashlib.sha256()
    with open(path, "rb") as source:
        for chunk in iter(lambda: source.read(1024 * 1024), b""):
            digest.update(chunk)
    print(json.dumps({"type": "file", "digest": digest.hexdigest()}, separators=(",", ":")))
    raise SystemExit(0)
if not stat.S_ISDIR(root_st.st_mode):
    raise SystemExit("identity root must be a regular file or directory")

records = []
for current, dirs, files in os.walk(path, topdown=True, followlinks=False):
    names = dirs + files
    dirs[:] = [name for name in dirs if not os.path.islink(os.path.join(current, name))]
    for name in names:
        entry = os.path.join(current, name)
        st = os.lstat(entry)
        record = {"path_hex": os.fsencode(os.path.relpath(entry, path)).hex()}
        if stat.S_ISREG(st.st_mode):
            digest = hashlib.sha256()
            with open(entry, "rb") as source:
                for chunk in iter(lambda: source.read(1024 * 1024), b""):
                    digest.update(chunk)
            record.update(type="file", sha256=digest.hexdigest())
        elif stat.S_ISDIR(st.st_mode):
            record.update(type="directory")
        elif stat.S_ISLNK(st.st_mode):
            record.update(type="symlink", target_hex=os.fsencode(os.readlink(entry)).hex())
        else:
            raise SystemExit("identity tree contains an unsupported special entry")
        records.append(record)

digest = hashlib.sha256()
for record in sorted(records, key=lambda item: bytes.fromhex(item["path_hex"])):
    digest.update(json.dumps(record, sort_keys=True, separators=(",", ":")).encode("ascii"))
    digest.update(b"\n")
print(json.dumps({"type": "tree", "digest": digest.hexdigest()}, separators=(",", ":")))
PY
}

parity_identity_matches() {
  local path=$1 expected=$2 actual
  actual=$(parity_content_identity "$path") || return 1
  jq -ne --argjson actual "$actual" --argjson expected "$expected" '$actual == $expected' >/dev/null
}

parity_approved_identity() {
  local contract=$1 kind=$2 path=$3 identity digest
  identity=$(parity_content_identity "$path") || return 1
  digest=$(printf '%s' "$identity" | jq -r '.digest')
  jq -e --arg kind "$kind" --arg digest "$digest" \
    '.approved_migrations.identities[$kind] // [] | index($digest) != null' \
    "$contract" >/dev/null || return 1
  printf '%s\n' "$identity"
}

parity_validate_state_file() {
  local path=$1
  python3 - "$path" <<'PY'
import os
import stat
import sys

path = sys.argv[1]
if not os.path.lexists(path):
    raise SystemExit(0)
st = os.lstat(path)
if not stat.S_ISREG(st.st_mode):
    raise SystemExit("state leaf is not a regular file")
if st.st_uid != os.getuid() or st.st_mode & (stat.S_IWGRP | stat.S_IWOTH):
    raise SystemExit("state leaf ownership or permissions are unsafe")
PY
}

parity_state_dir_init() {
  PARITY_STATE_DIR=${MYSYSTEM_STATE_DIR:-${XDG_STATE_HOME:-$HOME/.local/state}/mysystem-codex-parity}
  PARITY_LOCK_DIR="$PARITY_STATE_DIR/install.lock"
  PARITY_TRANSACTION="$PARITY_STATE_DIR/transaction.json"
  PARITY_MIGRATIONS="$PARITY_STATE_DIR/migrations.jsonl"
  if ! parity_validate_home "$PARITY_STATE_DIR" "$MYSYSTEM_REPO_ROOT" 1 2>/dev/null; then
    parity_fail STATE_DIR_UNSAFE "$PARITY_STATE_DIR" "Parity state path is unsafe" "A path component is linked, unowned, or group/world-writable" "Move the state path under a private user-owned directory" interrupted-migration
    return 1
  fi
  if [ ! -d "$PARITY_STATE_DIR" ]; then
    (umask 077; mkdir -p "$PARITY_STATE_DIR")
  fi
  if ! parity_validate_home "$PARITY_STATE_DIR" "$MYSYSTEM_REPO_ROOT" 0 2>/dev/null; then
    parity_fail STATE_DIR_UNSAFE "$PARITY_STATE_DIR" "Parity state path is unsafe after creation" "Secure directory creation or ownership validation failed" "Inspect the state path, then rerun setup" interrupted-migration
    return 1
  fi
  if ! parity_validate_state_file "$PARITY_TRANSACTION" 2>/dev/null || ! parity_validate_state_file "$PARITY_MIGRATIONS" 2>/dev/null; then
    parity_fail STATE_LEAF_UNSAFE "$PARITY_STATE_DIR" "Parity state contains an unsafe leaf" "A transaction or migration leaf is linked, unowned, writable by others, or non-regular" "Move the unsafe leaf aside and inspect it before retrying" interrupted-migration
    return 1
  fi
}

parity_acquire_lock() {
  local result status=0
  parity_state_dir_init
  result=$(python3 - "$PARITY_STATE_DIR" "$$" <<'PY'
import errno
import os
import stat
import sys

state_dir, current_pid = sys.argv[1], sys.argv[2]
nofollow = getattr(os, "O_NOFOLLOW", 0)
directory = getattr(os, "O_DIRECTORY", 0)
parent_fd = os.open(state_dir, os.O_RDONLY | directory | nofollow)
lock_fd = None
try:
    try:
        os.mkdir("install.lock", 0o700, dir_fd=parent_fd)
        os.fsync(parent_fd)
    except FileExistsError:
        st = os.stat("install.lock", dir_fd=parent_fd, follow_symlinks=False)
        if not stat.S_ISDIR(st.st_mode) or st.st_uid != os.getuid() or st.st_mode & (stat.S_IWGRP | stat.S_IWOTH):
            raise RuntimeError("lock leaf is linked, unowned, or writable by others")
        lock_fd = os.open("install.lock", os.O_RDONLY | directory | nofollow, dir_fd=parent_fd)
        names = os.listdir(lock_fd)
        if any(name != "pid" for name in names):
            raise RuntimeError("lock directory contains unexpected state")
        owner = None
        if "pid" in names:
            pid_fd = os.open("pid", os.O_RDONLY | nofollow, dir_fd=lock_fd)
            try:
                pid_st = os.fstat(pid_fd)
                if not stat.S_ISREG(pid_st.st_mode) or pid_st.st_uid != os.getuid():
                    raise RuntimeError("lock pid leaf is unsafe")
                raw = os.read(pid_fd, 64).decode("ascii", "strict").strip()
                if not raw.isdigit():
                    raise RuntimeError("lock pid is malformed")
                owner = int(raw)
            finally:
                os.close(pid_fd)
        if owner is not None:
            try:
                os.kill(owner, 0)
            except ProcessLookupError:
                pass
            except PermissionError:
                print(owner)
                raise SystemExit(2)
            else:
                print(owner)
                raise SystemExit(2)
            os.unlink("pid", dir_fd=lock_fd)
            os.fsync(lock_fd)
        os.close(lock_fd)
        lock_fd = None
        os.rmdir("install.lock", dir_fd=parent_fd)
        os.fsync(parent_fd)
        os.mkdir("install.lock", 0o700, dir_fd=parent_fd)
        os.fsync(parent_fd)

    lock_fd = os.open("install.lock", os.O_RDONLY | directory | nofollow, dir_fd=parent_fd)
    pid_fd = os.open("pid", os.O_WRONLY | os.O_CREAT | os.O_EXCL | nofollow, 0o600, dir_fd=lock_fd)
    try:
        os.write(pid_fd, (current_pid + "\n").encode("ascii"))
        os.fsync(pid_fd)
    finally:
        os.close(pid_fd)
    os.fsync(lock_fd)
except SystemExit:
    raise
except Exception as error:
    print(error, file=sys.stderr)
    raise SystemExit(3)
finally:
    if lock_fd is not None:
        os.close(lock_fd)
    os.close(parent_fd)
PY
) || status=$?
  case "$status" in
    0) ;;
    2)
      parity_fail INSTALL_LOCK_BUSY "$PARITY_LOCK_DIR" "Another parity install is active" "Process $result owns the install lock" "Wait for that process to finish, then retry" interrupted-migration
      return 1
      ;;
    *)
      parity_fail INSTALL_LOCK_STALE_UNSAFE "$PARITY_LOCK_DIR" "The install lock is unsafe" "The lock leaf is linked, malformed, unowned, or contains unexpected state" "Inspect the lock directory before retrying" interrupted-migration
      return 1
      ;;
  esac
  PARITY_LOCK_HELD=1
}

parity_release_lock() {
  if [ "${PARITY_LOCK_HELD:-0}" = 1 ]; then
    python3 - "$PARITY_STATE_DIR" "$$" <<'PY' 2>/dev/null || true
import os
import stat
import sys

state_dir, current_pid = sys.argv[1], sys.argv[2]
nofollow = getattr(os, "O_NOFOLLOW", 0)
directory = getattr(os, "O_DIRECTORY", 0)
parent_fd = os.open(state_dir, os.O_RDONLY | directory | nofollow)
try:
    st = os.stat("install.lock", dir_fd=parent_fd, follow_symlinks=False)
    if not stat.S_ISDIR(st.st_mode):
        raise SystemExit(1)
    lock_fd = os.open("install.lock", os.O_RDONLY | directory | nofollow, dir_fd=parent_fd)
    try:
        pid_fd = os.open("pid", os.O_RDONLY | nofollow, dir_fd=lock_fd)
        try:
            if os.read(pid_fd, 64).decode("ascii", "strict").strip() != current_pid:
                raise SystemExit(1)
        finally:
            os.close(pid_fd)
        os.unlink("pid", dir_fd=lock_fd)
        os.fsync(lock_fd)
    finally:
        os.close(lock_fd)
    os.rmdir("install.lock", dir_fd=parent_fd)
    os.fsync(parent_fd)
finally:
    os.close(parent_fd)
PY
    PARITY_LOCK_HELD=0
  fi
}

parity_write_transaction() {
  local destination=$1 backup=$2 target=$3 kind=$4 tmp
  PARITY_TRANSACTION_ID="$(date -u +%Y%m%dT%H%M%S).$$.$PARITY_LINK_COUNTER"
  PARITY_BACKUP_IDENTITY=$(parity_content_identity "$destination") || {
    parity_fail MIGRATION_IDENTITY_INVALID "$destination" "Approved content identity could not be recorded" "The destination changed type before the transaction was written" "Inspect the destination and retry only after it is stable" managed-links
    return 1
  }
  tmp="$PARITY_TRANSACTION.tmp.$$"
  jq -n \
    --arg destination "$destination" \
    --arg backup "$backup" \
    --arg target "$target" \
    --arg kind "$kind" \
    --arg transaction_id "$PARITY_TRANSACTION_ID" \
    --argjson backup_identity "$PARITY_BACKUP_IDENTITY" \
    '{schema_version:1,transaction_id:$transaction_id,destination:$destination,backup:$backup,target:$target,kind:$kind,backup_identity:$backup_identity}' \
    > "$tmp"
  chmod 600 "$tmp"
  python3 - "$tmp" "$PARITY_TRANSACTION" <<'PY'
import os
import sys
with open(sys.argv[1], "rb") as source:
    os.fsync(source.fileno())
os.replace(sys.argv[1], sys.argv[2])
fd = os.open(os.path.dirname(sys.argv[2]), os.O_RDONLY)
try:
    os.fsync(fd)
finally:
    os.close(fd)
PY
}

parity_record_migration() {
  local destination=$1 backup=$2 target=$3 kind=$4 transaction_id=${5:-} backup_identity=${6:-} record
  if [ -z "$backup_identity" ]; then
    backup_identity=$(parity_approved_identity "$CONTRACT" "$kind" "$backup") || return 1
  fi
  if [ -f "$PARITY_MIGRATIONS" ] && jq -s -e \
    --arg destination "$destination" --arg backup "$backup" --arg target "$target" --arg kind "$kind" --arg transaction_id "$transaction_id" \
    'any(.[]; (($transaction_id != "" and .transaction_id? == $transaction_id) or (.destination == $destination and .backup == $backup and .target == $target and .kind == $kind)))' \
    "$PARITY_MIGRATIONS" >/dev/null 2>&1; then
    return 0
  fi
  record=$(jq -nc \
    --arg destination "$destination" \
    --arg backup "$backup" \
    --arg target "$target" \
    --arg kind "$kind" \
    --arg transaction_id "$transaction_id" \
    --argjson backup_identity "$backup_identity" \
    '{schema_version:1,destination:$destination,backup:$backup,target:$target,kind:$kind,backup_identity:$backup_identity} + (if $transaction_id == "" then {} else {transaction_id:$transaction_id} end)')
  python3 - "$PARITY_MIGRATIONS" "$record" <<'PY'
import os
import sys
path, record = sys.argv[1:]
flags = os.O_WRONLY | os.O_APPEND | os.O_CREAT | getattr(os, "O_NOFOLLOW", 0)
fd = os.open(path, flags, 0o600)
with os.fdopen(fd, "ab") as target:
    target.write(record.encode("utf-8") + b"\n")
    target.flush()
    os.fsync(target.fileno())
fd = os.open(os.path.dirname(path), os.O_RDONLY)
try:
    os.fsync(fd)
finally:
    os.close(fd)
PY
  chmod 600 "$PARITY_MIGRATIONS"
}

parity_record_binding_valid() {
  local records=$1 destination=$2 target=$3 kind=$4 backup=$5
  awk -F '\t' -v kind="$kind" -v destination="$destination" -v target="$target" \
    '$1 == kind && $2 == destination && $3 == target { found=1 } END { exit !found }' "$records" || return 1
  python3 - "$destination" "$backup" <<'PY'
import os
import sys
destination, backup = map(os.path.normpath, sys.argv[1:])
if os.path.dirname(destination) != os.path.dirname(backup):
    raise SystemExit(1)
if not os.path.basename(backup).startswith(os.path.basename(destination) + ".mysystem-backup."):
    raise SystemExit(1)
PY
}

parity_validate_state() {
  local records=$1 contract=$2 destination backup target kind identity_type identity_mode identity_digest identity
  [ -f "$PARITY_MIGRATIONS" ] || return 0
  jq -s -e 'all(.[];
    .schema_version == 1 and
    (.destination | type == "string") and
    (.backup | type == "string") and
    (.target | type == "string") and
    (.kind | type == "string") and
    ((.transaction_id? // "") | type == "string") and
    ((.backup_identity? == null) or
      ((.backup_identity.type == "file" or .backup_identity.type == "tree") and
       (.backup_identity.digest | type == "string" and test("^[0-9a-f]{64}$")))))' "$PARITY_MIGRATIONS" >/dev/null 2>&1 || {
      parity_fail MIGRATION_LOG_MALFORMED "$PARITY_MIGRATIONS" "Migration history is malformed" "At least one entry violates the state schema" "Restore the state file from backup or inspect it manually" interrupted-migration
      return 1
    }
  while IFS=$'\x1f' read -r destination backup target kind identity_type identity_digest; do
    parity_record_binding_valid "$records" "$destination" "$target" "$kind" "$backup" || {
      parity_fail MIGRATION_LOG_UNBOUND "$destination" "Migration history references an unmanaged path" "The recorded target or adjacent backup does not match the current write set" "Inspect the state file; do not run recovery until it is corrected" interrupted-migration
      return 1
    }
    if [ -e "$backup" ] || [ -L "$backup" ]; then
      if [ -n "$identity_type" ]; then
        identity=$(jq -nc --arg type "$identity_type" --arg digest "$identity_digest" '{type:$type,digest:$digest}')
        parity_identity_matches "$backup" "$identity" || {
          parity_fail BACKUP_IDENTITY_MISMATCH "$backup" "Retained backup no longer matches its recorded identity" "Backup content, type, or mode changed after migration" "Restore the reviewed backup before retrying" interrupted-migration
          return 1
        }
      else
        parity_approved_identity "$contract" "$kind" "$backup" >/dev/null || {
          parity_fail BACKUP_IDENTITY_UNVERIFIABLE "$backup" "Legacy migration backup identity cannot be verified" "The pre-identity backup no longer matches an approved legacy manifest" "Inspect the backup manually before retrying" interrupted-migration
          return 1
        }
      fi
      chmod -R go-rwx "$backup" 2>/dev/null || {
        parity_fail BACKUP_PERMISSIONS_UNSAFE "$backup" "Backup permissions could not be restricted" "The retained migration backup is not safely writable" "Correct ownership and permissions, then retry" interrupted-migration
        return 1
      }
    fi
  done < <(jq -r '[.destination,.backup,.target,.kind,(.backup_identity.type // ""),(.backup_identity.digest // "")] | join("\u001f")' "$PARITY_MIGRATIONS")
}

parity_recover_pending() {
  local records=$1 contract=$2 destination backup target kind state transaction_id backup_identity
  [ -f "$PARITY_TRANSACTION" ] || return 0
  jq -e '.schema_version == 1 and (.destination|type=="string") and (.backup|type=="string") and (.target|type=="string") and (.kind|type=="string") and ((.transaction_id? // "")|type=="string") and ((.backup_identity? == null) or ((.backup_identity.type == "file" or .backup_identity.type == "tree") and (.backup_identity.digest|type=="string" and test("^[0-9a-f]{64}$"))))' \
    "$PARITY_TRANSACTION" >/dev/null || {
      parity_fail TRANSACTION_MALFORMED "$PARITY_TRANSACTION" "Pending transaction is malformed" "The durable transaction record violates its schema" "Inspect the state record before retrying" interrupted-migration
      return 1
    }
  destination=$(jq -r '.destination' "$PARITY_TRANSACTION")
  backup=$(jq -r '.backup' "$PARITY_TRANSACTION")
  target=$(jq -r '.target' "$PARITY_TRANSACTION")
  kind=$(jq -r '.kind' "$PARITY_TRANSACTION")
  transaction_id=$(jq -r '.transaction_id // empty' "$PARITY_TRANSACTION")
  backup_identity=$(jq -c '.backup_identity // empty' "$PARITY_TRANSACTION")
  parity_record_binding_valid "$records" "$destination" "$target" "$kind" "$backup" || {
    parity_fail TRANSACTION_UNBOUND "$destination" "Pending transaction references an unmanaged path" "The destination, target, kind, or backup is outside the current write set" "Inspect the transaction record before retrying" interrupted-migration
    return 1
  }
  state=$(parity_path_state "$destination" "$target")

  if [ -e "$backup" ] || [ -L "$backup" ]; then
    if [ -z "$backup_identity" ]; then
      backup_identity=$(parity_approved_identity "$contract" "$kind" "$backup") || {
        parity_fail TRANSACTION_BACKUP_UNVERIFIABLE "$backup" "Pending backup identity cannot be verified" "The backup does not match its recorded or approved legacy identity" "Inspect the retained backup manually" interrupted-migration
        return 1
      }
    elif ! parity_identity_matches "$backup" "$backup_identity"; then
      parity_fail TRANSACTION_BACKUP_MISMATCH "$backup" "Pending backup changed after transaction creation" "Backup content, type, or mode differs from the durable record" "Inspect the retained backup manually" interrupted-migration
      return 1
    fi
    case "$state" in
      absent)
        python3 - "$backup" "$destination" <<'PY'
import os
import sys
os.replace(sys.argv[1], sys.argv[2])
fd = os.open(os.path.dirname(sys.argv[2]), os.O_RDONLY)
try:
    os.fsync(fd)
finally:
    os.close(fd)
PY
        parity_remove_durable "$PARITY_TRANSACTION"
        echo "WARN TRANSACTION_RESTORED: restored $destination from $backup" >&2
        return 0
        ;;
      correct-link)
        parity_record_migration "$destination" "$backup" "$target" "$kind" "$transaction_id" "$backup_identity"
        parity_remove_durable "$PARITY_TRANSACTION"
        echo "WARN TRANSACTION_COMPLETED: retained backup $backup" >&2
        return 0
        ;;
      *)
        parity_fail TRANSACTION_CONFLICT "$destination" "Pending transaction cannot be resumed" "The managed destination changed after the transaction was recorded" "Inspect the destination and retained backup manually" interrupted-migration
        return 1
        ;;
    esac
  fi

  if [ -n "$backup_identity" ] && parity_identity_matches "$destination" "$backup_identity"; then
    parity_remove_durable "$PARITY_TRANSACTION"
    echo "WARN TRANSACTION_CLEARED: no migration move occurred for $destination" >&2
    return 0
  fi
  parity_fail TRANSACTION_LOST "$destination" "Pending migration lost both path states" "Neither destination nor retained backup exists" "Restore from an external backup before continuing" interrupted-migration
  return 1
}

PARITY_LINK_COUNTER=0
PARITY_LOCK_HELD=0
PARITY_TRANSACTION_ID=
PARITY_BACKUP_IDENTITY=
