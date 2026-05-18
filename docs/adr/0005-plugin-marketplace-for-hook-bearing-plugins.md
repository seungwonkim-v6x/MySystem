# ADR-0005: Plugin marketplace as the path for hook-bearing third-party plugins

- **Status**: Accepted
- **Date**: 2026-05-18
- **Author**: seungwon-v6x
- **Tags**: setup, plugins, security, supply-chain

## Context

v0.33.0 needed to adopt three plugins from `DrCatHicks/learning-opportunities`: a core skill, a PostToolUse hook that nudges Claude to offer a lesson after `git commit`, and a repo-orientation skill. Initial /office-hours design assumed `SPARSE_SKILLS` (ADR-0002) would suffice: clone repo, symlink the three subpaths into `skills/`.

`/deep-research` (Step 2) caught the trap by reading the upstream `hooks.json`:

```json
{"command": "bash ${CLAUDE_PLUGIN_ROOT}/hooks/post-tool-use.sh"}
```

`${CLAUDE_PLUGIN_ROOT}` is set **only by Claude Code's plugin loader**, not by file-system symlinks. A SPARSE_SKILLS install would silently break the hook — the worst kind of failure (looks installed, doesn't run).

Claude Code's `extraKnownMarketplaces` + `enabledPlugins` mechanism is the supported integration path. MySystem already uses it for `claude-plugins-official` (frontend-design, context7, code-review). Same shape, different upstream.

## Decision

We will use Claude Code's plugin marketplace mechanism for any third-party plugin that ships a `hooks.json`. Specifically: register the upstream marketplace git URL in `settings.json` `extraKnownMarketplaces`, then enable individual plugins via `enabledPlugins`. The plugin loader handles cloning, environment-variable injection, and lifecycle.

Boundary: this ADR applies to plugins that need `${CLAUDE_PLUGIN_ROOT}` or other plugin-loader services. Self-contained skills (no hooks, no plugin-loader dependencies) still go through SPARSE_SKILLS (ADR-0002).

## Alternatives considered

- **A: SPARSE_SKILLS for everything** — rejected because of the `${CLAUDE_PLUGIN_ROOT}` issue above; see [.out-of-scope/sparse-skills-for-hook-plugins.md](../../.out-of-scope/sparse-skills-for-hook-plugins.md)
- **B: Fork the plugin and wrap it with our own setup script** — rejected because forking crosses the "harness, don't build" line; see [.out-of-scope/custom-frequency-wrapper.md](../../.out-of-scope/custom-frequency-wrapper.md)
- **C: Skip the auto-nudge feature and use the core skill in explicit-invocation mode only** — rejected because the user's stated behavior pattern ("I will never invoke it manually") would make the skill effectively uninstalled

## Consequences

- ✓ Plugins integrate the way Claude Code expects; no glue code needed in `setup.sh`
- ✓ `git pull` propagates `settings.json` changes; the loader handles the rest on next session start
- ✗ Marketplace URLs are tracked as `main` branch with no pin; upstream force-push or compromise lands silently on every machine (mitigation in v0.33.0: SETUP.md notes "review upstream diff before pulling MySystem updates" for non-Anthropic marketplaces)
- ✗ Plugin behavior can drift from MySystem documentation if upstream changes the hook semantics — v0.33.0's Step 7 review caught two such mismatches at adoption time; need a process to re-validate on future upstream changes
- ? Whether Anthropic ever exposes a ref/commit/tag pinning mechanism for `extraKnownMarketplaces` — currently no public schema for it

## References

- CHANGELOG: v0.33.0
- Related: ADR-0002 (SPARSE_SKILLS for non-hook skills)
- Code: `settings.json` `extraKnownMarketplaces` + `enabledPlugins`
- Out of scope: [.out-of-scope/sparse-skills-for-hook-plugins.md](../../.out-of-scope/sparse-skills-for-hook-plugins.md), [.out-of-scope/custom-frequency-wrapper.md](../../.out-of-scope/custom-frequency-wrapper.md)
