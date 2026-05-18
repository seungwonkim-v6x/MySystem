# Out of scope: Keeping a populated `agents/` directory

**Decided:** 2026-05-17 during v0.30.0 cleanup (the 20 agent files were
deleted from `agents/`).

## What it is

A `~/.claude/agents/` directory full of specialized subagent definitions
(`backend-architect.md`, `business-panel-experts.md`, `deep-research-agent.md`,
`devops-architect.md`, `frontend-architect.md`, `pm-agent.md`,
`security-engineer.md`, …). 20 files at v0.29.x; came from SuperClaude
install.

## Why it was attractive

A specialist subagent for every domain — sounds productive. The harness
mentions "dispatch via Agent tool" so the surface seems built-in.

## Why we rejected it

Zero of the 20 agent files were ever invoked by MySystem's workflow. They
just inflated the available-agents list at every session start, biasing the
coordinator toward "spawn a subagent" instead of doing the work directly.
Most cases where a subagent helps, the built-in `general-purpose` agent
(or one of the few specialized agents in the workflow path, like the
`/requesting-code-review` dispatcher in Step 7) is sufficient.

## Reconsider when

- A specific workflow step genuinely needs domain isolation (e.g. a
  "fresh-eye reviewer with zero conversation history" — which we already
  have via Step 7's pattern)
- We accumulate 3+ requests for the same persona that built-in agents can't
  match. Then write **one** focused subagent file and tracking it as a
  user-owned skill in `skills/`, not a 20-file shotgun
