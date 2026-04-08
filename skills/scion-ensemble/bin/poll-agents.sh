#!/bin/bash
# poll-agents.sh — Poll scion agents until completion or timeout.
# Usage: poll-agents.sh <agent1> <agent2> [agent3] ...
# Exit code 0 = quorum met, 1 = quorum failed
#
# Environment variables (optional):
#   POLL_INTERVAL  — seconds between polls (default: 10)
#   MAX_TIMEOUT    — hard cap in seconds (default: 600)
#   QUORUM_MIN     — minimum agents that must complete (default: 2)

set -euo pipefail

AGENTS=("$@")
if [ ${#AGENTS[@]} -eq 0 ]; then
  echo "Usage: poll-agents.sh <agent1> <agent2> ..." >&2
  exit 1
fi

INTERVAL="${POLL_INTERVAL:-10}"
MAX="${MAX_TIMEOUT:-600}"
QUORUM="${QUORUM_MIN:-2}"
ELAPSED=0

# Build a Python script that checks agent status from JSON stdin.
# Agent names are passed as a Python list literal built from shell args.
NAMES_PY="["
for a in "${AGENTS[@]}"; do
  NAMES_PY+="\"$a\","
done
NAMES_PY+="]"

while [ "$ELAPSED" -lt "$MAX" ]; do
  RESULT=$(scion list --format json 2>/dev/null || echo "[]")

  STATUS=$(echo "$RESULT" | python3 -c "
import sys, json
agents = json.load(sys.stdin)
targets = set($NAMES_PY)
done = []
running = []
failed = []
for a in agents:
    name = a.get('name', '')
    if name not in targets:
        continue
    phase = a.get('phase', '')
    activity = a.get('activity', '')
    if activity == 'completed' or phase == 'stopped':
        done.append(name)
    elif phase == 'error':
        failed.append(name)
    elif phase == '' or phase in ('created', 'provisioning', 'cloning', 'starting', 'running'):
        running.append(name)
    else:
        running.append(name)
print(f'DONE={len(done)} FAILED={len(failed)} RUNNING={len(running)}')
for d in done:
    print(f'  COMPLETED: {d}')
for f in failed:
    print(f'  FAILED: {f}')
for r in running:
    print(f'  RUNNING: {r}')
print(f'TOTAL_TERMINAL={len(done) + len(failed)}')
" 2>/dev/null)

  echo "[${ELAPSED}s] $STATUS"

  TERMINAL=$(echo "$STATUS" | grep 'TOTAL_TERMINAL=' | sed 's/TOTAL_TERMINAL=//')
  DONE_COUNT=$(echo "$STATUS" | grep 'DONE=' | head -1 | sed 's/DONE=\([0-9]*\).*/\1/')

  # All agents reached terminal state
  if [ "${TERMINAL:-0}" -ge "${#AGENTS[@]}" ]; then
    if [ "${DONE_COUNT:-0}" -ge "$QUORUM" ]; then
      echo "QUORUM_MET: $DONE_COUNT/${#AGENTS[@]} completed (needed $QUORUM)"
      exit 0
    else
      echo "QUORUM_FAILED: $DONE_COUNT/${#AGENTS[@]} completed (needed $QUORUM)"
      exit 1
    fi
  fi

  # Quorum already met even with some still running — but wait for all to finish
  # unless we're past 80% of timeout
  if [ "${DONE_COUNT:-0}" -ge "$QUORUM" ] && [ "$ELAPSED" -gt $(( MAX * 80 / 100 )) ]; then
    echo "QUORUM_MET_TIMEOUT: $DONE_COUNT/${#AGENTS[@]} completed, timeout approaching"
    exit 0
  fi

  sleep "$INTERVAL"
  ELAPSED=$((ELAPSED + INTERVAL))
done

# Timeout reached
DONE_COUNT=$(echo "$STATUS" | grep 'DONE=' | head -1 | sed 's/DONE=\([0-9]*\).*/\1/')
if [ "${DONE_COUNT:-0}" -ge "$QUORUM" ]; then
  echo "QUORUM_MET_AFTER_TIMEOUT: $DONE_COUNT/${#AGENTS[@]} completed (needed $QUORUM)"
  exit 0
else
  echo "TIMEOUT: $DONE_COUNT/${#AGENTS[@]} completed after ${MAX}s (needed $QUORUM)"
  exit 1
fi
