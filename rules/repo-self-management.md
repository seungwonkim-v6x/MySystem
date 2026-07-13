---
paths:
  - "~/.claude/**"
---

<!-- mysystem:section repo-self-management:start -->
# Repo Self-Management Rules (MySystem)

This rule is **path-scoped** with the absolute `~/.claude/**` path so it only triggers when Claude reads files inside the MySystem repo. The earlier draft used unrooted globs such as `**/CHANGELOG.md` and `**/scripts/**`, which would inject MySystem release rules into unrelated projects. The absolute home prefix prevents that leak while covering new tracked directories such as `codex/` and `tests/`.

**Compaction-survival belt-and-suspenders:** Anthropic's context-window docs state path-scoped rules are NOT re-injected after `/compact` until a matching file is read again. The two most dangerous rules below (single-logical-change commits, NEVER PostToolUse git mutation) are therefore ALSO restated inline in `~/.claude/CLAUDE.md`'s "Critical Workflow Rules" block, which is re-read on compaction natively. The rest of this file is informational — if you `/compact` mid-MySystem-session and then keep editing MySystem files, the rule reloads when you touch a matching file.

## Required steps when modifying MySystem

1. **Bump VERSION** — follow semver:
   - major: breaking harness change (e.g., removing a safety hook or changing the working-agreement contract)
   - minor: new skill / new step / new rule
   - patch: fix or tweak
2. **Update CHANGELOG.md** — add an entry under the new version with date and description
3. **Git tag** — `/ship` creates `vX.Y.Z` tag matching the VERSION file (don't tag manually mid-stream)
4. **Sync skill files** — external skills are managed by `setup.sh` (full clone in `EXTERNAL_REPOS` or sparse cherry-pick in `SPARSE_SKILLS`), never copied. User-owned skills live as plain files under `skills/`.
5. **Push to origin** — push commits and tags (handled by `/ship`)
6. **Adding an external skill repo** — Append to `EXTERNAL_REPOS` (full repo) or `SPARSE_SKILLS` (single skill) in `setup.sh`, add a row to the table in `README.md` and `SETUP.md`. Never use git submodules (removed in v0.27.0). External skill dirs are registered dynamically in `.git/info/exclude` by `setup.sh`; do not hardcode their names in `.gitignore`.
7. **Updating the step→skill mapping** — Any change to the canonical mapping in `CLAUDE.md` is a breaking workflow change (major bump).

## Forbidden Patterns

**Commits are scoped to a single logical change, not a single file.** Bundle related file edits together into one commit. Per-file commits are an anti-pattern — they fragment history, defeat atomic-revert semantics, and produce review noise. The `/ship` workflow handles atomic commits; do not pre-fragment them. Use squash semantics where the host platform supports them.

**NEVER install PostToolUse hooks that mutate git state.** This includes `git add` / staging, `git commit`, `git commit --amend`, `git push`, `git pr create`, and any other write to `.git/` or the remote. Git state changes are produced only by `/ship`, by `/ai-review-loop` within its budget carve-out (below), or by explicit user request, never as a side effect of a tool call. Such hooks poison history with garbage messages, defeat atomic-commit discipline, silently bypass pre-commit hooks elsewhere, and undermine the "review before commit" gate. If a PostToolUse hook auto-stages, auto-commits, auto-pushes, or auto-PRs, REMOVE IT.

**`/ai-review-loop` carve-out (ADR-0012, on-demand tool per ADR-0015).** The /ai-review-loop skill may autonomously commit and push fix commits (`review-loop(rN):` prefix) on the PR branch it is looping, bounded by: ≤20 changed lines per round and ≤40 per loop without user approval (measured on the staged diff by `skills/ai-review-loop/bin/round-budget.sh`), sensitive paths (`hooks/**`, `settings.json`, `.github/workflows/**`, secret/credential/env globs, `install.sh`, `setup.sh`) always escalate regardless of size, fixes are staged-never-committed until the gate passes, and every escalation pauses the loop as awaiting-user. This is the ONLY autonomous git-mutation grant besides `/ship`; it does not generalize — new grants require their own ADR.

(Anti-patterns from shanraisshan/claude-code-best-practice and davila7/claude-code-templates `git-workflow/smart-commit.json`, generalized — the failure mode applies to every git-mutating side effect, not just commits.)
<!-- mysystem:section repo-self-management:end -->
