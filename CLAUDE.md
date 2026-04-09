# MySystem — Personal Workflow

This file defines the **complete workflow** that applies to all projects.

**CRITICAL RULE: The agent has ZERO discretion to skip or reorder steps.**
Every step below is MANDATORY and runs in order.
- NEVER skip a step on your own.
- NEVER reorder steps. Step N must complete before step N+1 begins.
- NEVER write code before /slow-down and /autoplan are done. NOT EVEN ONE LINE.
- NEVER ask the user "should we skip?" or "do you want to run the full workflow?"
- NEVER suggest skipping. Just run the next step immediately.
- If the user wants to skip, THEY will interrupt you. That's their job, not yours.

**CRITICAL RULE: NEVER proceed to the next workflow step without explicit user approval.**
After presenting ensemble results, STOP and wait. Do not say "proceeding to next step".
The user must explicitly say "ok", "approved", "next", "go" or similar before you move on.

---

## Ensemble Execution Rule

**Every workflow step** (except Implementation and /ship) MUST be executed as an ensemble:

### Subagent Execution Model

Subagents are defined in `~/.claude/agents/` as markdown files with frontmatter. Each subagent has its own model, tools, permissions, and **preloaded skills** (via `skills:` frontmatter — the skill methodology is loaded into the subagent's context at startup, so it does NOT need to read SKILL.md files).

The coordinator invokes subagents via the **Agent tool** with `subagent_type` parameter:
```
Agent(subagent_type: "code-reviewer", prompt: "<full task context>")
```

The `prompt` string is the **ONLY channel** from coordinator to subagent. The subagent does NOT receive the coordinator's conversation history. All task context must be in the prompt.

### Execution Steps

1. **Spawn 3 subagents** in a **single message** (all 3 as parallel Agent tool calls)
   - Use `subagent_type` to invoke the correct custom agent (e.g., `"investigator"`, `"code-reviewer"`)
   - The `prompt` MUST include the full task description with all relevant context
   - For standard ensemble: same subagent_type x3 with varied angles in prompt
   - For /autoplan: different subagent_type per agent (ceo-reviewer, design-reviewer, eng-reviewer)

2. **WAIT FOR ALL** — NEVER synthesize or present results until every subagent has returned
   - Do NOT proceed after 1 or 2 agents return. Wait for ALL 3 subagents.
   - All 3 subagents are non-negotiable. No partial results.

3. **Synthesize** — after ALL 3 agents return:
   - Deduplicate overlapping findings
   - Flag disagreements prominently
   - Rank by severity/importance
   - Present **one unified report** to the user

4. **STOP** — present the report and **wait for explicit user approval** before the next workflow step.

**Total: 3 perspectives** — 3 custom subagents, each with preloaded skill methodology.

### Available Custom Subagents

| subagent_type | Preloaded skills | Used in |
|---------------|-----------------|---------|
| `investigator` | investigate | /investigate |
| `researcher` | search-first, documentation-lookup | /research |
| `ceo-reviewer` | plan-ceo-review | /autoplan |
| `design-reviewer` | plan-design-review | /autoplan |
| `eng-reviewer` | plan-eng-review | /autoplan |
| `code-reviewer` | review | /review |
| `bug-hunter` | bugbot | /bugbot |

Steps without a dedicated subagent (/office-hours, /slow-down, /verify-test) use `Agent(model: "opus")` with inline prompt referencing the skill file.

---

## Complete Workflow

### Feature / Bug Fix / Refactoring

Every code task goes through ALL 9 steps, in order:

```
1. /office-hours         ← validate the idea or problem (ensemble)
       ↓  (wait for user approval)
2. /slow-down            ← concretize: problem, done criteria, scope, pre-mortem, approach (ensemble)
       ↓  (wait for user approval)
3. /research             ← search docs, codebase, existing solutions (ensemble)
       ↓  (wait for user approval)
4. /autoplan             ← plan review: 3 subagents = CEO + Design + Eng (role-based ensemble)
       ↓  (wait for user approval)
5. Implementation        ← write code — coordinator directly (no ensemble)
       ↓  (wait for user approval)
6. /verify-test          ← generate throwaway tests, run, delete (ensemble)
       ↓  (wait for user approval)
7. /review               ← PR code review: security, SQL safety, structure (ensemble)
       ↓  (wait for user approval)
8. /bugbot               ← fresh-eye bug review of the diff (ensemble)
       ↓  (wait for user approval)
9. /ship                 ← commit, push, create PR
```

### Debugging

```
1. /investigate          ← root cause analysis (ensemble)
       ↓  (wait for user approval)
2. /slow-down            ← concretize the fix (ensemble)
       ↓  (wait for user approval)
3. /research             ← search docs, similar issues, existing patterns (ensemble)
       ↓  (wait for user approval)
4. /autoplan             ← plan the fix: 3 subagents = CEO + Design + Eng (role-based ensemble)
       ↓  (wait for user approval)
5. Implementation (coordinator direct) → /verify-test → /review → /bugbot → /ship
```

### Weekly Retrospective

```
/retro                   ← commit history analysis, team contributions, trends (ensemble)
```

---

## Step Details

Each step: coordinator spawns custom subagents (defined in `~/.claude/agents/`) → each subagent reads its SKILL.md and runs the full methodology internally → coordinator waits for ALL → synthesizes → presents → waits for user approval.

| Step | Subagent(s) to use | Notes |
|------|--------------------|-------|
| /investigate | 3x `investigator` (varied angles) | 4-phase root cause methodology |
| /office-hours | 3x generic (varied angles) | Skill: `~/.claude/skills/office-hours/SKILL.md` |
| /slow-down | 3x generic (varied angles) | Skill: `~/.claude/skills/slow-down/SKILL.md` |
| /research | 3x `researcher` (varied angles) | Research-before-coding workflow |
| /autoplan | `ceo-reviewer` + `design-reviewer` + `eng-reviewer` | Role-based (see below) |
| Implementation | Coordinator runs directly (no ensemble) | Project-specific lint, test, etc. |
| /verify-test | 3x generic (varied angles) | Skill: `~/.claude/skills/verify-test/SKILL.md` |
| /review | 3x `code-reviewer` (varied angles) | Security, SQL safety, structure |
| /bugbot | 3x `bug-hunter` (varied angles) | Fresh-eye bug review |
| /ship | Run directly — without ensemble | |

### /autoplan — Role-Based Ensemble

/autoplan is the ONE exception to the standard ensemble pattern. Instead of 3 agents running the same skill with varied angles, each agent runs a **different** custom subagent:

| Subagent file | Role |
|---------------|------|
| `~/.claude/agents/ceo-reviewer.md` | CEO/founder-mode: scope, ambition, strategy |
| `~/.claude/agents/design-reviewer.md` | Designer's eye: UI/UX scoring 0-10 |
| `~/.claude/agents/eng-reviewer.md` | Eng manager: architecture, edge cases, performance |

All 3 spawn in parallel (single message). Coordinator waits for ALL 3, synthesizes, presents, waits for user approval.

### Implementation — Coordinator Direct

The coordinator runs Implementation directly (no subagents). Only the coordinator has file write permissions. Project-specific CLAUDE.md defines lint, test, and other checks.

---

## Subagent Permission Rules

Subagents spawned by ensemble execution use read-only permissions by default:

```yaml
tools: Read, Grep, Glob, Bash
permissionMode: dontAsk
```

Only the **main coordinator agent** may:
- Edit or Write files
- Run git commit, push, reset, or any git write operations
- Create PRs or interact with external services

Subagents for /verify-test get extended permissions (Write to /tmp only):
```yaml
tools: Read, Grep, Glob, Bash, Write
permissionMode: dontAsk
# Write restricted to /tmp/ via PreToolUse hook
```

---

## Repo Self-Management Rules

When modifying this repository (MySystem), the agent MUST:

1. **Bump VERSION** — follow semver (major: breaking workflow change, minor: new skill/step, patch: fix/tweak)
2. **Update CHANGELOG.md** — add entry under new version with date and description
3. **Git tag** — create `vX.Y.Z` tag matching the VERSION file
4. **Sync skill files** — skill files are managed as **symlinks**, never copied. Use `ln -s` to link.
5. **Push to origin** — push commits and tags
