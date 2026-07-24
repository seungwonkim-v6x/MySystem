#!/usr/bin/env bats
# Contract tests for scripts/apply-model-overrides.sh (v0.51.0).
# Hermetic: the wrapper generator runs against a sandbox repo via
# MYSYSTEM_REPO_ROOT — no dependence on the operator's live install.

CHECKOUT="${BATS_TEST_DIRNAME}/.."
SCRIPT="$CHECKOUT/scripts/apply-model-overrides.sh"

overrides_table() {
  awk '/^MODEL_OVERRIDES=\(/{f=1;next} f&&/^\)/{exit} f{gsub(/[ "]/,"");print}' "$SCRIPT"
}

setup() {
  SANDBOX=$(mktemp -d "${BATS_TMPDIR}/model-overrides.XXXXXX")
  mkdir -p "$SANDBOX/repo/skills" "$SANDBOX/external/gstack-ship" \
           "$SANDBOX/external/sparse-rcr"
  # Fake gstack-style install: real dir + SKILL.md symlink into a checkout.
  cat > "$SANDBOX/external/gstack-ship/SKILL.md" <<'EOF'
---
name: ship
version: 1.0.0
description: fake ship skill
model: haiku
---
# fake body
EOF
  mkdir -p "$SANDBOX/repo/skills/ship"
  ln -s "$SANDBOX/external/gstack-ship/SKILL.md" "$SANDBOX/repo/skills/ship/SKILL.md"
  # Fake sparse-style install: dir symlink into a checkout.
  cat > "$SANDBOX/external/sparse-rcr/SKILL.md" <<'EOF'
---
name: requesting-code-review
description: fake rcr skill
---
# fake body
EOF
  ln -s "$SANDBOX/external/sparse-rcr" "$SANDBOX/repo/skills/requesting-code-review"
  # "review" is deliberately absent — exercises the skip path.
}

teardown() {
  rm -rf "$SANDBOX"
}

run_overrides() {
  MYSYSTEM_REPO_ROOT="$SANDBOX/repo" run bash "$SCRIPT"
}

@test "override table declares ship, review, requesting-code-review → opus" {
  run overrides_table
  [ "$status" -eq 0 ]
  count=0
  for want in "ship|opus" "review|opus" "requesting-code-review|opus"; do
    [[ "$output" == *"$want"* ]] || { echo "missing entry: $want"; false; }
    count=$((count + 1))
  done
  [ "$count" -eq 3 ]
}

@test "file-symlink skill gets a wrapper: pinned model, preserved frontmatter, source marker, model-free source untouched" {
  run_overrides
  [ "$status" -eq 0 ]
  w="$SANDBOX/repo/skills/ship/SKILL.md"
  [ -f "$w" ] && [ ! -L "$w" ]
  grep -q '^model: opus$' "$w"
  grep -q '^name: ship$' "$w"
  grep -q '^description: fake ship skill$' "$w"
  # Source's own model: line is dropped from the wrapper, exactly one pin remains.
  [ "$(grep -c '^model:' "$w")" -eq 1 ]
  src=$(sed -n 's/^<!-- mysystem-model-override source=\(.*\) -->$/\1/p' "$w")
  expected="$(cd "$SANDBOX/external/gstack-ship" && pwd -P)/SKILL.md"
  [ "$src" = "$expected" ]
  # Deferral body names the source path; the source file itself is unmodified.
  grep -qF "$src" <(sed -n '/^<!--/,$p' "$w")
  grep -q '^model: haiku$' "$SANDBOX/external/gstack-ship/SKILL.md"
}

@test "sparse dir-symlink converts to a real dir holding the wrapper" {
  run_overrides
  [ "$status" -eq 0 ]
  d="$SANDBOX/repo/skills/requesting-code-review"
  [ -d "$d" ] && [ ! -L "$d" ]
  grep -q '^model: opus$' "$d/SKILL.md"
  grep -q '^name: requesting-code-review$' "$d/SKILL.md"
}

@test "missing source skips with exit 0 and leaves installer state untouched" {
  run_overrides
  [ "$status" -eq 0 ]
  [[ "$output" == *"review — source SKILL.md not found"* ]] || false
  [ ! -e "$SANDBOX/repo/skills/review" ]
}

@test "second run is idempotent: wrapper refreshed from recorded source, byte-identical" {
  run_overrides
  [ "$status" -eq 0 ]
  cp "$SANDBOX/repo/skills/ship/SKILL.md" "$SANDBOX/first-ship"
  cp "$SANDBOX/repo/skills/requesting-code-review/SKILL.md" "$SANDBOX/first-rcr"
  run_overrides
  [ "$status" -eq 0 ]
  cmp -s "$SANDBOX/first-ship" "$SANDBOX/repo/skills/ship/SKILL.md"
  cmp -s "$SANDBOX/first-rcr" "$SANDBOX/repo/skills/requesting-code-review/SKILL.md"
}

@test "dangling dir-symlink is left untouched (validate-before-mutate)" {
  rm "$SANDBOX/repo/skills/requesting-code-review"
  ln -s "$SANDBOX/external/nonexistent" "$SANDBOX/repo/skills/requesting-code-review"
  run_overrides
  [ "$status" -eq 0 ]
  [ -L "$SANDBOX/repo/skills/requesting-code-review" ]
}

@test "frontmatter-less source skips without mutating and without aborting the run" {
  printf '# no frontmatter here\nbody\n' > "$SANDBOX/external/gstack-ship/SKILL.md"
  run_overrides
  [ "$status" -eq 0 ]
  [[ "$output" == *"ship — source frontmatter missing or unterminated"* ]] || false
  [ -L "$SANDBOX/repo/skills/ship/SKILL.md" ]
}

@test "stale wrapper whose recorded source vanished is removed for installer re-link" {
  run_overrides
  [ "$status" -eq 0 ]
  rm "$SANDBOX/external/gstack-ship/SKILL.md"
  run_overrides
  [ "$status" -eq 0 ]
  [[ "$output" == *"ship — recorded source missing; stale wrapper removed"* ]] || false
  [ ! -e "$SANDBOX/repo/skills/ship/SKILL.md" ]
}

@test "relative symlink targets are canonicalized before embedding (absolute, ..-free)" {
  rm "$SANDBOX/repo/skills/ship/SKILL.md"
  (cd "$SANDBOX/repo/skills/ship" && ln -s ../../../external/gstack-ship/SKILL.md SKILL.md)
  run_overrides
  [ "$status" -eq 0 ]
  src=$(sed -n 's/^<!-- mysystem-model-override source=\(.*\) -->$/\1/p' "$SANDBOX/repo/skills/ship/SKILL.md")
  [[ "$src" == /* ]] || false
  [[ "$src" != *".."* ]] || false
  [ -f "$src" ]
}

@test "stale sparse wrapper removal also removes the dir so the sparse installer can re-link" {
  run_overrides
  [ "$status" -eq 0 ]
  rm "$SANDBOX/external/sparse-rcr/SKILL.md"
  run_overrides
  [ "$status" -eq 0 ]
  [[ "$output" == *"requesting-code-review — recorded source missing; stale wrapper removed"* ]] || false
  [ ! -e "$SANDBOX/repo/skills/requesting-code-review" ]
}

@test "interrupted conversion (real dir, no SKILL.md) is recovered by removing the empty dir" {
  rm "$SANDBOX/repo/skills/requesting-code-review"
  mkdir "$SANDBOX/repo/skills/requesting-code-review"
  run_overrides
  [ "$status" -eq 0 ]
  [[ "$output" == *"requesting-code-review — empty override dir removed"* ]] || false
  [ ! -e "$SANDBOX/repo/skills/requesting-code-review" ]
}

@test "unterminated source frontmatter skips without mutating the symlink" {
  printf -- '---\nname: ship\ndescription: never closes\n' > "$SANDBOX/external/gstack-ship/SKILL.md"
  run_overrides
  [ "$status" -eq 0 ]
  [[ "$output" == *"ship — source frontmatter missing or unterminated"* ]] || false
  [ -L "$SANDBOX/repo/skills/ship/SKILL.md" ]
}

@test "interrupted-run temp files are swept on the next run" {
  run_overrides
  [ "$status" -eq 0 ]
  touch "$SANDBOX/repo/skills/ship/.SKILL.md.stranded"
  run_overrides
  [ "$status" -eq 0 ]
  [ ! -e "$SANDBOX/repo/skills/ship/.SKILL.md.stranded" ]
}

@test "tracked user-owned workflow skills pin their models directly in frontmatter" {
  run awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^model:/{print $2}' "$CHECKOUT/skills/deep-research/SKILL.md"
  [ "$output" = "sonnet" ]
  run awk 'NR==1&&/^---$/{f=1;next} f&&/^---$/{exit} f&&/^model:/{print $2}' "$CHECKOUT/skills/ai-review-loop/SKILL.md"
  [ "$output" = "opus" ]
}

@test "setup.sh stage 3.5 delegates to the extracted script" {
  grep -q 'bash scripts/apply-model-overrides.sh' "$CHECKOUT/setup.sh"
}
