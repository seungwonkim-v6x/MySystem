#!/usr/bin/env bash
# render-md.sh — PostToolUse hook: render written markdown files to HTML preview.
#
# Wired in ~/.claude/settings.json on Write|Edit|MultiEdit. Reads the PostToolUse
# payload on stdin, extracts tool_input.file_path, filters to .md files outside
# cache/output paths, and renders to ~/.claude/previews/latest-md.html using the
# same kami-parchment template as the v0.32.0 Stop hook (preview-stop.sh).
#
# Different signal from latest.html:
#   - latest.html      = last substantive assistant turn (Stop event)
#   - latest-md.html   = last markdown file written (PostToolUse event)
# Both share ~/.claude/hooks/preview-template.html.
#
# Fail-open by mechanism (PostToolUse cannot block tools per Claude Code docs).
# Render errors are logged to ~/.claude/logs/md-render.log; we always exit 0.
# `set -e` is intentionally NOT used — errors should log+continue, not propagate.

set -uo pipefail

PREVIEW_DIR="$HOME/.claude/previews"
TEMPLATE="$HOME/.claude/hooks/preview-template.html"
LOG="$HOME/.claude/logs/md-render.log"
MAX_BYTES=262144   # 256KB ceiling; base64 of this fits comfortably in a sed arg

mkdir -p "$PREVIEW_DIR" "$HOME/.claude/logs" 2>/dev/null || true

# Cheap rolling rotation: 1MB ceiling, single .old kept.
if [ "$(wc -c < "$LOG" 2>/dev/null || echo 0)" -gt 1048576 ] 2>/dev/null; then
  mv "$LOG" "$LOG.old" 2>/dev/null || true
fi

log() { printf '[%s] %s\n' "$(date '+%F %T')" "$*" >> "$LOG" 2>/dev/null || true; }

payload="$(cat || true)"
[ -z "$payload" ] && exit 0

# Extract path + cwd (Write/Edit/MultiEdit all expose tool_input.file_path).
file_path="$(printf '%s' "$payload" | jq -r '.tool_input.file_path // empty' 2>/dev/null)"
cwd="$(printf '%s' "$payload" | jq -r '.cwd // empty' 2>/dev/null)"
[ -z "$file_path" ] && exit 0

# Resolve relative paths against cwd from payload.
case "$file_path" in
  /*) abs="$file_path" ;;
  *)  abs="${cwd:-$PWD}/$file_path" ;;
esac

# Filter 1: must be a markdown file (case-insensitive extension match).
shopt -s nocasematch 2>/dev/null
case "$abs" in
  *.md) : ;;
  *) exit 0 ;;
esac
shopt -u nocasematch 2>/dev/null

# Filter 2: file must exist + be readable. (Edit can fire on a path that no
# longer exists if a rename happened mid-tool; skip silently.)
[ -f "$abs" ] && [ -r "$abs" ] || exit 0

# Filter 3: skip cache / output / vcs / vendored paths.
# Path-prefix on ~/.claude/previews/ closes the re-entrancy edge case (belt-
# and-suspenders; docs confirm hook-subprocess writes don't re-trigger).
case "$abs" in
  "$HOME/.claude/previews/"*)        exit 0 ;;
  "$HOME/.claude/external-skills/"*) exit 0 ;;
  "$HOME/.claude/skills/gstack/"*)   exit 0 ;;
  "$HOME/.claude/references/"*)      exit 0 ;;
  "$HOME/.gstack/"*)                 exit 0 ;;
  *"/node_modules/"*)                exit 0 ;;
  *"/.git/"*)                        exit 0 ;;
  *"/__pycache__/"*)                 exit 0 ;;
  *"/.next/"*|*"/dist/"*|*"/build/"*) exit 0 ;;
esac

# Filter 4: size ceiling.
size="$(wc -c < "$abs" 2>/dev/null || echo 0)"
if [ "$size" -gt "$MAX_BYTES" ] 2>/dev/null; then
  log "skip oversize: $abs ($size bytes > $MAX_BYTES)"
  exit 0
fi

# Filter 5: template sanity.
[ -f "$TEMPLATE" ] || { log "missing template: $TEMPLATE"; exit 0; }

# Render.
md_content="$(cat "$abs" 2>/dev/null || true)"
[ -z "$md_content" ] && exit 0

md_b64="$(printf '%s' "$md_content" | base64 | tr -d '\n')"
ts="$(date '+%Y-%m-%d %H:%M:%S')"

# PID-suffix the tmp so concurrent hook invocations don't clobber each other
# before the atomic mv. sed > tmp is NOT atomic — mv is. Without the suffix,
# back-to-back .md writes in a multi-tool turn can produce a torn HTML.
tmp="$PREVIEW_DIR/.latest-md.html.tmp.$$"
if sed -e "s|__MARKDOWN_BASE64__|$md_b64|" \
       -e "s|__TIMESTAMP__|$ts|" \
       "$TEMPLATE" > "$tmp" 2>>"$LOG"; then
  mv "$tmp" "$PREVIEW_DIR/latest-md.html"
  cp "$abs" "$PREVIEW_DIR/latest-md.md" 2>/dev/null || true
  log "rendered: $abs ($size bytes)"
else
  rm -f "$tmp" 2>/dev/null || true
  log "render failed: $abs"
fi

exit 0
