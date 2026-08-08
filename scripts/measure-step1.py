#!/usr/bin/env python3
"""Measure how often a Step-1 skill ran before the first file edit of a session.

Why this exists. ADR-0019, ADR-0020, and ADR-0021 each pre-registered a kill
criterion citing a measurement script, and that script is gone from disk. This
script does NOT restore it: those criteria are about course-correction shares
(REDIRECT / REMOVE), a different metric. What it does restore is reproducibility
for the one number it computes, so the next ADR cannot re-derive a fourth answer
from the same transcripts.

It was written after two bucketing errors in a row, both of which averaged
different configurations into one bucket and both of which flattered or
maligned the wrong thing:

1. Bucketing by calendar week and file **mtime** smeared across the ADR-0021
   boundary and reported "12%", which read as the restored rule failing when it
   was actually measuring the window where the rule had been deleted.
2. Splitting at commit boundaries but **omitting ADR-0015/0016** blended 52% /
   8% / 62% into a single "48% baseline".

Hence: every boundary is listed, session START time is used, and synthetic
probe sessions are excluded by default.

Usage
-----
    scripts/measure-step1.py                      # by config window (default)
    scripts/measure-step1.py --by week            # calendar weeks
    scripts/measure-step1.py --by size            # by session edit count
    scripts/measure-step1.py --since 2026-08-06T18:08
    scripts/measure-step1.py --keep-probes --json  # include synthetic probe runs

What counts
-----------
A session counts only if it reached a file edit (Edit/Write/MultiEdit/
NotebookEdit). It complies if a Step-1 skill appears as a `Skill` tool call
before that first edit.

Two known biases, both in the direction of under-reporting compliance:

- A Step-1 skill the USER typed as a slash command emits no `Skill` tool call,
  so it is invisible here and to any hook matching on `Skill` (verified
  2026-08-07 with probe hooks: the CLI fires no tool event for user-typed
  commands). Those sessions score as non-compliant.
- A session that delegates its edits to a subagent has them in a separate
  transcript under `<project>/<session>/subagents/`, which this glob does not
  read.

Treat every number here as a floor.
"""

from __future__ import annotations

import argparse
import collections
import datetime as dt
import glob
import json
import os
import sys

STEP1 = {"scope-check", "office-hours", "investigate"}
WORKFLOW = STEP1 | {
    "deep-research", "autoplan", "verify-test", "qa-only", "design-review",
    "review", "requesting-code-review", "verification-before-completion", "ship",
}
EDIT_TOOLS = {"Edit", "Write", "MultiEdit", "NotebookEdit"}

# Every commit that changed whether Step 1 was obligatory on the Claude Code
# surface, timed by when the text first landed ON DISK in ~/.claude — which is
# the live repo, developed in place. The merge commit on main is the wrong
# oracle: ADR-0021's CLAUDE.md was readable from 16:13 (feature commit 58b3fde)
# but main did not carry it until 18:08, so nearly two hours of sessions had the
# new rule while being bucketed under the old one.
#
#   git -C ~/.claude log --date=iso-local --format='%ad %h %s' --all -- CLAUDE.md
#
# These boundaries are approximate by construction and cannot be made exact: the
# file is edited in the working tree before it is committed, so the true
# transition is somewhere earlier than any commit timestamp. Sessions starting
# within a few hours of a boundary are unreliable, which is one more reason not
# to read a decision off a small bucket.
#
# Completeness matters as much as timing. Omitting a boundary averages two
# configurations into one number: the first pass missed 0015/0016 entirely and
# blended 52% / 8% / 62% into a single "48% baseline".
DEFAULT_BOUNDARIES = [
    ("0015 rule removed", "2026-07-13T18:51"),      # 4a15ecb (v0.49.0 merged 20:59)
    ("0016 rule restored", "2026-07-21T13:58"),     # 22e2fa5 v0.50.0
    ("0019 rule removed", "2026-07-30T15:21"),      # f7e5ef5 (v0.55.0 merged 15:45)
    ("0020 description only", "2026-08-05T16:27"),  # 56037b4 v0.56.0
    ("0021 rule restored", "2026-08-06T16:13"),     # 58b3fde (v0.57.0 merged 18:08)
]
MAX_LINES = 200_000  # guard against a runaway transcript (largest seen: 5.6k lines)

# Synthetic sessions from harness experiments. They live under the scratchpad and
# under /private/tmp, edit files, and occasionally invoke a Step-1 skill.
DEFAULT_EXCLUDES = ["claude-501", "scratchpad"]


def session_start(path: str) -> dt.datetime | None:
    """First record timestamp. NOT mtime — mtime is when the session last wrote,
    which lands long sessions in the wrong bucket."""
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            for line in handle:
                try:
                    record = json.loads(line)
                except ValueError:
                    continue
                stamp = record.get("timestamp")
                if not isinstance(stamp, str) or not stamp:
                    continue
                try:
                    parsed = dt.datetime.fromisoformat(stamp.replace("Z", "+00:00"))
                except ValueError:
                    # A corrupt timestamp must not abort the run. This script is
                    # read on the day a kill criterion comes due; one bad file is
                    # not a reason to make that day undebuggable.
                    continue
                return parsed.astimezone().replace(tzinfo=None)
    except OSError:
        pass
    return None


def scan(path: str) -> tuple[list[str], int] | None:
    """Return (step1 skills seen before the first edit, total edit count),
    or None if the session never edited a file."""
    sequence: list[tuple[str, str]] = []
    try:
        with open(path, encoding="utf-8", errors="replace") as handle:
            for index, line in enumerate(handle):
                if index > MAX_LINES:
                    break
                if '"tool_use"' not in line:
                    continue
                try:
                    record = json.loads(line)
                except ValueError:
                    continue
                if record.get("type") != "assistant":
                    continue
                for block in record.get("message", {}).get("content") or []:
                    if not isinstance(block, dict) or block.get("type") != "tool_use":
                        continue
                    name = block.get("name")
                    if name == "Skill":
                        skill = (block.get("input") or {}).get("skill", "")
                        if skill in WORKFLOW:
                            sequence.append(("skill", skill))
                    elif name in EDIT_TOOLS:
                        sequence.append(("edit", name))
    except OSError:
        return None

    edits = [i for i, (kind, _) in enumerate(sequence) if kind == "edit"]
    if not edits:
        return None
    before = [v for k, v in sequence[: edits[0]] if k == "skill"]
    return [s for s in before if s in STEP1], len(edits)


def bucket_for(start: dt.datetime, boundaries: list[tuple[str, dt.datetime]]) -> str:
    label = f"pre-{boundaries[0][0].split()[0]}" if boundaries else "all"
    for name, when in boundaries:
        if start >= when:
            label = name
    return label


def size_bucket(edits: int) -> str:
    for limit, label in ((3, "1-3 edits"), (10, "4-10 edits"), (40, "11-40 edits")):
        if edits <= limit:
            return label
    return ">40 edits"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--projects", default=os.path.expanduser("~/.claude/projects"))
    parser.add_argument("--exclude", action="append", default=[], metavar="SUBSTRING",
                        help="ADDITIONAL project-dir substring to drop; repeatable. Adds to "
                             f"the always-on probe filter {DEFAULT_EXCLUDES}, which removes "
                             "synthetic harness sessions. Use --keep-probes to drop the filter.")
    parser.add_argument("--keep-probes", action="store_true",
                        help="do not filter synthetic probe sessions (they edit files and "
                             "sometimes invoke a Step-1 skill, so this inflates the rate)")
    parser.add_argument("--by", choices=("config", "week", "size"), default="config")
    parser.add_argument("--since", help="ISO datetime; ignore sessions starting before it")
    parser.add_argument("--boundary", action="append", metavar="LABEL=ISO",
                        help="config boundary; repeatable. Overrides the defaults.")
    parser.add_argument("--json", action="store_true", dest="as_json")
    args = parser.parse_args()

    raw = args.boundary or [f"{name}={when}" for name, when in DEFAULT_BOUNDARIES]
    boundaries: list[tuple[str, dt.datetime]] = []
    for item in raw:
        label, sep, when = item.partition("=")
        if not sep or not label.strip():
            print(f"bad --boundary {item!r}: need LABEL=ISO8601", file=sys.stderr)
            return 2
        try:
            boundaries.append((label, dt.datetime.fromisoformat(when)))
        except ValueError:
            print(f"bad --boundary {item!r}: need LABEL=ISO8601", file=sys.stderr)
            return 2
    boundaries.sort(key=lambda pair: pair[1])

    since = None
    if args.since:
        try:
            since = dt.datetime.fromisoformat(args.since)
        except ValueError:
            print(f"bad --since {args.since!r}: need an ISO8601 datetime", file=sys.stderr)
            return 2
        if since.tzinfo is not None:
            # Session starts are compared naive-local; an aware --since would
            # raise TypeError deep in the loop instead of here.
            since = since.astimezone().replace(tzinfo=None)

    if not os.path.isdir(args.projects):
        print(f"no such directory: {args.projects}", file=sys.stderr)
        return 2

    tally: dict[str, list[int]] = collections.defaultdict(lambda: [0, 0])
    order: list[str] = []
    if args.by == "config":
        order = [f"pre-{boundaries[0][0].split()[0]}"] + [n for n, _ in boundaries]
    elif args.by == "size":
        order = ["1-3 edits", "4-10 edits", "11-40 edits", ">40 edits"]

    # A probe session written by a harness experiment edits files and sometimes
    # invokes a Step-1 skill, so leaving them in lets the measurement grade its
    # own homework. The probe filter is additive, not replaceable: an earlier
    # version had --exclude REPLACE the defaults, so narrowing the corpus
    # silently widened it by re-admitting the probes.
    excludes = [e for e in args.exclude if e]
    if not args.keep_probes:
        excludes = DEFAULT_EXCLUDES + excludes

    scanned = skipped = undated = filtered = excluded = 0
    oldest = newest = None
    for path in sorted(glob.glob(os.path.join(args.projects, "*", "*.jsonl"))):
        project = os.path.basename(os.path.dirname(path))
        if any(token in project for token in excludes):
            excluded += 1
            continue
        start = session_start(path)
        if start is None:
            # Counted, not silently dropped: scanned + skipped + undated +
            # filtered must account for the whole corpus, or a shrinking
            # denominator quietly flatters the rate.
            undated += 1
            continue
        if since and start < since:
            filtered += 1
            continue
        oldest = start if oldest is None or start < oldest else oldest
        newest = start if newest is None or start > newest else newest
        result = scan(path)
        if result is None:
            skipped += 1
            continue
        step1, edits = result
        scanned += 1
        if args.by == "config":
            key = bucket_for(start, boundaries)
        elif args.by == "week":
            key = (start - dt.timedelta(days=start.weekday())).strftime("%Y-%m-%d")
        else:
            key = size_bucket(edits)
        tally[key][0] += 1
        if step1:
            tally[key][1] += 1

    total = scanned + skipped + undated + filtered + excluded
    stamp = dt.datetime.now().isoformat(timespec="seconds")

    # Transcripts are retention-pruned (cleanupPeriodDays, 30 days by default),
    # so this corpus shrinks from the old end every day. Without the range and
    # the counts printed alongside the rates, a different number next month is
    # indistinguishable from a behavior change — record this block with any
    # number you cite.
    corpus = {
        "generated": stamp,
        "projects_dir": args.projects,
        "excluded_substrings": excludes,
        "sessions_seen": total,
        "sessions_counted": scanned,
        "oldest_session": oldest.isoformat(timespec="minutes") if oldest else None,
        "newest_session": newest.isoformat(timespec="minutes") if newest else None,
    }

    keys = [k for k in order if k in tally] if order else sorted(tally)
    keys += [k for k in sorted(tally) if k not in keys]

    if args.as_json:
        json.dump({
            "corpus": corpus,
            "scanned": scanned,
            "skipped_no_edits": skipped,
            "skipped_undated": undated,
            "skipped_before_since": filtered,
            "skipped_excluded": excluded,
            "by": args.by,
            "buckets": [
                {"bucket": k, "sessions": tally[k][0], "step1_first": tally[k][1],
                 "rate": round(tally[k][1] / tally[k][0], 4) if tally[k][0] else None}
                for k in keys
            ],
        }, sys.stdout, indent=2)
        print()
        return 0

    print(f"corpus  {corpus['oldest_session']} .. {corpus['newest_session']}   "
          f"{scanned} counted of {total} seen "
          f"(no edit: {skipped}, undated: {undated}, before --since: {filtered}, "
          f"excluded: {excluded})")
    print(f"        excluding: {', '.join(excludes) if excludes else '(nothing)'}"
          f"   generated {stamp}")
    print("        transcripts are retention-pruned; cite this line with any number below")
    print(f"grouped by: {args.by}\n")
    print(f"{'bucket':24} {'sessions':>8} {'Step 1 first':>15}")
    for key in keys:
        sessions, complied = tally[key]
        pct = f"{100 * complied // sessions}%" if sessions else "n/a"
        print(f"{key:24} {sessions:>8} {complied:>6} ({pct:>4})")
    if not keys:
        print("(nothing matched)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
