# ADR-0011: /deep-research vendored + provider-pluggable (inline table, judgment-guided)

- **Status**: Accepted
- **Date**: 2026-06-01
- **Author**: seungwon-v6x
- **Supersedes / amends**: ADR-0010 (exa-only free stack)
- **Tags**: skills, mcp, research-tooling, vendoring, provider-routing

<!-- mysystem:managed-start (intentionally empty — reserved for future tooling) -->
<!-- mysystem:managed-end -->

## Context

ADR-0010 moved `/deep-research` off firecrawl to exa-only, but only relocated the wall:
exa's free tier is 1,000 req/mo, and the skill stayed locked to one provider with no escape
hatch. The skill was also a **sparse cherry-pick**: `skills/deep-research` symlinked into an
untracked clone of `affaan-m/everything-claude-code` (ECC), so any local edit was clobbered by
`git pull --ff-only` on the next `setup.sh` — durable customization was structurally impossible
(the exact fact ADR-0010 named when it rejected a "thin wrapper"). The user wanted to plug in
arbitrary free crawlers / research SaaS (apify, Scrapling, crawl4ai, built-in WebSearch) by task.

## Decision

**Vendor the skill and make it provider-pluggable via an inline, judgment-guided provider
table in the single `SKILL.md`.**

1. **Vendored.** `skills/deep-research/` is now a tracked real directory (copied from ECC at
   upstream commit `64cd1ba248e77e377e76f70fc4e6434bfdddd511`, "fix: surface warn-only
   PreToolUse hooks (#2084)"). The `SPARSE_SKILLS` entry was removed; `.gitignore` whitelists
   `!skills/deep-research/` + `!skills/deep-research/**` (user-owned-skill pattern, mirroring
   verify-test). `agents/openai.yaml` (a Codex variant) was dropped as dead weight for a
   Claude-Code-only skill.
2. **Inline table, not a sibling file.** The provider registry is a markdown table inside
   `SKILL.md`. A sibling `providers.yaml` was rejected because only `SKILL.md` auto-loads into
   context when a skill runs — a sibling would force a mandatory `Read` every run (a failure
   point) for zero edit-convenience gain over a markdown row.
3. **Judgment-guided selection + deterministic safety rails.** The agent reads each provider's
   `best_for`/`cost` and picks the best fit per task (default: free built-in WebSearch/WebFetch;
   escalate to exa for neural depth, Scrapling/crawl4ai for bot-walled/JS, apify/firecrawl for
   managed scrape). Only the safety rails are deterministic: MCP-present check (tool must be in
   the active tool list; tool-not-found → skip, no retry), fetch-only rows never originate a
   search, auth errors STOP rather than silently swap, disabled rows are never auto-selected.
   This is the honest resolution of the reviewers' "prose routing isn't an integration layer"
   risk — we don't pretend it's deterministic; we make judgment explicit and rail the rest.

Boundary: this does NOT build the code shim (B-real). During implementation the user registered
Scrapling (free/OSS) + apify (user token) MCPs and enabled their rows; crawl4ai is documented-
but-off (not registered) and firecrawl is disabled (registered but out of credits). `~/.claude.json`
gained the Scrapling + apify MCP entries; the existing exa registration (`exa-mcp-server@3.2.1`,
ADR-0010) is unchanged. Note exa is now an on-demand escalation, NOT the default route (free
built-in is the default) — "exa stays registered" is not "exa is the hot path".

## Alternatives considered

- **Inline table (CHOSEN)** — owns the skill, free-by-default, one-row edit to swap an
  already-registered provider, no standing infra.
- **Separate `providers.yaml`** — rejected: doesn't auto-load, so it adds a per-run Read step
  for no gain; its only edge (machine-readable config for B-real) serves a deferred feature.
- **Strict priority-walk routing** — rejected per user direction: the user wants the model to
  read pros/cons and choose, not follow a rigid ladder. Reconciled by keeping safety rails
  deterministic while selection is judgment.
- **B-real (local MCP fetch-proxy/shim)** — still deferred. See revised trigger below.

## Consequences

- ✓ `/deep-research` is owned and customizable; edits survive `setup.sh` re-runs (the real
  protection is the removed `SPARSE_SKILLS` entry; an idempotency guard in the sparse loop is
  defense-in-depth for any future vendored skill). The `.git/info/exclude` regeneration loop now
  skips `deep-research` so the tracked dir is not re-excluded.
- ✓ Free-by-default: routine research uses built-in WebSearch/WebFetch ($0). exa/apify/firecrawl/
  Scrapling/crawl4ai are deliberate, by-fit escalations.
- ✗ Vendoring forks off ECC's active upstream (which just shipped a native `exa-search` skill).
  Maintenance is now self-owned; re-baseline manually against the recorded SHA if desired.
- ~ Provider rows now: `builtin`/`exa`/`scrapling`/`apify` are registered + enabled (Scrapling
  installed via `uv tool`, MCP at user scope; apify via npx stdio with a user `APIFY_TOKEN`).
  `firecrawl` stays disabled (registered but out of credits); `crawl4ai` disabled (not
  registered). Disabled rows carry a dated freshness stamp — re-confirm tool names before
  enabling. (User added Scrapling + apify during implementation, beyond the original
  documented-but-off scope.)
- ? **B-real trigger — RESTATED (not carried forward).** ADR-0010's ">700 exa req/mo" metric is
  **superseded**: free-by-default moves exa off the hot path, so its request count no longer
  proxies research volume, and ADR-0010 already admitted there is no counter to read it. New
  qualitative trigger: **build B-real when escalation friction recurs — e.g. you manually
  override the agent's provider choice more than ~3x in a month, or repeatedly fight its tool
  selection.** Do not re-anchor it to an unmeasurable number.

## References

- Supersedes/amends: ADR-0010 (exa-only); builds on ADR-0007 (sparse cherry-pick mechanism — deep-research is now removed from it).
- Design doc: `~/.gstack/projects/seungwonkim-v6x-MySystem/seungwonkim-main-design-20260601-161353-deepresearch-provider-pluggable.md`
- Research (provider MCP tool names, verbatim-verified): `~/.gstack/projects/seungwonkim-v6x-MySystem/seungwonkim-main-research-20260601-deepresearch-provider-mcp.md`
- Plan + autoplan dual-voice review: `~/.gstack/projects/seungwonkim-v6x-MySystem/seungwonkim-main-plan-20260601-deepresearch-provider-pluggable.md`
- Vendored from ECC `affaan-m/everything-claude-code` @ `64cd1ba2`.

## How this file is maintained

- ADR numbering is monotonic per project. Don't reuse numbers; mark superseded instead.
- Rewrite history only by adding a new ADR that supersedes the old one.
- An ADR is deliberate. Don't auto-generate from PR descriptions.
