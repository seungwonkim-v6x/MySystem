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

**CRITICAL RULE (Interactive mode): NEVER proceed to the next workflow step without explicit user approval.**
After presenting step results, STOP and wait. Do not say "proceeding to next step".
The user must explicitly say "ok", "approved", "next", "go" or similar before you move on.

---

## Subagent Execution Model

Subagents are defined in `~/.claude/agents/` as markdown files with frontmatter. Each subagent has its own model, tools, permissions, and **preloaded skills** (via `skills:` frontmatter).

**Invocation: Always call agents directly via `subagent_type`.**
```
Agent(subagent_type: "code-reviewer", prompt: "<task context>")
```
- The coordinator must NOT read skill content and re-inject it into the prompt.
- `subagent_type` automatically preloads the agent's defined skills.
- The `prompt` should contain only the task description and necessary context.

**WRONG — never do this:**
```
Agent(model: "opus", prompt: "You are a bug hunter. Review...")  # ignores agent definition
Agent(subagent_type: "bug-hunter", prompt: "<copy-pasted skill content>")  # unnecessary re-injection
```

### Available Subagents

| subagent_type | Used in step |
|---------------|-------------|
| `investigator` | /investigate |
| `office-hours` | /office-hours |
| `slow-downer` | /slow-down |
| `researcher` | /research |
| `ceo-reviewer` | /autoplan (phase 2) |
| `design-reviewer` | /autoplan (phase 2) |
| `eng-reviewer` | /autoplan (phase 2) |
| `test-verifier` | /verify-test |
| `code-reviewer` | /review |
| `bug-hunter` | /bugbot |

---

## Complete Workflow

### Feature / Bug Fix / Refactoring

Every code task goes through ALL 9 steps, in order:

```
1. /office-hours         ← 1x office-hours subagent
       ↓
2. /slow-down            ← 1x slow-downer subagent
       ↓
3. /research             ← 1x researcher subagent
       ↓
4. /autoplan             ← Phase 1: coordinator writes plan
                           Phase 2: ceo-reviewer + design-reviewer + eng-reviewer (3 in parallel)
       ↓
5. Implementation        ← coordinator directly
       ↓
6. /verify-test          ← 1x test-verifier subagent
       ↓
7. /review               ← 1x code-reviewer subagent
       ↓
8. /bugbot               ← 1x bug-hunter subagent
       ↓
9. /ship                 ← coordinator directly (always human-only)
```

### Debugging

```
1. /investigate          ← 1x investigator subagent
       ↓
2. /slow-down → /research → /autoplan → Implementation → /verify-test → /review → /bugbot → /ship
```

### Weekly Retrospective

```
/retro                   ← commit history analysis, team contributions, trends
```

---

## Interactive vs Ralph

Same workflow, same agents. The only difference is approval.

| | Interactive (human supervised) | Ralph (autonomous) |
|--|-------------------------------|-------------------|
| Workflow | Same 9 steps | Same 9 steps |
| Agents | Same subagent calls | Same subagent calls |
| Between steps | Human approval required | Auto-advance |
| /ship | Human executes | NEVER autonomous — human only |

### Ralph Loop (Autonomous Execution)

Ralph Loop plugin intercepts session exit via Stop Hook and re-injects the same prompt for autonomous iteration.

```bash
/ralph-start                # Start (skill builds prompt + calls ralph-loop)
/ralph-report               # Check results
/cancel-ralph               # Cancel
```

**Required safety measures**:
- `--max-iterations`: Always set (default 30, overnight 50)
- `--completion-promise`: Always set ("COMPLETE")
- /ship excluded: local commits only, push/PR always human
- Worktree isolation recommended: `git worktree add` for separate branches

---

## Step Details

### /autoplan — Two-Phase: Plan First, Then Review

**Phase 1: Write the plan**
1. Coordinator uses `EnterPlanMode` to explore the codebase and write a detailed implementation plan
2. Coordinator presents the plan via `ExitPlanMode`
3. Interactive: human approves before phase 2 | Ralph: auto-advance

**Phase 2: Review the plan with 3 role-based subagents**

3 subagents in parallel (role division, not ensemble):
```
Agent(subagent_type: "ceo-reviewer", prompt: "<full plan text>")
Agent(subagent_type: "design-reviewer", prompt: "<full plan text>")
Agent(subagent_type: "eng-reviewer", prompt: "<full plan text>")
```
Wait for ALL 3, synthesize, present.

### Implementation — Coordinator Direct

The coordinator runs Implementation directly (no subagents). Only the coordinator has file write permissions. Project-specific CLAUDE.md defines lint, test, and other checks.

---

## Subagent Permission Rules

Subagents use read-only permissions by default:
```yaml
tools: Read, Grep, Glob, Bash
permissionMode: dontAsk
```

Only the **main coordinator** may: Edit/Write files, git operations, PRs, external services.

Exception — `/verify-test` subagent gets Write (to /tmp only):
```yaml
tools: Read, Grep, Glob, Bash, Write
```

---

## Repo Self-Management Rules

When modifying this repository (MySystem), the agent MUST:

1. **Bump VERSION** — follow semver (major: breaking workflow change, minor: new skill/step, patch: fix/tweak)
2. **Update CHANGELOG.md** — add entry under new version with date and description
3. **Git tag** — create `vX.Y.Z` tag matching the VERSION file
4. **Sync skill files** — skill files are managed as **symlinks**, never copied. Use `ln -s` to link.
5. **Push to origin** — push commits and tags
