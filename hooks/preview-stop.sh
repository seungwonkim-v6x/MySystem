#!/usr/bin/env bash
# preview-stop.sh — render the latest assistant turn as HTML and open it in a browser.
#
# Wired as a Stop hook in settings.json. Reads the standard Stop hook payload
# on stdin (session_id, transcript_path). Extracts the last assistant text
# turn from the transcript JSONL, escapes it as base64, and writes a static
# HTML file. First write per session opens a browser tab; subsequent writes
# rely on the tab's visibilitychange listener to auto-reload.
#
# Short or low-signal turns (chat back-and-forth) are skipped so the browser
# only flashes for substantive workflow output (plans, reviews, research).

set -euo pipefail

PREVIEW_DIR="$HOME/.claude/previews"
TEMPLATE="$HOME/.claude/hooks/preview-template.html"
mkdir -p "$PREVIEW_DIR"

# Read the Stop hook payload (JSON on stdin).
payload="$(cat || true)"
if [ -z "$payload" ]; then exit 0; fi

transcript_path="$(echo "$payload" | jq -r '.transcript_path // empty')"
session_id="$(echo "$payload" | jq -r '.session_id // "unknown"')"
if [ -z "$transcript_path" ] || [ ! -f "$transcript_path" ]; then exit 0; fi

# Extract the last assistant message's concatenated text blocks.
# Claude Code transcripts are JSONL, one event per line. Assistant turns
# have type "assistant" with message.content as an array of blocks.
# Pull the most recent *substantive* assistant turn: text-bearing,
# >=600 chars OR contains markdown structure (## heading, table, fence).
# This intentionally skips short ack-style replies so the preview stays
# pinned to the last meaningful output until a new substantive one arrives.
last_text="$(
  jq -rs '
    def text_of:
      ([.message.content[]? | select(.type == "text") | .text] | join("\n\n"));
    map(select(.type == "assistant"
               and ((.message.content // null) | type) == "array"
               and (text_of | length) > 0))
    | map(. + {_text: text_of})
    | map(select((._text | length) >= 600
                 or (._text | test("(^|\n)(##|\\||```)"))))
    | if length == 0 then "" else (last | ._text) end
  ' "$transcript_path" 2>/dev/null || true
)"

if [ -z "$last_text" ] || [ "$last_text" = "null" ]; then exit 0; fi

# Persist raw markdown (handy for grep / re-rendering later).
printf '%s\n' "$last_text" > "$PREVIEW_DIR/latest.md"

# Build the HTML by substituting base64-encoded markdown + timestamp.
md_b64="$(printf '%s' "$last_text" | base64 | tr -d '\n')"
ts="$(date '+%Y-%m-%d %H:%M:%S')"

# sed-safe substitution: write to a tmp file, then atomic rename.
tmp="$PREVIEW_DIR/.latest.html.tmp"
sed -e "s|__MARKDOWN_BASE64__|$md_b64|" \
    -e "s|__TIMESTAMP__|$ts|" \
    "$TEMPLATE" > "$tmp"
mv "$tmp" "$PREVIEW_DIR/latest.html"

# Viewer setup is on the user:
#   - VS Code: install the Live Preview extension (ms-vscode.live-server)
#     and open `latest.html` in it once. The extension watches the file
#     and auto-reloads on every hook write — no further action needed.
#   - Browser fallback: double-click `~/.claude/previews/latest.html` once;
#     the embedded visibilitychange listener reloads on tab focus.
# The hook intentionally does NOT call `open` — that would spawn a new
# OS-default tab on every session start.

exit 0
