# Out of scope: SuperClaude (sc:*) as a parallel system

**Decided:** 2026-05-17 during v0.30.0 cleanup (the 31 `sc:*` slash commands
were deleted from `commands/sc/` then).

## What it is

[SuperClaude_Framework](https://github.com/SuperClaude-Org/SuperClaude_Framework) —
22k ⭐ Claude Code framework, ships 31 `sc:*` slash commands covering
the same workflow phases MySystem already has (`/sc:brainstorm`, `/sc:design`,
`/sc:implement`, `/sc:test`, `/sc:git`, etc.). Strong design, popular, MIT.

## Why it was attractive

Single coherent system, well-documented, "do it the SuperClaude way" is a
real option — could replace MySystem's harness entirely.

## Why we rejected it

It's a parallel system, not a complementary one. Adopting it would mean
either (a) running two workflows in parallel and getting confused which to
invoke when, or (b) replacing MySystem's harness wholesale. Neither matches
the MySystem ethos of "compose external skills via a thin harness I control".

Specifically the rejection played out: `commands/sc/` had been installed
silently (via SuperClaude's setup), and the 31 sc:* slash commands surfaced
in the session's available-skills list every turn — exactly the agent-skill
sprawl the v0.30.0 cleanup was designed to kill.

## Reconsider when

- MySystem's harness approach proves too thin for some workflow phase
  SuperClaude handles natively, AND no smaller-surface alternative exists
- Specifically: would we wholesale-adopt SuperClaude, or just cherry-pick
  one skill? If cherry-pick, do that via `SPARSE_SKILLS` per the harness
  pattern — don't import the full framework
