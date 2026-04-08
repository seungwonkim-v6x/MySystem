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

### 1d. Build task prompt with embedded methodology

The coordinator MUST read the relevant gstack skill file and extract its methodology into the task prompt. Scion agents (Gemini, Codex) cannot access gstack skills — the methodology must be inlined.

**Process:**
1. Identify which skill this step maps to (e.g., /investigate, /review, /bugbot, /office-hours, /slow-down, etc.)
2. Read the skill's SKILL.md from `~/.claude/skills/<skill-name>/SKILL.md`
3. Extract the key methodology sections (phases, steps, evaluation criteria, output format)
4. Build a self-contained prompt that includes:
   - The user's task description
   - The extracted methodology as instructions ("Follow these phases: ...")
   - The structured output format from the skill
   - For review/bugbot: append `git diff main...HEAD` (truncated to 50KB)

**Example for /investigate:**
```
Investigate the root cause of this bug: <user's bug description>

Follow this methodology:
Phase 1 — Investigate: Gather evidence. Read error logs, trace code paths, identify the exact point of failure.
Phase 2 — Analyze: Map the control flow. What triggers the bug? What are the preconditions?
Phase 3 — Hypothesize: Form 2-3 hypotheses. Rank by likelihood. Identify what evidence would confirm/deny each.
Phase 4 — Root Cause: State the root cause with evidence. No fixes without root cause.

Output format:
  ROOT_CAUSE: <one sentence>
  EVIDENCE: <what you found that proves it>
  LOCATION: file/path:line_number
  FIX: <recommended fix>
```

The local Claude agent also gets this same prompt — consistency across all 4 agents makes synthesis easier. The local agent additionally has conversation context and gstack skills, giving it an edge.

### 1e. Generate run ID

```bash
TS=$(date +%s)
```

All Scion agent names use this timestamp suffix to prevent collisions: `review-claude-$TS`, `review-gemini-$TS`, `review-codex-$TS`.

## Step 2: Spawn (4 agents in parallel)

Use the prompt built in Step 1d. All 4 agents get the same prompt (methodology + task + output format). Then spawn simultaneously.

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
