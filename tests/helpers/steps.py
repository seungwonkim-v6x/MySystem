#!/usr/bin/env python3
"""Print recorded skill names, space separated."""
import json, sys
print(" ".join(s.get("skill", "?") for s in json.load(open(sys.argv[1], encoding="utf-8"))["steps"]))
