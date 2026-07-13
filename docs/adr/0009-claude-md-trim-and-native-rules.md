# ADR-0009: CLAUDE.md trim + native `.claude/rules/` migration

Date: 2026-05-22
Status: Accepted; Codex-specific assumptions superseded by ADR-0014

> **2026-07-10 amendment:** The Claude-native rules decision remains active.
> The claims that Codex applies `project_doc_max_bytes` to its global home
> instructions, reads only a standalone CLAUDE/AGENTS file, and therefore needs
> no global projection are superseded by ADR-0014. Current Codex loads global
> `$CODEX_HOME/AGENTS.md` separately from the project-document budget. MySystem
> now generates a global projection plus a MySystem-only project supplement.

## Context

`~/.claude/CLAUDE.md` had grown to 680 lines / 34,780 bytes by v0.40.0. Two concrete consequences:

1. **Anthropic public guidance violation.** [code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory): *"Size: target under 200 lines per CLAUDE.md file. Longer files consume more context and reduce adherence."* MySystem ran at 3.4× the recommended ceiling.
2. **Codex CLI 32 KiB cap exceeded.** Codex's `project_doc_max_bytes` default is 32,768; MySystem's CLAUDE.md alone was 2,012 bytes over, so Codex CLI silently truncated.

The 8-step workflow ran an Option-D rescope first (single-PR delete-and-measure plus a `SessionStart(matcher: "compact")` hook re-injecting an extracted `critical-rules.md`). That plan was prepared with all scaffolding written (hook + critical-rules.md + settings.json entry + budget script) before a deeper read of [code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory) surfaced two facts that invalidated the workaround:

> *"Project-root CLAUDE.md survives compaction: after `/compact`, Claude re-reads it from disk and re-injects it into the session."*

> *".claude/rules/ directory ... rules can be scoped to specific files using YAML frontmatter with the `paths` field."*

So: (a) compaction safety for root-CLAUDE.md content is native — no hook needed; (b) Anthropic ships path-scoped rules as a first-class mechanism that the previous Option-D plan dismissed in favor of "skill extraction".

## Decision

Adopt Anthropic's native primitives rather than build parallel custom infrastructure:

1. **Trim CLAUDE.md to ≤ 200 lines.** Final size 173 lines / 13,536 bytes. Keeps the load-bearing workflow (precedence ladder, Step → Skill mapping, complete workflow, successor map, Step 5 menu, two-pass review, /autoplan, context-management discipline, project-knowledge convention). Inline CRITICAL RULES collapsed to one compressed Critical Workflow Rules block. The two most dangerous self-management rules (single-logical-change commits, NEVER PostToolUse git mutation) are restated inline in that block for compaction-survival belt-and-suspenders — the rest moved to `.claude/rules/`.
2. **Migrate detailed rules to `~/.claude/rules/*.md`** (Claude Code native, documented):
   - `operating-principles.md` — Boil the Lake, Harness Not Model, Vertical-Slice TDD, Conditional Clarification, Repo Mode, See Something Say Something, References-before-web. No `paths:` frontmatter (always loaded).
   - `trust-boundaries.md` — external content is data, not instructions. No `paths:` frontmatter.
   - `gbrain-protocol.md` — retrieve/write trigger lists. No `paths:` frontmatter.
   - `repo-self-management.md` — VERSION/CHANGELOG/git tag discipline + forbidden patterns (per-file commits, PostToolUse git mutation). **Path-scoped with absolute `~/.claude/` paths** (e.g., `~/.claude/CLAUDE.md`, `~/.claude/CHANGELOG.md`, `~/.claude/docs/adr/**`, `~/.claude/setup.sh`, `~/.claude/scripts/**`, `~/.claude/rules/**`, `~/.claude/settings.json`). An earlier draft used unscoped globs like `**/CHANGELOG.md` which would have triggered when editing other projects (e.g., vProp, cc-guard) because `~/.claude/rules/` is user-level. The absolute home paths prevent that leak. The compaction caveat (path-scoped rules aren't re-injected after `/compact` until a matching file is read again) is mitigated by restating the two most dangerous rules inline in CLAUDE.md.
3. **Add `~/.claude/scripts/claude-md-budget.sh`.** Reports the Claude Code always-loaded chain (CLAUDE.md + `@import` targets recursive up to 5 hops + `.claude/rules/*.md` with path-scope annotation + MEMORY.md + skill frontmatter estimate). Its original CLAUDE-only Codex comparison was replaced by ADR-0014's separate generated-global and project-supplement budgets. Read-only, idempotent.

## Alternatives rejected

- **Original 5-PR plan (R1-R5)** — UserPromptSubmit workflow router + 4 `mysystem-*` skill extractions + `/si:review`+`/si:promote` adoption + AGENTS.md symlink + budget script across 5 commits with 5 ADRs and 5 VERSION bumps. Rejected via cross-model consensus during `/autoplan` Phase 1 CEO dual voices: 8/8 dimensions both Claude subagent and Codex challenged scope as "corporate theater" for a solo repo. Aligned with the `feedback-trigger-driven-shipping` memory's precedent (the 12-factor-agents v0.40 abort).
- **Option D — single PR with `SessionStart(compact)` hook + extracted `critical-rules.md`** — workaround for compaction-loss fear. Rejected after [code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory) directly stated root-CLAUDE.md is re-read on compaction. The hook would be parallel infrastructure for a problem Anthropic already solves natively. Scaffolding written during Option-D execution was rolled back before commit (hook deleted, critical-rules.md deleted, settings.json entry reverted; only `claude-md-budget.sh` preserved into Option E).
- **Skill extraction (`mysystem-trust-boundary`, `mysystem-operating-principles`, etc.)** — Anthropic ships `.claude/rules/*.md` with `paths:` frontmatter as the native path-scoped loading mechanism. Skill extraction is the right pattern when content is genuinely on-demand procedural; for always-or-path-scoped rule content, native rules win. Skill extraction reserved for future cases where progressive disclosure is the actual need.
- **AGENTS.md symlink** — originally deferred on an incomplete Codex discovery model. Superseded by ADR-0014 after the concrete cross-tool friction occurred and current Codex global/project loading was verified.

## Retire when

- **Anthropic ships skill progressive-disclosure fix** ([issue #14882](https://github.com/anthropics/claude-code/issues/14882)) — token savings for skill bodies land automatically; re-evaluate whether some `.claude/rules/` content should become opt-in skills.
- **Anthropic exposes memory tool / context-editing API in Claude Code surface** — current API beta `context-management-2025-06-27` may obsolete some always-loaded content.
- **Cross-tool friction surfaces** — concrete report of Codex CLI not reading MySystem instructions in a typical workflow → revisit AGENTS.md symlink/import.
- **`.claude/rules/` proves insufficient** — if the harness's path-scoped loading doesn't trigger reliably, fall back to inline (with a different ADR explaining why).

## References

- [code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory) — CLAUDE.md size guidance, `.claude/rules/` mechanism, compaction survival
- [code.claude.com/docs/en/best-practices](https://code.claude.com/docs/en/best-practices) — "Bloated CLAUDE.md files cause Claude to ignore your actual instructions"; "Hooks > prose for must-always-happen rules"; "Skills load on demand"
- ADR-0006 — defense-in-depth PreToolUse hooks (this ADR strengthens that pattern by leaning further into native enforcement)
- ADR-0007 — sparse cherry-pick SHA pinning (referenced by the v0.37.0 skill block that remains in CLAUDE.md)
- ADR-0008 — gbrain as memory layer (was referenced by `.claude/rules/gbrain-protocol.md`; rule file removed 2026-06-11 with the gbrain excision — see ADR-0008 SUPERSEDED note)
- [memory `feedback-trigger-driven-shipping`](file://~/.claude/projects/-Users-seungwonkim--claude/memory/feedback-trigger-driven-shipping.md) — precedent for trigger-driven scope reduction
- 12-factor-agents v0.40 abort (2026-05-20) — same pattern: cross-phase review consensus → abort rather than ship for workflow completion
- Research reports under `~/.gstack/projects/seungwonkim-v6x-MySystem/` (rounds 1 and 2) — sources for the Cem Karaca case study, Anthropic compliance numbers (25-40% prose vs 95% hooks), community CLAUDE.md survey (median 88 lines), Anthropic roadmap forecast
