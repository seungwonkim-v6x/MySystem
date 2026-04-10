#!/bin/bash
# SessionStart hook: inject MemPalace wake-up context (L0+L1, ~170 tokens)

export PATH="/Users/seungwonkim/Library/Python/3.9/bin:/usr/local/bin:/usr/bin:/bin"
export HOME="/Users/seungwonkim"

PROJECT_DIR=$(cat | jq -r '.cwd // empty')

if [ -n "$PROJECT_DIR" ]; then
  WING=$(basename "$PROJECT_DIR")
  CONTEXT=$(mempalace wake-up --wing "$WING" 2>/dev/null)
  if [ -n "$CONTEXT" ]; then
    jq -n --arg ctx "$CONTEXT" '{
      hookSpecificOutput: {
        hookEventName: "SessionStart",
        additionalContext: $ctx
      }
    }'
  fi
fi

exit 0
