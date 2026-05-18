# ADR-0003: References — local treasure trove over web search

- **Status**: Accepted
- **Date**: 2026-05-17
- **Author**: seungwon-v6x
- **Tags**: knowledge, references, agent-behavior

## Context

For recurring questions ("how do consistent-hashing schemes degrade under skew?", "what time-zone falsehoods will bite us?", "what does Atlassian's design system pattern look like?") the agent was defaulting to `WebSearch` every time. Two problems: (1) it burns context discovering the same canonical sources repeatedly; (2) high-leverage knowledge bases (papers-we-love, awesome-falsehood, system-design-primer, awesome-design-md) have organized this material once already — re-searching is waste.

mattpocock-style external skill libraries solve the *skill* surface but not the *knowledge* surface. A third install mechanism, distinct from `SPARSE_SKILLS` (which symlinks into `skills/`), is needed for read-only knowledge that the agent greps but does not invoke.

## Decision

We will add `REFERENCE_REPOS` to `setup.sh`. Format: `"local-name|url|branch"`. Each entry clones the upstream repo into `references/<local-name>/` (git-ignored cache). **No symlinks, no skill registration** — these are read-only knowledge bases the agent greps when a relevant question lands. A tracked `references/INDEX.md` catalogs each repo with a "use when" hook so the agent knows when to consult.

CLAUDE.md gains a "Consult references before searching the web" operating principle: for the listed domains (system design, distributed systems papers, schema/validation hazards, design systems, AI agent patterns), grep `references/` first; only then fall back to web search.

Boundary: this is for *general-purpose curated knowledge*, not project-specific docs (those belong in the project repo) and not for skills (those go through `SPARSE_SKILLS` / `EXTERNAL_REPOS`).

## Alternatives considered

- **A: Keep relying on `WebSearch` + cache mental** — rejected because each new conversation pays the same rediscovery cost
- **B: Vendor PDFs / docs into MySystem directly** — rejected because git is a poor binary store; ~640MB across 12 repos would be tracked content with no upstream sync
- **C: Use a vector store / RAG layer** — rejected because grep is fast, deterministic, and zero infra; vector stores add a moving part with marginal benefit for this use case

## Consequences

- ✓ Recurring questions hit local content first; web search becomes the fallback path it should be
- ✓ References stay current via `git pull` per upstream
- ✓ `references/INDEX.md` is a forcing function: any new reference repo needs an explicit "use when" hook to be findable
- ✗ Disk cost ~640MB at v0.31.0 (12 repos); will grow as more references are added
- ✗ Upstream rename / sunset for any indexed repo would leave a dead clone until manually cleaned
- ? Whether the agent will actually prefer local grep over `WebSearch` in practice; the CLAUDE.md rule is necessary but not sufficient

## References

- CHANGELOG: v0.31.0
- Code: `setup.sh:46-60`, `references/INDEX.md`
