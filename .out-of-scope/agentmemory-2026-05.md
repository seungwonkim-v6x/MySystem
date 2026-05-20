# Out of scope: adopting `rohitg00/agentmemory` (2026-05)

**Decision date:** 2026-05-20
**Status:** Rejected (pure-reject; not deferred, not partial)
**Considered during:** v0.38.0 release planning
**Replaced by:** Activating gbrain as an experimental retrieval sidecar — see [ADR-0008](../docs/adr/0008-gbrain-as-memory-layer.md)

## TL;DR

User asked: "https://github.com/rohitg00/agentmemory — anything to adopt
into MySystem?" After /office-hours + /deep-research + /autoplan with 4
reviewer voices (CEO subagent, CEO codex, Eng subagent, Eng codex), the
answer is **no**. Pure reject. Adopt gbrain instead, since MySystem's
existing gstack already cites gbrain in every skill preamble and the layer
was just dormant.

## What agentmemory is

A persistent memory system for AI coding agents — 14.2k stars, Apache-2.0,
TypeScript, actively maintained (pushed daily). Installs as an npm package
(`@agentmemory/agentmemory`) on Node ≥20 with an iii-engine native binary
dependency. Ships with:

- 12 Claude Code lifecycle hooks (SessionStart, UserPromptSubmit,
  PreToolUse, PostToolUse, PreCompact, Stop, etc.) for zero-effort capture.
- 51 MCP tools + 4 skills (`/recall`, `/remember`, `/session-history`,
  `/forget`).
- Triple-stream retrieval (BM25 + vector + knowledge graph) with RRF fusion.
- 4-tier "sleep consolidation" taxonomy (Working / Episodic / Semantic /
  Procedural) with Ebbinghaus-curve decay.
- Bidirectional CLAUDE.md sync via `memory_claude_bridge_sync`.
- Real-time viewer on :3113 + iii console on :3114.
- Claimed LongMemEval-S retrieval recall@5: 95.2%.

## Why reject

### 1. Real choice was activating gbrain, not adopting a new tool

MySystem's `gstack` (already trusted, ADR-0001 consolidation) cites
**gbrain** in every skill preamble's "Artifacts Sync" + "GBrain Search
Guidance" sections. Before v0.38.0 those branches were dormant only
because `~/.gbrain/config.json` didn't exist on this machine. Activating
the designed default beats adding a parallel memory system.

### 2. Benchmark advantage doesn't exist

| | agentmemory | gbrain |
|---|---|---|
| Stars | 14,215 | 17,547 |
| Maintainer | rohitg00 (new trust surface) | Garry Tan (= gstack maintainer, transitive trust) |
| License | Apache-2.0 | MIT |
| Recall@5 | 95.2% (LongMemEval-S) | **97.9%** (BrainBench, gbrain-evals) |
| Precision@5 | not stated | 49.1% |
| Hooks installed | **12** | 0 (config-only activation) |
| Bidirectional CLAUDE.md sync | yes (RISK) | no (by design) |
| External runtime | Node ≥20 + iii-engine binary | Bun ≥1.3.10 (already required by gstack) |

gbrain wins on retrieval, supply-chain trust, hook surface, and config
discipline. Same maintainer as the rest of the workflow.

### 3. Six-dimension gap analysis: no genuine unmet need

Deep-research /office-hours phase ran a 6-dimension gap analysis:

| # | agentmemory feature | gbrain coverage | MySystem implication |
|---|---|---|---|
| 1 | Per-tool-call auto-capture via 12 hooks | PARTIAL — per-message signal-detector inside agent loop; MCP-only | No action. Per-tool-call grain explodes noise; learning-opportunities already capped at 2/session for similar reason. |
| 2 | 4-tier time-decay (Working/Episodic/Semantic/Procedural) | PARTIAL — temporal versioning via `valid_from`/`valid_until` + `consolidate` cycle | No action. MySystem already tiers via CLAUDE.md (procedural) + ADRs (semantic) + plans/ (episodic) + /compact (working). |
| 3 | Privacy filter on memory writes | PARTIAL — `shell-redact.ts`, MCP request log redaction, `harvest-lint.ts` | No action. v0.35.0 PreToolUse secret-scanner already catches at file-write boundary. |
| 4 | Bidirectional CLAUDE.md sync | NO (read-only by design) | Actively unwanted. CLAUDE.md is hand-curated workflow contract; programmatic mutation violates v0.36.0 instruction-precedence ladder. |
| 5 | Multi-agent leasing (`memory_lease`) | NO | Not a current pain — MySystem runs one CC session at a time. Re-evaluate if Conductor workspaces become real. |
| 6 | Real-time viewer + OTEL traces | YES — `gbrain serve --http` + `/admin` dashboard + SSE feed | gbrain admin is enough for solo workflow. |

**Verdict: 0 NOs that matter. 1 NO (#4) is anti-pattern for MySystem.**

### 4. Adoption cost is asymmetric

Adopting agentmemory means:

- 12 new lifecycle hooks under a new maintainer = 12× the SHA-pin review
  burden of gbrain under Garry Tan (already trusted transitively via
  gstack). Per ADR-0005/0007, autonomous-invoked code requires SHA pinning
  + quarterly review.
- iii-engine native binary = additional install + version coupling.
- Bidirectional CLAUDE.md sync would silently mutate the workflow contract
  from level-9 retrieved content. v0.36.0 hardening was designed to
  prevent exactly this.
- Runtime: separate Node 20+ runtime, plus :3113 viewer process, plus
  iii-engine. gbrain is in-process PGLite, no daemons.

### 5. Conversation-layer gap (user feedback during autoplan)

Mid-autoplan, the user clarified the actual value gbrain fills that no
other layer captures: **conversation / decision-flow / reasoning capture.**
Existing layers all miss this:

| Existing layer | Captures | Misses |
|---|---|---|
| auto-memory | user/feedback facts | session back-and-forth |
| gstack artifacts | frozen design docs/plans/reviews | rejected-option reasoning |
| learnings.jsonl | agent-observed patterns | user reframes / interjections |
| timeline.jsonl | mechanical skill log | why a skill was chosen |
| ADRs + CLAUDE.md | hand-curated decisions | sub-ADR decisions |
| references/ | external read-only | session-generated content |
| CONTEXT.md | per-project glossary | cross-session reasoning |

gbrain's signal-detector + put-page + search closes this gap as a
**capture-first** layer. agentmemory aims at the same gap but pays a much
higher supply-chain + hook-surface cost to do it.

## Re-evaluation triggers (when to reopen this)

Don't reopen this decision unless:

- gbrain becomes unmaintained (Garry Tan leaves gstack/gbrain, upstream
  silent >90 days). At that point ADR-0008's K2 kill trigger fires and
  this rejection should be re-evaluated alongside any other memory layer
  option.
- Anthropic ships native semantic memory with comparable conversation-layer
  capture, making both gbrain AND agentmemory legacy ballast. K3 kill
  trigger fires; this rejection naturally becomes moot.
- A specific agentmemory feature emerges that genuinely has no gbrain
  equivalent AND solves a real MySystem pain. Document the feature + the
  pain in a new `.out-of-scope/` entry and run a fresh /office-hours.

Do NOT reopen because:

- agentmemory adds new MCP tools or hooks. Surface area growth isn't a
  reason to adopt.
- agentmemory passes some new benchmark. Retrieval benchmark deltas under
  3 points are noise at this scale.
- A blog post claims agentmemory has surpassed gbrain. Independent
  benchmark evidence required.

## Related decisions

- [ADR-0008](../docs/adr/0008-gbrain-as-memory-layer.md) — what we did
  instead.
- [ADR-0005](../docs/adr/0005-plugin-marketplace-for-hook-bearing-plugins.md) — supply-chain
  trust gradient. agentmemory's 12 hooks would violate the SHA-pin
  discipline at scale.
- [ADR-0007](../docs/adr/0007-skill-cherry-pick-batch-v0.37.md) —
  SHA-pin amendment. Demonstrates the cost of per-skill pinning at 4
  autonomous skills; 12 hooks would 3× that cost.
- `learning-opportunities` plugin (v0.33.0) — accepted; demonstrates
  that we're not anti-plugin. Plugins fitting the workflow get adopted;
  this one didn't fit.
