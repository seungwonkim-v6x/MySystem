# CONTEXT - MySystem

MySystem is one developer's strict Claude Code and Codex workflow, tracked at
[seungwonkim-v6x/MySystem](https://github.com/seungwonkim-v6x/MySystem) and
checked out at `~/.claude/`. `CLAUDE.md` is the operating rulebook,
`codex/parity-contract.json` is the narrow machine-readable ownership contract,
ADRs are the decision log, and `.out-of-scope/` records explicit no-decisions.

## Who and why

- **User:** Korean backend/frontend engineer with high AI-assist usage across
  personal and collaborative repositories.
- **Goal:** keep one auditable 9-step workflow and make Claude Code and Codex
  follow the same observable gates without sharing unsafe runtime state.
- **Audience:** primarily the owner; secondarily future maintainers.

## The 9-step workflow

```text
1. /office-hours -> 2. /deep-research -> 3. /autoplan
                                             |
                                             v
4. Implementation -> 5. Verification -> 6. Concurrent review
                                        (/review + /requesting-code-review,
                                         run together, one gate)
                                             |
                                             v
                              8. /ship -> 9. /ai-review-loop
                                          (only when /ship created a PR)
```

Debugging swaps Step 1 for `/investigate`. Every transition waits for explicit
approval except the documented Step 8 to Step 9 PR-created chain. The complete
mapping and successor rules live only in `CLAUDE.md`; Codex consumes a generated
native projection rather than an independent rewrite.

## Vocabulary

- **Behavioral parity:** Claude Code and Codex produce the same observable
  workflow routing, approval stops, required skill/tool attempts, and forbidden
  actions. Exact wording is not part of the contract.
- **Canonical prose:** marked sections in `CLAUDE.md` and `rules/*.md`. Humans
  edit these; generated `codex/AGENTS.*.md` files are never edited directly.
- **Projection:** deterministic provider-native `AGENTS.md` output containing
  canonical prose plus the small Codex terminology adapter.
- **Core profile:** always-required workflow skills and safety hooks.
- **Conditional profile:** a closed preflight for `material-ui`, `browser`, or
  explicit `figma` work. Configuration is not an authentication claim.
- **Typed skill source:** `gstack-generated`, `portable-local`,
  `portable-sparse`, or `plugin-profile`. Each type has one installer behavior.
- **Managed path:** a destination the parity installer may link after complete
  preflight. Unknown real content is preserved and blocks installation.
- **Harness, don't build:** prefer established public skills and deterministic
  enforcement over more prompt prose.
- **Valid-finding convergence:** Step 9 ends only when the untriaged queue is
  empty and no finding is classified valid; rounds remain unbounded per ADR-0012.

## Ownership boundaries

| Surface | Owner |
|---|---|
| Workflow prose and detailed rules | `~/.claude` Git checkout |
| Generated Codex global/project instructions | renderer, tracked under `codex/` |
| Default Codex instruction/hooks links | parity installer |
| Alternate Codex-home `AGENTS.md` | parity installer |
| Alternate host `hooks.json` | host, inspected read-only |
| Gstack-generated Codex skills | gstack setup |
| Portable local/sparse Codex skills | parity installer links |
| Auth, history, sessions, config, DB, plugins, MCP credentials | each runtime/host |

## Install mechanisms

- `EXTERNAL_REPOS`: full upstream checkout and its own setup. Current: gstack.
- `SPARSE_SKILLS`: one subdirectory from an upstream checkout. Current:
  `requesting-code-review` and SHA-pinned `verification-before-completion`.
- Codex parity installer: local render, safe migration, links, recovery, and
  structural doctor. It performs no network, model, browser, or authenticated
  MCP calls.
- Claude plugins: `settings.json` marketplace configuration, owned by Claude.
- Codex conditional capabilities: runtime-owned plugin/MCP configuration,
  checked by named profiles rather than copied from Claude.

## Directory map

| Path | Purpose | Tracked? |
|---|---|---|
| `CLAUDE.md` | canonical workflow | yes |
| `AGENTS.md` | link to MySystem-only Codex supplement | yes, symlink |
| `rules/` | canonical detailed rules | yes |
| `codex/` | parity contract, adapter, generated files, hook registration | yes |
| `scripts/` | renderer, installer, doctor, budget helper | yes |
| `skills/verify-test/`, `deep-research/`, `aside-qa/`, `ai-review-loop/` | user-owned skills | yes |
| `skills/gstack/`, `external-skills/`, other setup outputs | external cache/install state | no |
| `hooks/` | canonical hook implementations | yes |
| `tests/` | deterministic contracts | yes |
| `projects/`, sessions, telemetry, runtime state | provider state | no |

## Compatibility baseline

- Codex CLI `0.144.1`
- Orca `1.4.128`
- macOS Bash 3.2 and current Ubuntu Bash
- Global `AGENTS.md` symlink behavior is both source-backed and empirically
  observed for the baseline. Newer unverified versions require the doctor and
  the bounded live release scenarios before a parity claim.

## What to read first

- Operation: this file -> `CLAUDE.md` -> `SETUP.md`
- Architecture: `docs/adr/0014-codex-behavioral-parity.md`
- Testing and release evidence: `TESTING.md`
- Adding an external skill: `SETUP.md#external-skills`
- Recording a decision: `docs/adr/` and `templates/0000-adr-template.md`
