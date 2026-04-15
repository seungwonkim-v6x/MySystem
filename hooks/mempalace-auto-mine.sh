#!/bin/bash
# Stop hook: auto-mine the current session transcript into MemPalace
# Triggered when Claude Code session ends

export PATH="/Users/seungwonkim/Library/Python/3.9/bin:/Users/seungwonkim/.nvm/versions/node/v22.6.0/bin:/usr/local/bin:/usr/bin:/bin"
export HOME="/Users/seungwonkim"

INPUT=$(cat)
SESSION_ID=$(echo "$INPUT" | jq -r '.session_id // empty')
PROJECT_DIR=$(echo "$INPUT" | jq -r '.cwd // empty')

# Derive project key from cwd (same format Claude uses for project dirs)
if [ -n "$PROJECT_DIR" ]; then
  PROJECT_KEY=$(echo -n "$PROJECT_DIR" | sed 's|/|-|g; s|^-||')
  TRANSCRIPT_DIR="$HOME/.claude/projects/-${PROJECT_KEY}"

  if [ -d "$TRANSCRIPT_DIR" ] && [ -n "$SESSION_ID" ]; then
    TRANSCRIPT_FILE="$TRANSCRIPT_DIR/${SESSION_ID}.jsonl"
    if [ -f "$TRANSCRIPT_FILE" ]; then
      # Mine just this session's transcript
      WING=$(basename "$PROJECT_DIR")
      mempalace mine "$TRANSCRIPT_DIR" --mode convos --wing "$WING" --agent seungwon-v6x --limit 1 --extract general >> "$HOME/.mempalace/auto-mine.log" 2>&1 &
    fi
  fi
fi

exit 0
