#!/usr/bin/env python3
"""Print the recorded phase from a marker file."""
import json
import sys

print(json.load(open(sys.argv[1], encoding="utf-8"))["phase"])
