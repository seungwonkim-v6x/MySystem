#!/usr/bin/env python3
"""Build a hook payload without shell quoting hazards."""
import json
import sys

kind, session, pid = sys.argv[1], sys.argv[2], sys.argv[3]
if kind == "prompt":
    print(json.dumps({"hook_event_name": "UserPromptSubmit", "session_id": session,
                      "prompt_id": pid, "prompt": sys.argv[4]}))
else:
    raise SystemExit(f"unknown payload kind: {kind}")
