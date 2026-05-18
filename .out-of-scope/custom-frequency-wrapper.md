# Out of scope: Custom frequency-control wrapper around learning-opportunities-auto

**Decided:** 2026-05-17 during v0.33.0 /office-hours (rejected option C).

## What it is

Fork `learning-opportunities-auto`'s `post-tool-use.sh` and wrap it with
custom frequency control — anchor the regex to `^git\s+commit\b` so `git log`
and `git show` stop false-positive-triggering, persist a real decline-state
file so "decline → stop offering" actually means stop, add snooze for N
minutes/days.

## Why it was attractive

The upstream regex is intentionally loose (matches any Bash payload containing
both "git" and "commit") and "sticky decline" is a prompt-level instruction,
not enforced state. A wrapper would harden both. The whole point of the
v0.33.0 review (Step 7 /requesting-code-review) was catching exactly these
mismatches.

## Why we rejected it

Forking crosses MySystem's "harness, don't build" line. Maintaining a fork of
a third-party hook = exactly the kind of upkeep the harness philosophy was
designed to avoid. The cost of looser-than-ideal triggers (a false-positive
burns the 2-offer-per-session budget) is real but small; the cost of
maintaining a fork compounds forever.

CHANGELOG and CLAUDE.md were corrected to describe the real upstream
behavior honestly — that's the audit trail.

## Reconsider when

- Upstream becomes unresponsive and the looseness causes real friction
  (decline rate climbs because of false-positive fatigue)
- An upstream maintainer accepts a PR anchoring the regex — then this
  becomes "use the upstream", not "fork"
- We accumulate 3+ similar fork-temptations on different plugins — at that
  point we have evidence the harness philosophy needs an exception path,
  not just a one-off fork
