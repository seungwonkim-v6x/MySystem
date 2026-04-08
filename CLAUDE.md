# MySystem — Personal Workflow

## THE ONE RULE

Your first tool call for any task MUST be `Skill(skill: "scion-ensemble")`.

Not Read. Not Grep. Not Bash. Not Agent. Not "let me just check one thing first."
Your FIRST tool call is /scion-ensemble. Every time. For every step.

You are a COORDINATOR. You do not work alone. You dispatch 4 agents and synthesize.

---

## How It Works

1. User gives you a task (bug fix, feature, investigation, etc.)
2. Determine which workflow step you're on (see Workflow below)
3. Read the relevant skill's SKILL.md to extract the methodology
4. Invoke /scion-ensemble with: task + methodology + output format
5. The skill spawns 4 agents in parallel:
   - 1 local Claude (Agent tool, sonnet) — full project context
   - 3 Scion containers (Claude Opus, Gemini 2.5 Pro, Codex) — isolated, fresh eyes
6. Collect results → synthesize → present Consensus / Unique / Disagreements
7. Wait for user approval → move to next step

If Scion is unavailable (no Docker), fall back to 3 local sonnet subagents + warn user.

---

## Workflow Steps

### Debugging (bug reports, errors, unexpected behavior)

```
/investigate → /slow-down → /research → /autoplan → Implementation → /verify-test → /review → /bugbot → /ship
```

### Feature / Bug Fix / Refactoring

```
/office-hours → /slow-down → /research → /autoplan → Implementation → /verify-test → /review → /bugbot → /ship
```

Every step (except /ship) goes through /scion-ensemble. No exceptions.
Steps run in order. Never skip. Never reorder. User interrupts if they want to skip.

---

## Step Details

For each step: read the skill file → extract methodology → invoke /scion-ensemble.

| Step | Skill file to read | What to extract |
|------|--------------------|-----------------|
| /investigate | `~/.claude/skills/investigate/SKILL.md` | 4-phase root cause methodology |
| /office-hours | `~/.claude/skills/office-hours/SKILL.md` | Idea validation methodology |
| /slow-down | `~/.claude/skills/slow-down/SKILL.md` | 5-step concretization process |
| /research | `~/.claude/skills/search-first/SKILL.md` | Research-before-coding workflow |
| /autoplan | `~/.claude/skills/autoplan/SKILL.md` | CEO + Design + Eng review |
| Implementation | (no skill file) | Implementation task description |
| /verify-test | `~/.claude/skills/verify-test/SKILL.md` | Throwaway test generation |
| /review | `~/.claude/skills/review/SKILL.md` | Code review criteria |
| /bugbot | `~/.claude/skills/bugbot/SKILL.md` | Fresh-eye bug review |
| /ship | Run directly — ONLY step without /scion-ensemble | |

The extracted methodology goes INTO the /scion-ensemble task prompt so all 4 agents
(including Gemini and Codex, which can't read skill files) follow the same methodology.

---

## Subagent Permissions

Local subagents: read-only (Read, Grep, Glob, Bash). Only the coordinator writes files, commits, pushes.

---

## Repo Self-Management

When modifying this repo (MySystem):
1. Bump VERSION (semver)
2. Update CHANGELOG.md
3. Git tag vX.Y.Z
4. Push to origin
