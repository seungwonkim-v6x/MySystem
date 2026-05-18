# Out of scope: SPARSE_SKILLS for hook-bearing plugins

**Decided:** 2026-05-17 during v0.33.0 /deep-research, ratified in v0.33.0 CHANGELOG.

## What it is

Use `setup.sh`'s `SPARSE_SKILLS` mechanism (clone repo, symlink one subpath
into `skills/<name>/`) to adopt plugins that ship a Claude Code `hooks.json`
file. The mechanism already works for skill-only plugins (e.g. obra/superpowers
`requesting-code-review`, affaan-m `deep-research`).

## Why it was attractive

Single install mechanism for all third-party content. Familiar to MySystem's
existing patterns. No need to involve Claude Code's plugin marketplace
machinery.

## Why we rejected it

`hooks.json` references `${CLAUDE_PLUGIN_ROOT}/hooks/post-tool-use.sh`. That
environment variable is set **only by Claude Code's plugin loader**, not by
file-system symlinks. SPARSE_SKILLS would import the files and silently
break the hook — the worst kind of failure (looks installed, doesn't run).

The supported integration path is `extraKnownMarketplaces` +
`enabledPlugins` in `settings.json`. MySystem already uses that pattern for
`claude-plugins-official`; the marketplace mechanism is the right tool.

## Reconsider when

- Anthropic exposes a stable way to populate `CLAUDE_PLUGIN_ROOT` without
  going through the marketplace loader (would let SPARSE_SKILLS handle
  hooks too)
- Or: a third-party plugin we want to adopt ships its hook in a way that
  doesn't depend on `CLAUDE_PLUGIN_ROOT`
