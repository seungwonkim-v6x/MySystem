# ADR-0010: /deep-research free stack — exa-only (crawl4ai wrapper rejected)

- **Status**: Accepted
- **Date**: 2026-05-29
- **Author**: seungwon-v6x
- **Tags**: skills, mcp, research-tooling, supply-chain

<!-- mysystem:managed-start (intentionally empty — reserved for future tooling) -->
<!-- mysystem:managed-end -->

## Context

`/deep-research` (external sparse-cherry-picked skill from affaan-m/everything-claude-code)
leaned on the firecrawl MCP. Firecrawl is a paid, credit-gated managed API; its credits ran
out, and `/deep-research` is used continuously, so the credit wall is a recurring hard stop.
Goal: run `/deep-research` for $0 with no credit-card exposure.

The skill is provider-agnostic ("at least one of firecrawl / exa"), and exa covers both
search (`web_search_exa`) and deep-read (`web_fetch_exa` in current `exa-mcp-server@3.2.1`;
the upstream skill body still calls `crawling_exa`, which exa keeps working as a deprecated
alias for the same endpoint). exa has a perpetual free tier (1,000 req/mo, no card).
Registering exa therefore already removes the firecrawl dependency.

A richer option (Approach B) was explored: keep exa for search but offload the request-heavy
scrape step to a local crawl4ai container (free, unlimited) behind a thin user-owned wrapper
skill, to conserve the exa free-tier budget.

## Decision

We will run `/deep-research` on **exa-only (Approach A)**. exa MCP is registered at user
scope in `~/.claude.json`, pinned to `exa-mcp-server@3.2.1` (was floating `npx exa-mcp-server`;
firecrawl was already pinned `@3.17.0` — this removes the inconsistency). No crawl4ai, no
wrapper skill, no MCP container, no `skillOverrides`.

Boundary: this does NOT build the crawl4ai stack (B). It does not modify the upstream
`/deep-research` skill body. It does not remove firecrawl (left registered but unused/out of
credits; harmless).

## Alternatives considered

- **A: exa-only** — CHOSEN. Solves the stated problem (firecrawl wall) at zero build, zero
  standing infra. Makes no enforcement promise a prompt cannot keep.
- **B: exa search + crawl4ai scrape via a thin wrapper skill** — rejected. office-hours
  premise challenge + autoplan dual-voice review (CEO 6/6 and Eng 6/6 consensus, Codex
  gpt-5.5 + Claude subagent) found it (1) over-scoped — it optimizes an unmeasured exa cap
  (~50→~100 researches/mo for one solo user) with no evidence usage approaches it; and (2)
  structurally unbuildable as a "thin wrapper": provider-routing and the exa-budget guard are
  prose in a SKILL.md, not enforceable (violates "harness, not model"); a wrapper delegating
  to an unpinned upstream skill does not compose (upstream hardcodes its tools, no extension
  point); and the durability mechanism (`skillOverrides`) was an unverified assumption.
- **C: built-in WebSearch + crawl4ai** — rejected. Removes the exa cap entirely but needs a
  more invasive skill-logic change and trades exa's neural search quality for keyword search,
  with no measured benefit for solo use.

## Consequences

- ✓ `/deep-research` works for $0 today via exa, within the 1,000 req/mo free tier. At
  ~20 req/research that cap is ≈50 researches/mo — that is the ceiling, not the expected load;
  realistic solo use (a few researches/week) sits well under it. No credit-card exposure.
- ✓ Zero standing infrastructure and no new running services. The only new secret is the exa
  API key stored at rest in `~/.claude.json` (same trust posture as the existing firecrawl key;
  free-tier, no card). Aligns with the "prefer native / harness-don't-build" and
  system-weight-trim operating principles.
- ✗ exa's free tier is a real ceiling. If a future month genuinely exceeds it, more research
  capacity is not free.
- ? Betting that solo usage stays well under the 1,000 req/mo cap. **Revisit trigger:** if a
  month crosses ~700 exa req (70% of cap), build **B-real** — a deterministic local
  fetch-proxy / MCP shim that owns provider routing, fallback, content validation, and
  concurrency locking *in code* (plus a forked/vendored upstream), NOT a prose wrapper. Do not
  re-attempt the thin-wrapper B; the review already showed it cannot enforce its own value
  proposition. **How to measure:** there is no local request counter today — read the usage
  page at dashboard.exa.ai during `/retro` or a monthly check.

## References

- Related ADR: ADR-0007 (skill cherry-pick + SHA-pin mechanism; deep-research is unpinned there)
- Design doc: `~/.gstack/projects/seungwonkim-v6x-MySystem/seungwonkim-main-design-20260529-174212-deepresearch-free-stack.md`
- Code/config: `~/.claude.json` (exa MCP, pinned `exa-mcp-server@3.2.1`)
- crawl4ai image kept on disk (`unclecode/crawl4ai@sha256:a45fd08f…`, v0.8.6) as the optional future tool for B-real.

## How this file is maintained

- ADR numbering is monotonic per project. Don't reuse numbers; mark superseded instead.
- Rewrite history only by adding a new ADR that supersedes the old one.
- An ADR is deliberate. Don't auto-generate from PR descriptions.
