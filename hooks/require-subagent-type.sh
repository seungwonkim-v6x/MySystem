#!/bin/bash
# PreToolUse hook: Block Agent calls without subagent_type
# Generic Agent(model: "opus", prompt: "...") is not allowed.
# All ensemble steps must use a named custom subagent.

INPUT=$(cat)
TOOL_NAME=$(echo "$INPUT" | jq -r '.tool_name')
SUBAGENT_TYPE=$(echo "$INPUT" | jq -r '.tool_input.subagent_type // empty')

# Only enforce on Agent tool calls
if [ "$TOOL_NAME" != "Agent" ]; then
  exit 0
fi

# Allow if subagent_type is specified
if [ -n "$SUBAGENT_TYPE" ]; then
  exit 0
fi

# Block — no subagent_type
jq -n '{
  hookSpecificOutput: {
    hookEventName: "PreToolUse",
    permissionDecision: "deny",
    permissionDecisionReason: "BLOCKED: Agent calls must use subagent_type. Use a named custom subagent (e.g., bug-hunter, code-reviewer, investigator). See ~/.claude/CLAUDE.md Ensemble Execution Rule."
  }
}'
exit 0
