---
name: scion-ensemble
description: "Spawn a 4-agent multi-model ensemble (1 local Claude + 3 Scion containers: Claude/Gemini/Codex) for ANY workflow step. Collects results, synthesizes consensus/unique/disagreements. Invoke with /scion-ensemble."
---

# /scion-ensemble — Multi-Model Ensemble Execution

Spawn 4 independent AI agents across 3 vendors for epistemic diversity.
One local Claude (full project context) + three Scion containers (Claude Opus, Gemini 2.5 Pro, Codex).
Each independently executes the same task. Results are collected, deduplicated, and categorized.

## When to Run

1. **Automatic**: Every workflow step (except /ship) invokes this skill via CLAUDE.md
2. **Manual**: User invokes `/scion-ensemble` with a task description
3. **Scope**: All steps — diff-based (review, bugbot) AND non-diff (investigate, office-hours, research, etc.)

## Step 1: Pre-flight

Check infrastructure and working tree before spawning agents.

### 1a. Health check

Run these checks. If ANY fail, fall back to local-only ensemble (Step 2 fallback).

```bash
which scion >/dev/null 2>&1 || { echo "FALLBACK: scion not found"; exit 1; }
docker info >/dev/null 2>&1 || { echo "FALLBACK: Docker not running"; exit 1; }
```

If health check fails, warn the user: "Scion unavailable — falling back to local-only Agent tool ensemble."
Then spawn 3 local Claude Agent tool subagents (model: sonnet) with paraphrased task variations instead. This is the old MySystem behavior. Skip Steps 2-7 for Scion agents.

### 1b. Stash dirty working tree

```bash
if [ -n "$(git status --porcelain)" ]; then
  git stash push -m "scion-ensemble-wip"
  echo "STASHED=true"
fi
```

Record whether a stash was made — needed for Step 7.

### 1c. Clean up stale agents

Check for leftover agents from a prior crashed run:

```bash
scion list --format json 2>/dev/null
```

If any agents matching the current step prefix exist (e.g., `review-claude-*`, `review-gemini-*`, `review-codex-*`), delete them:

```bash
scion delete <stale-agent-name> -y
```

### 1d. Prepare task prompt

Take the user's task description as-is. Scion agents have access to the full codebase via their git worktree — they can read files, grep, and explore independently. Do not try to pre-digest context for them.

For review/bugbot steps, optionally append `git diff main...HEAD` (truncated to 50KB) to help agents focus on the changed files. For all other steps, just pass the task.

### 1e. Generate run ID

```bash
TS=$(date +%s)
```

All Scion agent names use this timestamp suffix to prevent collisions: `review-claude-$TS`, `review-gemini-$TS`, `review-codex-$TS`.

## Step 2: Spawn (4 agents in parallel)

Build the task prompt from the user's task description. Then spawn all 4 agents simultaneously.

### Task prompt

Pass the same task to all 4 agents. Scion agents have full codebase access via their worktree. The local Claude agent has the current session context. No need to differentiate prompts — each agent approaches the task in its own way.

For structured output, append to the task:

```
For each finding, output in this format:
  SEVERITY: Critical | High | Medium | Low
  LOCATION: file/path:line_number
  DESCRIPTION: What is wrong / what you found
  FIX: How to fix it / recommendation
```

### Spawn all 4

Issue these in a single response (parallel execution):

**3 Scion containers** (via Bash tool, each a separate call):

```bash
scion start review-claude-$TS "<scion-prompt>" -t claude-oauth --no-auth -y
```

```bash
scion start review-gemini-$TS "<scion-prompt>" -t gemini-oauth --harness-auth auth-file -y
```

```bash
scion start review-codex-$TS "<scion-prompt>" --harness codex --harness-auth auth-file -y
```

**1 local Claude** (via Agent tool):

```
Agent(model: "sonnet", prompt: "<local-prompt>")
```

Track which Scion agents actually started (check exit codes). Record in `STARTED_AGENTS`.

**Auth note**: Claude uses template-based auth (`--no-auth -t claude-oauth`) because the Claude harness does not support `--harness-auth auth-file`. Gemini and Codex use native auth-file. This asymmetry is intentional.

## Step 3: Monitor

The local Agent tool returns its result directly — no polling needed.

For Scion agents, run the poll script:

```bash
QUORUM_MIN=2 MAX_TIMEOUT=600 ~/.claude/skills/scion-ensemble/bin/poll-agents.sh review-claude-$TS review-gemini-$TS review-codex-$TS
```

Check exit code:
- **0** = quorum met (2+ Scion agents completed). Proceed to Step 4.
- **1** = quorum failed. Warn user: "Only N/3 Scion agents completed. Partial results below."

Combined quorum: local Claude (always completes) + at least 2 Scion agents = 3/4 total.

## Step 4: Collect results

**Local Claude**: Result is already in context from the Agent tool response.

**Scion agents** — for each completed agent, run in parallel:

```bash
scion look review-claude-$TS --plain
```

```bash
scion look review-gemini-$TS --plain
```

```bash
scion look review-codex-$TS --plain
```

`--plain` strips ANSI escape codes natively. Skip any agent that timed out or failed.

Log which agents participated:
- `[Local-Claude]` — always present (rich context: gstack skills, CLAUDE.md, uncommitted changes, conversation history)
- `[Scion-Claude]` — clean-room, container-isolated
- `[Gemini]` — different model, different vendor
- `[Codex]` — different model, different vendor

## Step 5: Synthesize findings

Analyze all collected results. Extract structured findings (Severity, Location, Description, Fix) from each agent's output.

### Classification

**Consensus** (2+ agents reported the same issue at the same location):
- High confidence. Present first. Tag with agreeing agents.

**Unique catches** (only 1 agent found it):
- Tag with `[Local-Claude]` (rich context) or `[Scion-Claude]`/`[Gemini]`/`[Codex]` (clean-room)
- These demonstrate epistemic diversity — the whole point of the ensemble.

**Disagreements** (agents contradict each other about the same location):
- Present both sides with model attribution.
- The user decides which is right.

### Output format

```markdown
## Ensemble Review Results

**Agents**: Local-Claude + [list of Scion agents that completed] | Time: Xs
**Agents failed/timed out**: [list, or "none"]

### Consensus (N findings)
Findings where 2+ agents agree:
1. **[Severity]** `file:line` — description (agreed by: Local-Claude, Gemini)
   Fix: ...

### Unique Catches (N findings)
Findings only one agent caught:
1. **[Severity]** `file:line` — description `[Codex]`
   Fix: ...

### Disagreements (N)
1. `file:line` — Local-Claude says X, Gemini says Y

---
Total: N unique findings across M agents.
```

## Step 6: Cleanup

Delete all Scion agents that were started in this run:

```bash
scion delete review-claude-$TS review-gemini-$TS review-codex-$TS -y 2>/dev/null
```

Only delete agents in `STARTED_AGENTS`. The `-y` flag skips confirmation. Errors from non-existent agents are suppressed.

The local Agent tool needs no cleanup.

## Step 7: Post-flight

If a stash was made in Step 1b:

```bash
git stash pop
```

This restores the working tree to its original dirty state. Safe — no history mutation.

If no stash was made, skip this step.

## Rules

- **Always 4 agents** — 1 local Claude (Agent tool, sonnet) + 3 Scion containers (Claude, Gemini, Codex)
- **Self-contained Scion prompts** — Include the diff verbatim. Scion agents have NO conversation context.
- **Local agent has full context** — It reads files directly. Do NOT include the diff in its prompt.
- **Parallel execution** — Start all 4 simultaneously. Never sequential.
- **Timestamped names** — `<step>-<model>-<timestamp>` prevents concurrent run collisions.
- **Always cleanup** — Delete Scion agents even if the run fails or times out.
- **Always pop stash** — Restore working tree even if the run fails.
- **Quorum 3/4** — Local Claude + at least 2 Scion agents. Partial results with warning if quorum fails.
- **Structured output** — Agent prompts request Severity/Location/Description/Fix format for reliable synthesis.
- **Ensemble agents report only** — They never fix code. The coordinator decides what to fix.
- **All steps supported** — diff-based (review, bugbot) and non-diff (investigate, research, etc.) alike.
- **Fallback** — If Scion is unavailable, degrade to local-only Agent tool ensemble + warn user.
