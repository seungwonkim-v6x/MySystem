#!/usr/bin/env bash
# Itemize the always-loaded instruction chain for MySystem.
#
# Reports bytes for: CLAUDE.md, every @import target (one level deep),
# critical-rules.md, MEMORY.md (auto-memory, capped 200 lines per Anthropic),
# and every skills/*/SKILL.md frontmatter (always-loaded portion).
#
# Compares total against the Codex CLI 32 KiB hard cap so cross-tool
# truncation is visible. Read-only; safe to run repeatedly.
#
# Usage: bash ~/.claude/scripts/claude-md-budget.sh

set -u

CLAUDE_HOME="${CLAUDE_HOME:-$HOME/.claude}"
CODEX_CAP=32768   # bytes — OpenAI Codex CLI project_doc_max_bytes default

cd "$CLAUDE_HOME" || { echo "cannot cd to $CLAUDE_HOME" >&2; exit 1; }

always_total=0
scoped_total=0
printf "%-50s %10s %8s\n" "FILE" "BYTES" "LINES"
printf -- "------------------------------------------------------------------------------\n"

report_always() {
  local label="$1" path="$2"
  if [ -r "$path" ]; then
    local bytes lines
    bytes=$(wc -c < "$path" | tr -d ' ')
    lines=$(wc -l < "$path" | tr -d ' ')
    printf "%-50s %10s %8s\n" "$label" "$bytes" "$lines"
    always_total=$((always_total + bytes))
  else
    printf "%-50s %10s %8s\n" "$label" "(missing)" "—"
  fi
}

report_scoped() {
  local label="$1" path="$2"
  if [ -r "$path" ]; then
    local bytes lines
    bytes=$(wc -c < "$path" | tr -d ' ')
    lines=$(wc -l < "$path" | tr -d ' ')
    printf "%-50s %10s %8s\n" "$label" "$bytes" "$lines"
    scoped_total=$((scoped_total + bytes))
  else
    printf "%-50s %10s %8s\n" "$label" "(missing)" "—"
  fi
}

# Resolve @import paths recursively (up to 5 hops per Anthropic docs).
# Visited-set prevents cycles. Use newline-delimited string instead of array
# to avoid the "empty array under `set -u`" bash trap.
VISITED=""
already_visited() {
  local target="$1"
  case $'\n'"$VISITED"$'\n' in
    *$'\n'"$target"$'\n'*) return 0 ;;
  esac
  return 1
}

walk_imports() {
  local current="$1" depth="$2" indent_prefix="$3"
  [ "$depth" -gt 5 ] && return
  [ -r "$current" ] || return
  already_visited "$current" && return
  VISITED="$VISITED"$'\n'"$current"

  while IFS= read -r import_target; do
    [ -n "$import_target" ] || continue
    local resolved="$import_target"
    case "$resolved" in
      "~/"*) resolved="${HOME}/${resolved#~/}" ;;
      "/"*)  : ;;
      *)     resolved="$(dirname "$current")/$resolved" ;;
    esac
    report_always "${indent_prefix}@import → $import_target" "$resolved"
    walk_imports "$resolved" $((depth + 1)) "  ${indent_prefix}"
  done < <(grep -oE '^@[A-Za-z0-9_./~-]+' "$current" 2>/dev/null | sed 's/^@//')
}

# Root CLAUDE.md (always loaded)
report_always "CLAUDE.md" "$CLAUDE_HOME/CLAUDE.md"
walk_imports "$CLAUDE_HOME/CLAUDE.md" 1 "  "

# Native .claude/rules/*.md. Files without a "paths:" frontmatter load
# unconditionally and survive /compact (counted into always_total). Files
# WITH paths: are loaded only when matching files are read, and per
# Anthropic context-window docs they are NOT re-injected after compaction
# until a matching file is read again — counted into scoped_total separately
# so the headline number reflects steady-state always-loaded weight.
if [ -d "$CLAUDE_HOME/rules" ]; then
  for rule in "$CLAUDE_HOME/rules"/*.md; do
    [ -r "$rule" ] || continue
    label="  .claude/rules/$(basename "$rule")"
    if head -n 1 "$rule" | grep -q "^---"; then
      report_scoped "$label (path-scoped — not always-loaded)" "$rule"
    else
      report_always "$label (always-loaded)" "$rule"
    fi
  done
fi

# Auto-memory MEMORY.md (Anthropic caps at 200 lines / 25 KB always-loaded)
MEM_FILE=$(find "$CLAUDE_HOME/projects" -maxdepth 3 -name "MEMORY.md" -type f 2>/dev/null | head -1)
[ -n "$MEM_FILE" ] && report_always "MEMORY.md (auto-memory)" "$MEM_FILE"

# Skills frontmatter weight estimate (Claude Code only — Codex CLI does not
# load skill frontmatter, only CLAUDE.md/AGENTS.md, so this counts against
# Claude Code session weight only).
#
# Skills nest one level deep under skills/<vendor>/<name>/SKILL.md in this
# repo, so depth=3 catches gstack and others. external-skills follow the
# same pattern. The estimate is a LOWER BOUND — deeper nested skills exist
# but their progressive-disclosure behaviour is the same.
SKILL_COUNT=$(find "$CLAUDE_HOME/skills" "$CLAUDE_HOME/external-skills" -maxdepth 3 -name "SKILL.md" -type f 2>/dev/null | wc -l | tr -d ' ')
est_skill_bytes=0
if [ "$SKILL_COUNT" -gt 0 ]; then
  est_skill_bytes=$((SKILL_COUNT * 200))
fi

printf -- "------------------------------------------------------------------------------\n"
printf "%-50s %10s\n" "TOTAL Claude Code rules+CLAUDE.md (always)" "$always_total"
[ "$scoped_total" -gt 0 ] && printf "%-50s %10s\n" "TOTAL path-scoped (loaded on match only)" "$scoped_total"
[ "$SKILL_COUNT" -gt 0 ] && printf "%-50s %10s\n" "skill frontmatter estimate ($SKILL_COUNT × 200 B)" "$est_skill_bytes"

# Codex CLI cap applies ONLY to the agent-doc file (CLAUDE.md/AGENTS.md);
# Codex does not read .claude/rules/, MEMORY.md, or skill frontmatter, so
# comparing the full always-loaded chain to Codex's cap is apples-to-oranges.
claude_md_bytes=$(wc -c < "$CLAUDE_HOME/CLAUDE.md" 2>/dev/null | tr -d ' ')
printf "\n%-50s %10s\n" "Codex cap target (CLAUDE.md alone)" "$CODEX_CAP"
printf "%-50s %10s\n" "  CLAUDE.md size" "$claude_md_bytes"
if [ "$claude_md_bytes" -gt "$CODEX_CAP" ]; then
  printf "⚠  CLAUDE.md alone OVER %s bytes — Codex CLI will truncate.\n" "$((claude_md_bytes - CODEX_CAP))"
  exit 1
else
  printf "✓  CLAUDE.md fits with %s bytes headroom (Codex CLI).\n" "$((CODEX_CAP - claude_md_bytes))"
fi

exit 0
