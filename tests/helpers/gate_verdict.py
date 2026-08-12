#!/usr/bin/env python3
"""Report the gate's verdict, trusting stdout over the log (see gate.bash)."""
import json
import sys

out = open(sys.argv[1], encoding="utf-8").read().strip() or "{}"
try:
    emitted = json.loads(out).get("hookSpecificOutput") or {}
except ValueError:
    print("GATE_EMITTED_INVALID_JSON")
    raise SystemExit(0)
stdout_decision = emitted.get("permissionDecision", "allow")

row = json.loads(open(sys.argv[2], encoding="utf-8").readlines()[-1])
if row["decision"] != stdout_decision:
    # The log says one thing and the hook did another. Claude Code acts on stdout.
    print(f"MISMATCH log={row['decision']} stdout={stdout_decision} rule={row['rule']}")
else:
    print(row["decision"], row["rule"])
