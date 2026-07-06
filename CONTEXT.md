# CONTEXT — MySystem

MySystem is one developer's personal Claude Code configuration, tracked at
[seungwonkim-v6x/MySystem](https://github.com/seungwonkim-v6x/MySystem) and
checked out at `~/.claude/` on every machine. This file is the project-level
glossary; CLAUDE.md is the operating rulebook; ADRs in `docs/adr/` are the
decision log; `.out-of-scope/` is the "explicitly not doing this" log.

## Who and why

- **User**: a junior-to-mid backend/frontend engineer (Korean), high
  AI-assist usage, works across multiple repos (vProp at voyagerx, personal
  projects like cc-guard, MySystem itself).
- **Why this exists**: keep a *strict* 8-step workflow that the user can
  audit, version, and propagate across machines via `git pull`. Resist the
  scope sprawl that comes from accumulating user-owned skills.
- **Audience**: primarily the user; secondarily a future contributor or
  curious reader who finds the repo and wonders how it's wired.

## The 9-step workflow (the central thing this repo enforces)

```
1. /office-hours  →  2. /research  →  3. /autoplan
                ↓                                ↓
4. Implementation  ←  5. Verification (verify-test/qa-only/design-review)
                ↓
6. /review  →  7. /requesting-code-review  →  8. /ship  →  9. /ai-review-loop
                                                            (only when /ship
                                                             created a PR)
```

The full table with skill ownership lives in CLAUDE.md ("Step → Skill Mapping").
Debug paths swap step 1 for `/investigate`.

## Vocabulary

- **Harness, don't build** — MySystem's prime directive. Adopt public skills,
  don't write custom ones. See ADR-0001.
- **Skill whitelist** — only skills mapped to one of the 8 workflow steps may
  be invoked autonomously by the coordinator. Everything else runs only when
  the user types its name.
- **Boil the lake** — when AI makes the marginal cost of completeness near
  zero, prefer the complete implementation over the 80% shortcut. Originated
  in gstack's philosophy; absorbed by MySystem as a judgment criterion.
- **Repo mode** — solo vs collaborative. In solo repos (MySystem, cc-guard)
  the agent proactively fixes adjacent issues. In collaborative repos (vProp)
  the agent flags issues in one sentence rather than fixing.
- **See something, say something** — anytime the agent notices something
  wrong during any workflow step, surface it in one sentence; never silently
  pass.
- **AI reviewer loop (Step 9)** — post-/ship convergence loop over every AI
  reviewer reachable on the PR. **Tier A** = PR bots (Copilot, Greptile,
  CodeRabbit — re-triggered per-reviewer: gh @copilot / push / comment
  command), **tier B** = local cross-model CLIs (codex), **tier C** = fresh
  Claude subagents. See `skills/ai-review-loop/`.
- **Fingerprint** — a finding's state-tracking identity in the loop:
  `<path>#<gist>` where gist = normalized first-8-significant-tokens of the
  title (line number is metadata, survives fix-commit drift). Cross-source
  clustering of differently-phrased duplicates stays a judgment call on top.
- **Valid-finding convergence** — the loop's termination predicate: a round
  with an empty untriaged queue and zero findings classified "valid".
  Noise (misreadings, prior-decision re-raises) gets replies but cannot
  extend the loop. Rounds are unbounded by user decision (ADR-0012).

## Install mechanisms (three, in `setup.sh`)

- `EXTERNAL_REPOS` — full-clone install. The upstream repo's own setup
  script installs N skills. Current: `gstack`.
- `SPARSE_SKILLS` — cherry-pick install. Clone repo, symlink one subpath
  into `skills/<name>/`. Current: `requesting-code-review` from
  obra/superpowers, `deep-research` from affaan-m/everything-claude-code.
  See ADR-0002.
- `REFERENCE_REPOS` — read-only knowledge install. Clone into
  `references/<name>/`. **Not skills** — the agent greps them. Catalog at
  `references/INDEX.md`. See ADR-0003.

Plugins that ship hooks (depend on `${CLAUDE_PLUGIN_ROOT}`) cannot use any
of the above; they go through Claude Code's marketplace mechanism
(`settings.json` `extraKnownMarketplaces` + `enabledPlugins`). See ADR-0005.

## Directory map

| Path | Purpose | Tracked? |
|---|---|---|
| `CLAUDE.md` | Operating rules — workflow, skill whitelist, repo mode | yes |
| `CONTEXT.md` | This file | yes |
| `settings.json` | Claude Code harness config + plugin enablement | yes |
| `setup.sh` / `install.sh` | Bootstrap external repos + plugins | yes |
| `hooks/` | SessionStart / PreToolUse / Stop hooks | yes |
| `templates/` | CONTEXT.md / ADR / pre-commit templates for downstream projects | yes |
| `docs/adr/` | Architecture Decision Records for MySystem itself | yes |
| `.out-of-scope/` | Explicit "we considered it, chose no" rationales | yes |
| `references/INDEX.md` | Curated catalog of `references/<repo>/` knowledge bases | yes |
| `references/*/` | Cloned knowledge repos (system-design-primer, papers-we-love, …) | no (cache) |
| `skills/verify-test/` | The one remaining user-owned skill (no public alternative) | yes |
| `skills/*/` (other) | External skills installed by `setup.sh` | no (symlinks / clones) |
| `external-skills/` | Cache for `SPARSE_SKILLS` clones | no |
| `projects/`, `sessions/`, `telemetry/`, etc. | Claude Code runtime state | no |

## External dependencies (the surface)

| Source | Mechanism | Adopted in |
|---|---|---|
| [garrytan/gstack](https://github.com/garrytan/gstack) | EXTERNAL_REPOS (full clone) | workflow steps 1-3, 6, 8 |
| [obra/superpowers](https://github.com/obra/superpowers) | SPARSE_SKILLS (one skill) | workflow step 7 |
| [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code) | SPARSE_SKILLS (one skill) + firecrawl MCP | workflow step 2 |
| 12 reference repos | REFERENCE_REPOS (clone-only) | grepped on demand |
| [nexu-io/html-anything](https://github.com/nexu-io/html-anything) | Visual system only (CSS adapted) | preview hook |
| [anthropics/claude-plugins-official](https://github.com/anthropics/claude-plugins-official) | Plugin marketplace | frontend-design, context7, code-review, figma |

## What to read first

- New contributor / future-me onboarding: this file → `CLAUDE.md` → `docs/adr/0001-*.md`
- Adding a new external skill: `SETUP.md` "Adding another external skill repo"
- Adding a new reference: `references/INDEX.md` bottom section
- Recording a "no" decision: `.out-of-scope/README.md`
- Recording a "yes" decision worth preserving: `docs/adr/` + the template at
  `templates/0000-adr-template.md`
