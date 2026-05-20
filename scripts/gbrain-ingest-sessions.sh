#!/usr/bin/env bash
# gbrain-ingest-sessions.sh
# Realizes ADR-0008 Section 2's "capture-first" intent.
# Extracts user+assistant text from Claude Code session JSONL files,
# writes one gbrain page per session (idempotent via marker file).
# Runs hourly via ~/Library/LaunchAgents/com.user.gbrain-session-capture.plist
#
# Manual backfill: TIME_WINDOW=10080 bash $0  # last week
# Initial full sweep: TIME_WINDOW=525600 bash $0  # last year

set -euo pipefail

PROJECTS_DIR="$HOME/.claude/projects"
GBRAIN_HOME="$HOME/.gbrain"
INGEST_LOG="$GBRAIN_HOME/ingest-log.jsonl"
MARKER_DIR="$GBRAIN_HOME/ingested"
TIME_WINDOW="${TIME_WINDOW:-65}"  # minutes
MAX_SIZE_KB="${MAX_SIZE_KB:-500}"  # per-session content cap before skipping

# Lift gbrain's default markdown fence cap (100/page) — code-heavy sessions
# routinely exceed it. Setting high avoids "Page not found" cascade errors.
export GBRAIN_MAX_FENCES_PER_PAGE="${GBRAIN_MAX_FENCES_PER_PAGE:-2000}"

mkdir -p "$MARKER_DIR"
touch "$INGEST_LOG"

if ! command -v gbrain >/dev/null 2>&1; then
  echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"error\":\"gbrain CLI not on PATH\"}" >> "$INGEST_LOG"
  exit 0
fi

if ! command -v jq >/dev/null 2>&1; then
  echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"error\":\"jq not on PATH\"}" >> "$INGEST_LOG"
  exit 0
fi

processed=0
skipped=0
ingested=0
errored=0

while IFS= read -r jsonl; do
  processed=$((processed + 1))
  filename=$(basename "$jsonl" .jsonl)

  # Skip files in memory/ subdirs
  case "$jsonl" in
    */memory/*) continue ;;
  esac

  current_sig=$(stat -f "%z-%m" "$jsonl" 2>/dev/null || stat -c "%s-%Y" "$jsonl" 2>/dev/null)
  marker_file="$MARKER_DIR/$filename"
  if [ -f "$marker_file" ] && [ "$(cat "$marker_file" 2>/dev/null)" = "$current_sig" ]; then
    skipped=$((skipped + 1))
    continue
  fi

  # Repo name from parent dir (e.g., -Users-seungwonkim-Documents-vprop → vprop)
  # Strip "-Users-<user>-" prefix and common parent dirs (Documents/, src/, etc.)
  repo_encoded=$(basename "$(dirname "$jsonl")")
  repo_name=$(echo "$repo_encoded" \
    | sed 's|^-||; s|^Users-[^-]*-||; s|^Documents-||; s|^src-||; s|^code-||; s|^projects-||; s|^-||' \
    | tr '/' '-' \
    | tr -c 'a-zA-Z0-9-' '-' \
    | sed 's/--*/-/g; s/^-//; s/-$//')
  [ -z "$repo_name" ] && repo_name="unknown"

  # 12 chars of UUID — collision-resistant (8 chars too short for agent-ab vs agent-ae)
  short_uuid="${filename:0:12}"
  slug="cc-session-${repo_name}-${short_uuid}"

  content=$(mktemp -t gbrain-ingest.XXXXXX)
  {
    echo "---"
    echo "type: transcript"
    echo "session_id: $filename"
    echo "repo: $repo_name"
    echo "captured_at: $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    echo "source_path: $jsonl"
    echo "ingested_by: gbrain-ingest-sessions.sh"
    echo "---"
    echo
    echo "# Claude Code session: $repo_name / ${short_uuid}"
    echo
    jq -r '
      . as $msg |
      if ($msg.type // "") == "user" and (($msg.message.content // "") | type) == "string" then
        "## USER\n\n" + $msg.message.content + "\n"
      elif ($msg.type // "") == "user" and (($msg.message.content // []) | type) == "array" then
        (($msg.message.content // []) | map(select(.type == "text")) | map(.text) | join("\n\n")) as $text |
        if ($text // "") == "" then empty else "## USER\n\n" + $text + "\n" end
      elif ($msg.type // "") == "assistant" and (($msg.message.content // []) | type) == "array" then
        (($msg.message.content // []) | map(select(.type == "text")) | map(.text) | join("\n\n")) as $text |
        if ($text // "") == "" then empty else "## ASSISTANT\n\n" + $text + "\n" end
      else empty end
    ' "$jsonl" 2>/dev/null
  } > "$content"

  # Skip if content is just frontmatter (no real messages)
  body_lines=$(tail -n +10 "$content" 2>/dev/null | wc -l | tr -d ' ')
  if [ "${body_lines:-0}" -lt 5 ]; then
    rm -f "$content"
    skipped=$((skipped + 1))
    continue
  fi

  size_kb=$(du -k "$content" | awk '{print $1}')
  if [ "$size_kb" -gt "$MAX_SIZE_KB" ]; then
    echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"slug\":\"$slug\",\"skipped\":\"oversize\",\"size_kb\":$size_kb}" >> "$INGEST_LOG"
    rm -f "$content"
    skipped=$((skipped + 1))
    continue
  fi

  if gbrain put "$slug" < "$content" >/dev/null 2>"$content.err"; then
    echo "$current_sig" > "$marker_file"
    echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"slug\":\"$slug\",\"session\":\"$filename\",\"repo\":\"$repo_name\",\"size_kb\":$size_kb}" >> "$INGEST_LOG"
    ingested=$((ingested + 1))
  else
    err_msg=$(head -c 500 "$content.err" 2>/dev/null | tr -d '\n' | tr -d '"')
    echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"slug\":\"$slug\",\"error\":\"$err_msg\"}" >> "$INGEST_LOG"
    errored=$((errored + 1))
  fi
  rm -f "$content" "$content.err"
done < <(find "$PROJECTS_DIR" -name "*.jsonl" -type f -mmin -"$TIME_WINDOW" 2>/dev/null)

echo "{\"ts\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"summary\":{\"processed\":$processed,\"ingested\":$ingested,\"skipped\":$skipped,\"errored\":$errored,\"window_min\":$TIME_WINDOW}}" >> "$INGEST_LOG"
