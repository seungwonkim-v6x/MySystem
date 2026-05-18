# ADR-0002: Sparse cherry-pick install mechanism (`SPARSE_SKILLS`)

- **Status**: Accepted
- **Date**: 2026-05-17
- **Author**: seungwon-v6x
- **Tags**: setup, install, harness

## Context

Pre-v0.30.0 `setup.sh` had one external-skill mechanism: `EXTERNAL_REPOS`, which clones a full repo into `skills/<name>/` and runs that repo's own setup script. This works for gstack (which installs 40+ skills via its own setup) but is the wrong shape for "I want exactly *one* skill out of this 14-skill collection." Cloning the full collection drags in siblings the workflow doesn't use and forces the coordinator to triage 14 skill suggestions per session start.

The v0.30.0 wave added two such single-skill targets — `requesting-code-review` from obra/superpowers (a 14-skill repo) and `deep-research` from affaan-m/everything-claude-code (a much larger collection). Neither merited a full clone.

## Decision

We will support a second install mechanism in `setup.sh`: `SPARSE_SKILLS`. Format: `"skill-name|url|branch|subpath-in-repo"`. The setup script clones the repo into a cache directory (`external-skills/<skill-name>/`, git-ignored), then **symlinks** the named subpath into `skills/<skill-name>/`. Only the one targeted skill appears under `skills/`.

Boundary: SPARSE_SKILLS is for *self-contained* skill subpaths. Plugins that ship hooks depending on `${CLAUDE_PLUGIN_ROOT}` cannot use it — those go through the marketplace mechanism (ADR-0005).

## Alternatives considered

- **A: Submodule the upstream repo at a specific subpath** — rejected because git submodules were removed in v0.27.0 (operational pain >> benefit for solo workflow)
- **B: Vendor a copy of the skill file into MySystem** — rejected because upstream changes require manual sync; defeats the harness philosophy
- **C: Full clone via `EXTERNAL_REPOS`** — rejected because of the sibling-skill surface problem above

## Consequences

- ✓ `git pull` in MySystem keeps the cherry-picked skill current with upstream `main` automatically
- ✓ Sibling skills in the upstream repo are invisible to Claude Code (they live under `external-skills/`, not `skills/`)
- ✓ Adding a new cherry-pick is a one-line `SPARSE_SKILLS+=( ... )` change
- ✗ `setup.sh` re-clone behavior depends on the upstream's branch shape; we tracking `main` means an upstream force-push lands silently
- ✗ Hook-bearing plugins can't use this mechanism; see ADR-0005
- ? Whether the "symlink-not-copy" pattern survives if Claude Code changes how it resolves skills (currently fine, but the symlink is a coupling point)

## References

- Related: ADR-0001 (harness philosophy), ADR-0005 (plugin marketplace for hook-bearing plugins)
- CHANGELOG: v0.30.0 (mechanism introduced), v0.31.0 (extended for `REFERENCE_REPOS` clone-only variant)
- Code: `setup.sh:33-37`
- Out of scope: [.out-of-scope/sparse-skills-for-hook-plugins.md](../../.out-of-scope/sparse-skills-for-hook-plugins.md)
