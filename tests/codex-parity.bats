#!/usr/bin/env bats

SOURCE_REPO="$BATS_TEST_DIRNAME/.."

setup() {
  export TEST_ROOT="$BATS_TEST_TMPDIR/parity"
  export HOME="$TEST_ROOT/home"
  export TEST_REPO="$HOME/.claude"
  export MYSYSTEM_REPO_ROOT="$TEST_REPO"
  export MYSYSTEM_STATE_DIR="$HOME/.local/state/mysystem-codex-parity"
  unset CODEX_HOME ORCA_CODEX_HOME XDG_STATE_HOME

  mkdir -p "$TEST_REPO" "$HOME/.agents/skills"
  cp "$SOURCE_REPO/CLAUDE.md" "$TEST_REPO/CLAUDE.md"
  cp -R "$SOURCE_REPO/codex" "$SOURCE_REPO/hooks" "$SOURCE_REPO/rules" "$SOURCE_REPO/scripts" "$TEST_REPO/"
  mkdir -p "$TEST_REPO/skills"
  for skill in deep-research verify-test aside-qa ai-review-loop; do
    cp -RL "$SOURCE_REPO/skills/$skill" "$TEST_REPO/skills/$skill"
  done
  for skill in requesting-code-review verification-before-completion; do
    mkdir -p "$TEST_REPO/skills/$skill"
    printf '%s\n' '---' "name: $skill" '---' "# $skill" > "$TEST_REPO/skills/$skill/SKILL.md"
  done
  for skill in office-hours investigate autoplan qa-only design-review review ship; do
    mkdir -p "$HOME/.agents/skills/gstack/$skill" "$HOME/.agents/skills/$skill"
    printf '%s\n' '---' "name: $skill" '---' "# $skill" > "$HOME/.agents/skills/gstack/$skill/SKILL.md"
    ln -s "$HOME/.agents/skills/gstack/$skill/SKILL.md" "$HOME/.agents/skills/$skill/SKILL.md"
  done
}

managed_snapshot() {
  find "$HOME" "$TEST_REPO/AGENTS.md" \( -type l -o -type f \) 2>/dev/null \
    | LC_ALL=C sort \
    | while IFS= read -r path; do
        if [ -L "$path" ]; then
          printf 'L %s -> %s\n' "$path" "$(readlink "$path")"
        else
          printf 'F %s %s\n' "$path" "$(shasum -a 256 "$path" | awk '{print $1}')"
        fi
      done
}

install_parity() {
  "$TEST_REPO/scripts/install-codex-parity.sh"
}

@test "renderer is deterministic and --check is read-only" {
  run "$TEST_REPO/scripts/render-codex-agents.sh"
  [ "$status" -eq 0 ]
  first=$(shasum -a 256 "$TEST_REPO/codex/AGENTS.global.md" "$TEST_REPO/codex/AGENTS.project.md")

  run "$TEST_REPO/scripts/render-codex-agents.sh"
  [ "$status" -eq 0 ]
  second=$(shasum -a 256 "$TEST_REPO/codex/AGENTS.global.md" "$TEST_REPO/codex/AGENTS.project.md")
  [ "$first" = "$second" ]

  run "$TEST_REPO/scripts/render-codex-agents.sh" --check
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROJECTIONS_CURRENT"* ]]
}

@test "renderer fails closed on stale source and missing markers" {
  printf '\nsource drift\n' >> "$TEST_REPO/CLAUDE.md"
  run "$TEST_REPO/scripts/render-codex-agents.sh" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"STALE_PROJECTION"* ]]

  sed -i.bak '/mysystem:section claude-workflow:start/d' "$TEST_REPO/CLAUDE.md"
  run "$TEST_REPO/scripts/render-codex-agents.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"SECTION_MARKER_COUNT"* ]]
}

@test "renderer rejects duplicate reversed and empty marker sections" {
  start='<!-- mysystem:section claude-workflow:start -->'
  end='<!-- mysystem:section claude-workflow:end -->'

  python3 - "$TEST_REPO/CLAUDE.md" "$start" <<'PY'
import sys
path, start = sys.argv[1:]
text = open(path, encoding="utf-8").read().replace(start, start + "\n" + start, 1)
open(path, "w", encoding="utf-8").write(text)
PY
  run "$TEST_REPO/scripts/render-codex-agents.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"SECTION_MARKER_COUNT"* ]]

  cp "$SOURCE_REPO/CLAUDE.md" "$TEST_REPO/CLAUDE.md"
  pstart='<!-- mysystem:section repo-self-management:start -->'
  pend='<!-- mysystem:section repo-self-management:end -->'
  python3 - "$TEST_REPO/rules/repo-self-management.md" "$pstart" "$pend" <<'PY'
import sys
path, start, end = sys.argv[1:]
text = open(path, encoding="utf-8").read()
text = text.replace(start, "__START__", 1).replace(end, start, 1).replace("__START__", end, 1)
open(path, "w", encoding="utf-8").write(text)
PY
  run "$TEST_REPO/scripts/render-codex-agents.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"SECTION_EXTRACTION_INVALID"* ]]

  cp "$SOURCE_REPO/CLAUDE.md" "$TEST_REPO/CLAUDE.md"
  cp "$SOURCE_REPO/rules/repo-self-management.md" "$TEST_REPO/rules/repo-self-management.md"
  python3 - "$TEST_REPO/rules/repo-self-management.md" "$pstart" "$pend" <<'PY'
import sys
path, start, end = sys.argv[1:]
text = open(path, encoding="utf-8").read()
before, rest = text.split(start, 1)
_, after = rest.split(end, 1)
open(path, "w", encoding="utf-8").write(before + start + "\n\n" + end + after)
PY
  run "$TEST_REPO/scripts/render-codex-agents.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"SECTION_EXTRACTION_INVALID"* ]]
}

@test "renderer confines contract outputs to the supported codex paths" {
  jq '.projections.global.output = "../outside.md"' "$TEST_REPO/codex/parity-contract.json" \
    > "$TEST_REPO/codex/parity-contract.json.next"
  mv "$TEST_REPO/codex/parity-contract.json.next" "$TEST_REPO/codex/parity-contract.json"

  run "$TEST_REPO/scripts/render-codex-agents.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"CONTRACT_MODEL_INVALID"* ]]
  [ ! -e "$TEST_ROOT/outside.md" ]
}

@test "approved tree digest includes empty directories and symlinks" {
  mkdir -p "$TEST_ROOT/tree"
  printf '%s\n' payload > "$TEST_ROOT/tree/file"
  first=$(bash -c '. "$1"; parity_tree_digest "$2"' _ "$TEST_REPO/scripts/codex-parity-lib.sh" "$TEST_ROOT/tree")

  mkdir "$TEST_ROOT/tree/empty"
  second=$(bash -c '. "$1"; parity_tree_digest "$2"' _ "$TEST_REPO/scripts/codex-parity-lib.sh" "$TEST_ROOT/tree")
  [ "$first" != "$second" ]

  rmdir "$TEST_ROOT/tree/empty"
  ln -s "$TEST_ROOT/host-owned" "$TEST_ROOT/tree/link"
  third=$(bash -c '. "$1"; parity_tree_digest "$2"' _ "$TEST_REPO/scripts/codex-parity-lib.sh" "$TEST_ROOT/tree")
  [ "$first" != "$third" ]
}

@test "committed legacy manifests derive every production tree allowlist digest" {
  run python3 - "$TEST_REPO/codex/parity-contract.json" "$SOURCE_REPO/tests/fixtures/codex-parity/approved-tree-manifests.json" <<'PY'
import hashlib
import json
import os
import sys
with open(sys.argv[1], encoding="utf-8") as source:
    contract = json.load(source)
with open(sys.argv[2], encoding="utf-8") as source:
    fixtures = json.load(source)
for kind, fixture in fixtures.items():
    digest = hashlib.sha256()
    for entry in sorted(fixture["entries"], key=lambda item: os.fsencode(item["path"])):
        record = dict(entry)
        record["path_hex"] = os.fsencode(record.pop("path")).hex()
        digest.update(json.dumps(record, sort_keys=True, separators=(",", ":")).encode("ascii") + b"\n")
    actual = digest.hexdigest()
    assert actual == fixture["digest"], (kind, actual, fixture["digest"])
    assert actual in contract["approved_migrations"]["trees"][kind], kind
    identity = hashlib.sha256()
    for entry in sorted(fixture["entries"], key=lambda item: os.fsencode(item["path"])):
        record = {key: value for key, value in entry.items() if key != "mode"}
        record["path_hex"] = os.fsencode(record.pop("path")).hex()
        identity.update(json.dumps(record, sort_keys=True, separators=(",", ":")).encode("ascii") + b"\n")
    identity_digest = identity.hexdigest()
    assert identity_digest == fixture["identity_digest"], (kind, identity_digest, fixture["identity_digest"])
    assert identity_digest in contract["approved_migrations"]["identities"][kind], kind
PY
  [ "$status" -eq 0 ]
}

@test "renderer enforces exact global and project budget boundaries" {
  run "$TEST_REPO/scripts/render-codex-agents.sh"
  [ "$status" -eq 0 ]
  global_bytes=$(wc -c < "$TEST_REPO/codex/AGENTS.global.md" | tr -d ' ')
  project_bytes=$(wc -c < "$TEST_REPO/codex/AGENTS.project.md" | tr -d ' ')
  jq --argjson global_max "$((global_bytes + 4096))" --argjson project_max "$project_bytes" \
    '.budgets.global_max_bytes = $global_max | .budgets.global_reserve_bytes = 4096 | .budgets.project_max_bytes = $project_max' \
    "$TEST_REPO/codex/parity-contract.json" > "$TEST_REPO/codex/parity-contract.json.next"
  mv "$TEST_REPO/codex/parity-contract.json.next" "$TEST_REPO/codex/parity-contract.json"
  run "$TEST_REPO/scripts/render-codex-agents.sh" --check
  [ "$status" -eq 0 ]

  jq '.budgets.global_max_bytes -= 1' "$TEST_REPO/codex/parity-contract.json" > "$TEST_REPO/codex/parity-contract.json.next"
  mv "$TEST_REPO/codex/parity-contract.json.next" "$TEST_REPO/codex/parity-contract.json"
  run "$TEST_REPO/scripts/render-codex-agents.sh" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"GLOBAL_BUDGET_EXCEEDED"* ]]

  jq --argjson global_max "$((global_bytes + 4096))" '.budgets.global_max_bytes = $global_max | .budgets.project_max_bytes -= 1' \
    "$TEST_REPO/codex/parity-contract.json" > "$TEST_REPO/codex/parity-contract.json.next"
  mv "$TEST_REPO/codex/parity-contract.json.next" "$TEST_REPO/codex/parity-contract.json"
  run "$TEST_REPO/scripts/render-codex-agents.sh" --check
  [ "$status" -eq 1 ]
  [[ "$output" == *"PROJECT_BUDGET_EXCEEDED"* ]]
}

@test "fresh install is idempotent and installs only expected links" {
  mkdir -p "$HOME/.codex"
  printf '%s\n' 'protected config' > "$HOME/.codex/config.toml"
  printf '%s\n' 'protected auth' > "$HOME/.codex/auth.json"
  protected_before=$(shasum -a 256 "$HOME/.codex/config.toml" "$HOME/.codex/auth.json")

  run install_parity
  [ "$status" -eq 0 ]
  [ -L "$TEST_REPO/AGENTS.md" ]
  [ -L "$HOME/.codex/AGENTS.md" ]
  [ -L "$HOME/.codex/hooks" ]
  [ -L "$HOME/.codex/hooks.json" ]
  [ -L "$HOME/.agents/skills/ai-review-loop" ]
  protected_after=$(shasum -a 256 "$HOME/.codex/config.toml" "$HOME/.codex/auth.json")
  [ "$protected_before" = "$protected_after" ]
  first=$(managed_snapshot)

  run install_parity
  [ "$status" -eq 0 ]
  second=$(managed_snapshot)
  [ "$first" = "$second" ]
  [[ "$output" == *"SUMMARY profile=core"* ]]
  [[ "$output" == *"FAIL=0"* ]]
  [[ "$output" == *"TIMING stage=render"* ]]
  [[ "$output" == *"TIMING stage=parity-total"* ]]
}

@test "unknown real content blocks all link mutations and is preserved" {
  mkdir -p "$HOME/.codex"
  printf '%s\n' 'user-owned unknown content' > "$HOME/.codex/AGENTS.md"

  run install_parity
  [ "$status" -eq 1 ]
  [[ "$output" == *"MANAGED_PATH_CONFLICT"* ]]
  [ "$(cat "$HOME/.codex/AGENTS.md")" = "user-owned unknown content" ]
  [ ! -e "$TEST_REPO/AGENTS.md" ]
  [ ! -L "$TEST_REPO/AGENTS.md" ]
}

@test "approved legacy file is backed up and recover restores it" {
  mkdir -p "$HOME/.codex"
  printf '%s\n' 'approved fixture legacy' > "$HOME/.codex/AGENTS.md"
  digest=$(shasum -a 256 "$HOME/.codex/AGENTS.md" | awk '{print $1}')
  jq --arg digest "$digest" '.approved_migrations.files.default_agents += [$digest] | .approved_migrations.identities.default_agents += [$digest]' \
    "$TEST_REPO/codex/parity-contract.json" > "$TEST_REPO/codex/parity-contract.json.next"
  mv "$TEST_REPO/codex/parity-contract.json.next" "$TEST_REPO/codex/parity-contract.json"

  run install_parity
  [ "$status" -eq 0 ]
  [ -L "$HOME/.codex/AGENTS.md" ]
  backup=$(find "$HOME/.codex" -maxdepth 1 -name 'AGENTS.md.mysystem-backup.*' -print -quit)
  [ -n "$backup" ]

  run "$TEST_REPO/scripts/install-codex-parity.sh" --recover
  [ "$status" -eq 0 ]
  [ ! -L "$HOME/.codex/AGENTS.md" ]
  [ "$(cat "$HOME/.codex/AGENTS.md")" = "approved fixture legacy" ]
}

@test "pending committed transaction is deduplicated after the append crash window" {
  mkdir -p "$HOME/.codex"
  printf '%s\n' 'approved fixture legacy' > "$HOME/.codex/AGENTS.md"
  digest=$(shasum -a 256 "$HOME/.codex/AGENTS.md" | awk '{print $1}')
  jq --arg digest "$digest" '.approved_migrations.files.default_agents += [$digest] | .approved_migrations.identities.default_agents += [$digest]' \
    "$TEST_REPO/codex/parity-contract.json" > "$TEST_REPO/codex/parity-contract.json.next"
  mv "$TEST_REPO/codex/parity-contract.json.next" "$TEST_REPO/codex/parity-contract.json"
  run install_parity
  [ "$status" -eq 0 ]

  cp "$MYSYSTEM_STATE_DIR/migrations.jsonl" "$MYSYSTEM_STATE_DIR/transaction.json"
  before=$(wc -l < "$MYSYSTEM_STATE_DIR/migrations.jsonl" | tr -d ' ')
  run install_parity
  [ "$status" -eq 0 ]
  after=$(wc -l < "$MYSYSTEM_STATE_DIR/migrations.jsonl" | tr -d ' ')
  [ "$before" = "$after" ]
  [ ! -e "$MYSYSTEM_STATE_DIR/transaction.json" ]
}

@test "recovery finalizes after an atomic restore crash before log rewrite" {
  mkdir -p "$HOME/.codex"
  printf '%s\n' 'approved fixture legacy' > "$HOME/.codex/AGENTS.md"
  digest=$(shasum -a 256 "$HOME/.codex/AGENTS.md" | awk '{print $1}')
  jq --arg digest "$digest" '.approved_migrations.files.default_agents += [$digest] | .approved_migrations.identities.default_agents += [$digest]' \
    "$TEST_REPO/codex/parity-contract.json" > "$TEST_REPO/codex/parity-contract.json.next"
  mv "$TEST_REPO/codex/parity-contract.json.next" "$TEST_REPO/codex/parity-contract.json"
  run install_parity
  [ "$status" -eq 0 ]
  backup=$(jq -r '.backup' "$MYSYSTEM_STATE_DIR/migrations.jsonl")
  python3 - "$backup" "$HOME/.codex/AGENTS.md" <<'PY'
import os
import sys
os.replace(sys.argv[1], sys.argv[2])
PY

  run "$TEST_REPO/scripts/install-codex-parity.sh" --recover
  [ "$status" -eq 0 ]
  [[ "$output" == *"RECOVERY_FINALIZED"* ]]
  [ "$(cat "$HOME/.codex/AGENTS.md")" = "approved fixture legacy" ]
  [ ! -s "$MYSYSTEM_STATE_DIR/migrations.jsonl" ]
}

@test "recovery retains metadata when a missing backup has arbitrary replacement content" {
  mkdir -p "$HOME/.codex"
  printf '%s\n' 'approved fixture legacy' > "$HOME/.codex/AGENTS.md"
  digest=$(shasum -a 256 "$HOME/.codex/AGENTS.md" | awk '{print $1}')
  jq --arg digest "$digest" '.approved_migrations.files.default_agents += [$digest] | .approved_migrations.identities.default_agents += [$digest]' \
    "$TEST_REPO/codex/parity-contract.json" > "$TEST_REPO/codex/parity-contract.json.next"
  mv "$TEST_REPO/codex/parity-contract.json.next" "$TEST_REPO/codex/parity-contract.json"
  run install_parity
  [ "$status" -eq 0 ]
  backup=$(jq -r '.backup' "$MYSYSTEM_STATE_DIR/migrations.jsonl")
  rm "$backup" "$HOME/.codex/AGENTS.md"
  printf '%s\n' unrelated > "$HOME/.codex/AGENTS.md"

  run "$TEST_REPO/scripts/install-codex-parity.sh" --recover
  [ "$status" -eq 1 ]
  [[ "$output" == *"RECOVERY_CONFLICT"* ]]
  [ -s "$MYSYSTEM_STATE_DIR/migrations.jsonl" ]
  [ "$(cat "$HOME/.codex/AGENTS.md")" = unrelated ]
}

@test "recovery rejects a corrupted retained backup" {
  mkdir -p "$HOME/.codex"
  printf '%s\n' 'approved fixture legacy' > "$HOME/.codex/AGENTS.md"
  digest=$(shasum -a 256 "$HOME/.codex/AGENTS.md" | awk '{print $1}')
  jq --arg digest "$digest" '.approved_migrations.files.default_agents += [$digest] | .approved_migrations.identities.default_agents += [$digest]' \
    "$TEST_REPO/codex/parity-contract.json" > "$TEST_REPO/codex/parity-contract.json.next"
  mv "$TEST_REPO/codex/parity-contract.json.next" "$TEST_REPO/codex/parity-contract.json"
  run install_parity
  [ "$status" -eq 0 ]
  backup=$(jq -r '.backup' "$MYSYSTEM_STATE_DIR/migrations.jsonl")
  printf '%s\n' tampered > "$backup"

  run "$TEST_REPO/scripts/install-codex-parity.sh" --recover
  [ "$status" -eq 1 ]
  [[ "$output" == *"BACKUP_IDENTITY_MISMATCH"* ]]
  [ -s "$MYSYSTEM_STATE_DIR/migrations.jsonl" ]
}

@test "migration state rejects malformed earlier entries and unbound transactions" {
  mkdir -p "$MYSYSTEM_STATE_DIR"
  printf '%s\n' '{"schema_version":0}' > "$MYSYSTEM_STATE_DIR/migrations.jsonl"
  printf '%s\n' '{"schema_version":1,"destination":"x","backup":"x.mysystem-backup.y","target":"z","kind":"default_agents"}' >> "$MYSYSTEM_STATE_DIR/migrations.jsonl"
  run install_parity
  [ "$status" -eq 1 ]
  [[ "$output" == *"MIGRATION_LOG_MALFORMED"* ]]

  rm "$MYSYSTEM_STATE_DIR/migrations.jsonl"
  jq -n --arg destination "$HOME/unmanaged" --arg backup "$HOME/unmanaged.mysystem-backup.x" --arg target "$HOME/target" \
    '{schema_version:1,transaction_id:"fixture",destination:$destination,backup:$backup,target:$target,kind:"default_agents"}' \
    > "$MYSYSTEM_STATE_DIR/transaction.json"
  run install_parity
  [ "$status" -eq 1 ]
  [[ "$output" == *"TRANSACTION_UNBOUND"* ]]
  [ ! -e "$HOME/unmanaged" ]
}

@test "concurrent installers preserve a valid final state and expose only lock contention" {
  run install_parity
  [ "$status" -eq 0 ]
  pids=""
  for index in $(seq 1 10); do
    "$TEST_REPO/scripts/install-codex-parity.sh" > "$TEST_ROOT/concurrent.$index.log" 2>&1 &
    pids="$pids $!"
  done
  index=0
  for pid in $pids; do
    index=$((index + 1))
    if ! wait "$pid"; then
      grep -q 'INSTALL_LOCK_BUSY' "$TEST_ROOT/concurrent.$index.log"
    fi
  done
  run install_parity
  [ "$status" -eq 0 ]
  [[ "$output" == *"FAIL=0"* ]]
}

@test "stale and live installer locks have deterministic outcomes" {
  mkdir -p "$MYSYSTEM_STATE_DIR/install.lock"
  printf '%s\n' 99999999 > "$MYSYSTEM_STATE_DIR/install.lock/pid"
  run install_parity
  [ "$status" -eq 0 ]

  mkdir -p "$MYSYSTEM_STATE_DIR/install.lock"
  printf '%s\n' "$$" > "$MYSYSTEM_STATE_DIR/install.lock/pid"
  run install_parity
  [ "$status" -eq 1 ]
  [[ "$output" == *"INSTALL_LOCK_BUSY"* ]]
}

@test "symlinked lock and state leaves fail without touching their targets" {
  mkdir -p "$MYSYSTEM_STATE_DIR" "$TEST_ROOT/lock-victim"
  printf '%s\n' 99999999 > "$TEST_ROOT/lock-victim/pid"
  ln -s "$TEST_ROOT/lock-victim" "$MYSYSTEM_STATE_DIR/install.lock"
  run install_parity
  [ "$status" -eq 1 ]
  [[ "$output" == *"INSTALL_LOCK_STALE_UNSAFE"* ]]
  [ "$(cat "$TEST_ROOT/lock-victim/pid")" = 99999999 ]

  rm "$MYSYSTEM_STATE_DIR/install.lock"
  printf '%s\n' preserved > "$TEST_ROOT/state-victim"
  chmod 600 "$TEST_ROOT/state-victim"
  ln -s "$TEST_ROOT/state-victim" "$MYSYSTEM_STATE_DIR/transaction.json"
  run install_parity
  [ "$status" -eq 1 ]
  [[ "$output" == *"STATE_LEAF_UNSAFE"* ]]
  [ "$(cat "$TEST_ROOT/state-victim")" = preserved ]
}

@test "wrong and broken symlinks plus empty placeholders are replaced" {
  mkdir -p "$HOME/.codex" "$HOME/.agents/skills/deep-research"
  alternate_home="$HOME/codex home"
  mkdir -p "$alternate_home"
  ln -s "$TEST_ROOT/missing" "$HOME/.codex/AGENTS.md"
  ln -s "$TEST_ROOT/wrong" "$TEST_REPO/AGENTS.md"

  run "$TEST_REPO/scripts/install-codex-parity.sh" \
    --codex-home "$alternate_home" --codex-home "$alternate_home"
  [ "$status" -eq 0 ]
  [ "$(readlink "$HOME/.codex/AGENTS.md")" = "$TEST_REPO/codex/AGENTS.global.md" ]
  [ "$(readlink "$TEST_REPO/AGENTS.md")" = "codex/AGENTS.project.md" ]
  [ -L "$HOME/.agents/skills/deep-research" ]
  [ "$(readlink "$alternate_home/AGENTS.md")" = "$TEST_REPO/codex/AGENTS.global.md" ]
}

@test "unsafe and missing explicit Codex homes are rejected with usage-safe status" {
  run "$TEST_REPO/scripts/install-codex-parity.sh" --check --codex-home "$HOME"
  [ "$status" -eq 1 ]
  [[ "$output" == *"CODEX_HOME_UNSAFE"* ]]
  [[ "$output" == *"Problem="* ]]
  [[ "$output" == *"Docs=SETUP.md#codex-home-unsafe"* ]]

  run "$TEST_REPO/scripts/install-codex-parity.sh" --check --codex-home relative-home
  [ "$status" -eq 1 ]
  [[ "$output" == *"CODEX_HOME_UNSAFE"* ]]
}

@test "state and managed-parent symlinks fail without mutating their targets" {
  mkdir -p "$TEST_ROOT/state-target" "$(dirname "$MYSYSTEM_STATE_DIR")"
  chmod 755 "$TEST_ROOT/state-target"
  ln -s "$TEST_ROOT/state-target" "$MYSYSTEM_STATE_DIR"

  run install_parity
  [ "$status" -eq 1 ]
  [[ "$output" == *"STATE_DIR_UNSAFE"* ]]
  [ "$(stat -f '%Lp' "$TEST_ROOT/state-target" 2>/dev/null || stat -c '%a' "$TEST_ROOT/state-target")" = 755 ]

  rm "$MYSYSTEM_STATE_DIR"
  mkdir -p "$MYSYSTEM_STATE_DIR" "$TEST_ROOT/redirected-agents"
  mv "$HOME/.agents" "$HOME/.agents-real"
  ln -s "$TEST_ROOT/redirected-agents" "$HOME/.agents"
  run install_parity
  [ "$status" -eq 1 ]
  [[ "$output" == *"MANAGED_PARENT_UNSAFE"* ]]
  [ -z "$(find "$TEST_ROOT/redirected-agents" -mindepth 1 -print -quit)" ]
}

@test "doctor profiles distinguish structural presence from missing MCP" {
  run install_parity
  [ "$status" -eq 0 ]
  mkdir -p "$TEST_ROOT/bin"
  cp "$SOURCE_REPO/tests/fixtures/codex-parity/codex" "$TEST_ROOT/bin/codex"
  chmod +x "$TEST_ROOT/bin/codex"

  PATH="$TEST_ROOT/bin:$PATH" run "$TEST_REPO/scripts/codex-parity-doctor.sh" --require material-ui
  [ "$status" -eq 0 ]

  PATH="$TEST_ROOT/bin:$PATH" run "$TEST_REPO/scripts/codex-parity-doctor.sh" --require browser
  [ "$status" -eq 1 ]
  [[ "$output" == *"PROFILE_MCP_MISSING"* ]]

  CODEX_STUB_ASIDE=1 PATH="$TEST_ROOT/bin:$PATH" run "$TEST_REPO/scripts/codex-parity-doctor.sh" --require browser
  [ "$status" -eq 0 ]
  [[ "$output" == *"LIVE_AUTH_UNVERIFIABLE"* ]]
}

@test "doctor JSON has stable fields and missing safety tuple is a core failure" {
  run install_parity
  [ "$status" -eq 0 ]

  run "$TEST_REPO/scripts/codex-parity-doctor.sh" --json
  [ "$status" -eq 0 ]
  printf '%s' "$output" | jq -e '.summary.fail == 0 and (.summary.elapsed_seconds | type == "number") and all(.checks[]; has("status") and has("check_id") and has("problem") and has("cause") and has("fix") and has("docs"))' >/dev/null
  grep '^### ' "$SOURCE_REPO/SETUP.md" \
    | sed 's/^### //' \
    | tr '[:upper:] ' '[:lower:]-' > "$TEST_ROOT/docs-anchors"
  while IFS= read -r docs; do
    anchor=${docs#SETUP.md#}
    grep -qx "$anchor" "$TEST_ROOT/docs-anchors"
  done < <(printf '%s' "$output" | jq -r '.checks[].docs')

  chmod -x "$TEST_REPO/hooks/secret-scanner.py"
  run "$TEST_REPO/scripts/codex-parity-doctor.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"HOOK_SAFETY_SOURCE_INVALID"* ]]
  chmod +x "$TEST_REPO/hooks/secret-scanner.py"

  cp "$TEST_REPO/codex/hooks.json" "$TEST_ROOT/runtime-hooks.json"
  rm "$HOME/.codex/hooks.json"
  jq '(.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks) |= map(select(.command | contains("secret-scanner.py") | not))' \
    "$TEST_ROOT/runtime-hooks.json" > "$HOME/.codex/hooks.json"
  run "$TEST_REPO/scripts/codex-parity-doctor.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"HOOK_SAFETY_MISSING"* ]]
}

@test "contract closure rejects removed hooks and doctor preserves malformed JSON diagnostics" {
  run install_parity
  [ "$status" -eq 0 ]

  cp "$TEST_REPO/codex/parity-contract.json" "$TEST_ROOT/contract.good"
  jq '.hooks = []' "$TEST_ROOT/contract.good" > "$TEST_REPO/codex/parity-contract.json"
  run "$TEST_REPO/scripts/render-codex-agents.sh" --validate-contract
  [ "$status" -eq 1 ]
  [[ "$output" == *"CONTRACT_MODEL_INVALID"* ]]

  run "$TEST_REPO/scripts/codex-parity-doctor.sh" --json
  [ "$status" -eq 1 ]
  printf '%s' "$output" | jq -e '.summary.fail == 1 and .summary.exit_code == 1 and any(.checks[]; .check_id == "CONTRACT_INVALID")' >/dev/null

  jq '.approved_migrations.identities.default_hooks[0] = "bad"' "$TEST_ROOT/contract.good" > "$TEST_REPO/codex/parity-contract.json"
  run "$TEST_REPO/scripts/render-codex-agents.sh" --validate-contract
  [ "$status" -eq 1 ]
  [[ "$output" == *"CONTRACT_MODEL_INVALID"* ]]

  cp "$TEST_ROOT/contract.good" "$TEST_REPO/codex/parity-contract.json"
  jq '(.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks) |= map(select(.command | contains("secret-scanner.py") | not))' \
    "$TEST_REPO/codex/hooks.json" > "$TEST_REPO/codex/hooks.json.next"
  mv "$TEST_REPO/codex/hooks.json.next" "$TEST_REPO/codex/hooks.json"
  run "$TEST_REPO/scripts/render-codex-agents.sh" --validate-contract
  [ "$status" -eq 1 ]
  [[ "$output" == *"CONTRACT_HOOK_REGISTRATION_INVALID"* ]]
}

@test "doctor rejects inert hook commands and unowned gstack placeholders" {
  run install_parity
  [ "$status" -eq 0 ]

  cp "$TEST_REPO/codex/hooks.json" "$TEST_ROOT/runtime-hooks.json"
  rm "$HOME/.codex/hooks.json"
  jq '(.hooks.PreToolUse[] | select(.matcher == "Bash") | .hooks[] | select(.command | contains("secret-scanner.py")) | .command) = "true # secret-scanner.py"' \
    "$TEST_ROOT/runtime-hooks.json" > "$HOME/.codex/hooks.json"
  run "$TEST_REPO/scripts/codex-parity-doctor.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"HOOK_SAFETY_MISSING"* ]]

  rm "$HOME/.agents/skills/review/SKILL.md"
  printf '%s\n' placeholder > "$HOME/.agents/skills/review/SKILL.md"
  run "$TEST_REPO/scripts/codex-parity-doctor.sh"
  [ "$status" -eq 1 ]
  [[ "$output" == *"GSTACK_SKILL_UNOWNED"* ]]
}

@test "profile probes use the single explicitly requested Codex home" {
  alternate="$HOME/alternate-codex"
  mkdir -p "$alternate"
  touch "$alternate/.aside-present"
  run "$TEST_REPO/scripts/install-codex-parity.sh" --codex-home "$alternate"
  [ "$status" -eq 0 ]

  mkdir -p "$TEST_ROOT/bin"
  cp "$SOURCE_REPO/tests/fixtures/codex-parity/codex" "$TEST_ROOT/bin/codex"
  chmod +x "$TEST_ROOT/bin/codex"
  PATH="$TEST_ROOT/bin:$PATH" run "$TEST_REPO/scripts/codex-parity-doctor.sh" --require browser --codex-home "$alternate"
  [ "$status" -eq 0 ]
  [[ "$output" == *"LIVE_AUTH_UNVERIFIABLE"* ]]
}

@test "supported Orca browser profile uses only the declared Aside CLI fallback" {
  run install_parity
  [ "$status" -eq 0 ]
  orca="$HOME/Library/Application Support/orca/codex-runtime-home/home"
  mkdir -p "$orca" "$TEST_ROOT/bin"
  ln -s "$TEST_REPO/codex/AGENTS.global.md" "$orca/AGENTS.md"
  cp "$TEST_REPO/codex/hooks.json" "$orca/hooks.json"
  cp "$SOURCE_REPO/tests/fixtures/codex-parity/codex" "$TEST_ROOT/bin/codex"
  printf '%s\n' '#!/usr/bin/env bash' 'exit 0' > "$TEST_ROOT/bin/aside"
  chmod +x "$TEST_ROOT/bin/codex" "$TEST_ROOT/bin/aside"

  PATH="$TEST_ROOT/bin:$PATH" run "$TEST_REPO/scripts/codex-parity-doctor.sh" --require browser --codex-home "$orca"
  [ "$status" -eq 0 ]
  [[ "$output" == *"PROFILE_MCP_CLI_FALLBACK"* ]]
  [[ "$output" != *"PROFILE_MCP_MISSING"* ]]
}

@test "doctor warns instead of certifying an unobserved Codex version" {
  run install_parity
  [ "$status" -eq 0 ]
  mkdir -p "$TEST_ROOT/bin"
  cp "$SOURCE_REPO/tests/fixtures/codex-parity/codex" "$TEST_ROOT/bin/codex"
  chmod +x "$TEST_ROOT/bin/codex"
  CODEX_STUB_VERSION=9.9.9 PATH="$TEST_ROOT/bin:$PATH" run "$TEST_REPO/scripts/codex-parity-doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"CODEX_VERSION_UNTESTED"* ]]
}

@test "doctor consumes the observed Orca version contract" {
  run install_parity
  [ "$status" -eq 0 ]
  plist="$HOME/Applications/Orca.app/Contents/Info.plist"
  mkdir -p "$(dirname "$plist")"
  python3 - "$plist" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "wb") as target:
    plistlib.dump({"CFBundleShortVersionString": "1.4.128"}, target)
PY

  run "$TEST_REPO/scripts/codex-parity-doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ORCA_VERSION_OBSERVED"* ]]

  python3 - "$plist" <<'PY'
import plistlib
import sys

with open(sys.argv[1], "wb") as target:
    plistlib.dump({"CFBundleShortVersionString": "9.9.9"}, target)
PY
  run "$TEST_REPO/scripts/codex-parity-doctor.sh"
  [ "$status" -eq 0 ]
  [[ "$output" == *"ORCA_VERSION_UNTESTED"* ]]
}

@test "global projection excludes MySystem-only rules and project projection contains them" {
  run "$TEST_REPO/scripts/render-codex-agents.sh"
  [ "$status" -eq 0 ]
  ! grep -q 'Repo Self-Management Rules' "$TEST_REPO/codex/AGENTS.global.md"
  grep -q 'Repo Self-Management Rules' "$TEST_REPO/codex/AGENTS.project.md"
}
