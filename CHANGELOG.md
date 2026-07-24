# Changelog

All notable changes to MySystem are documented here.
Format follows [Keep a Changelog](https://keepachangelog.com/).

> **Versioning note (2026-05-08)**: MySystem was renumbered from `vN.M.P`
> (running 1.0.0 → 7.6.1 over Mar–May 2026) into the pre-1.0 `0.x.y` range.
> Old `MAJOR.MINOR` pairs were collapsed onto sequential new MINOR slots
> (e.g. `1.0 → 0.0`, `2.0 → 0.1`, `2.3 → 0.4`, `7.6 → 0.29`); old PATCH was
> preserved. All git tags (`v2.0.0` … `v7.6.1`) were force-replaced with the
> new mapping. Body text in older entries has been updated to match the new
> scheme. Solo repo, no external consumers — preserving SemVer signal
> (still-iterating, no API stability promise) was worth the rewrite.

## [0.52.1] - 2026-07-24

**Config cleanup landed from pre-existing WIP: Codex context-budget skill pruning in `setup.sh`, and the default session model set to Opus.**

### Changed
- `setup.sh`: after the gstack/sparse installers, prune generated host-export directories, non-workflow skills, and plugin caches so the Codex skills surface stays scoped to the mandatory workflow whitelist (tighter context budget; pruned skills remain restorable via a direct gstack setup).
- `settings.json`: default session model `claude-fable-5[1m]` → `opus[1m]`.

## [0.52.0] - 2026-07-24

**Steps 6 and 7 merged into one concurrent two-pass review gate (ADR-0017, amends ADR-0016). Both passes still run — `/review` in-session (context-rich structural) and `/requesting-code-review` as a parallel fresh-context subagent — but concurrently, with findings merged into a single approval gate instead of two sequential gates. No coverage loss; one fewer approval wait. This started as an investigation into adopting `alibaba/open-code-review` (OCR) to do the merge and rejected it: in delegation mode OCR adds no review intelligence (only deterministic file selection + rule-doc injection — the review is still done by a fresh Claude subagent), while dragging in a version-pinned third-party binary, a re-audit-on-bump tax, and an untrusted-rule-injection surface on team repos. OCR's real fit is a Step-9 CI bot, which the owner cannot install anyway.**

> Version note: 0.51.0 is claimed by the open skill-model-routing PR (#11); this change branched off main@0.50.0 and advances to 0.52.0 to avoid the queue collision. VERSION/CHANGELOG reconcile at merge (whichever lands second rebases).

### Changed
- `CLAUDE.md`: Step→Skill mapping, both workflow diagrams, successor map, Step 5 menu, and the "Steps 6 + 7" section rewritten as "Step 6: Concurrent Two-Pass Review (one gate)". Step 7 removed; Steps 8 (`/ship`) and 9 (`/ai-review-loop`) keep their numbers — a deliberate gap at 7, since `/ai-review-loop` is hard-referenced as "Step 9" across its SKILL.md and ADR-0012. Successor-map preamble reworded off the now-imprecise "step N+1".
- `skills/ai-review-loop/SKILL.md`: "Steps 6/7" → "Step 6" (4 references).
- `CONTEXT.md`, `README.md`: workflow diagram and source-attribution updated for the merge.
- `templates/PRE-COMMIT-SETUP.md`: stale "Step 7 `/review`" → "Step 6".
- `codex/AGENTS.global.md`: regenerated projection from the edited `CLAUDE.md`.

### Added
- `docs/adr/0017-merge-review-steps-6-7.md`: records the merge, the OCR investigation and rejection (with the security findings), and the numbering-gap rationale. Amends (does not supersede) ADR-0016 — only the Step 6/7 shape changes; all other gates stand.

### Hook-enforcement candidates
- (none) — this is a workflow-doc change; "both passes must complete before the single gate" is irreducibly prompt-level (no hook event fires on a model's review sequencing).

## [0.51.0] - 2026-07-21

**Per-step model routing: research runs on Sonnet, everything from review through the post-ship loop runs on Opus, and Fable stays reserved for planning and implementation.**

### Added

- `scripts/apply-model-overrides.sh` (setup.sh stage [3.5/5]): a `MODEL_OVERRIDES` table (`ship|opus`, `review|opus`, `requesting-code-review|opus`) that runs after the gstack/sparse installers each session and replaces each skill's SKILL.md symlink with a generated wrapper — the source's frontmatter plus a pinned `model:` line, body deferring to the external file (read live at invocation, so upstream skill updates still apply). Self-healing against gstack's per-session re-linking; editing the external checkouts directly would break their session-start pulls. Validate-before-mutate: every failure path (missing source, frontmatter-less source, dangling symlink) leaves installer-managed state untouched, and a wrapper whose recorded source vanished is removed so the installer re-links on its next run.
- `tests/model-overrides.bats` — 15 hermetic contract tests (sandbox repo via `MYSYSTEM_REPO_ROOT`, CI-safe; mid-test `[[ ]]` assertions carry `|| false` so macOS bash 3.2 cannot silently no-op them): wrapper generation for file- and dir-symlink installs, model pin + preserved frontmatter + source marker, byte-identical idempotency, skip paths (missing / dangling / frontmatter-less / unterminated-frontmatter sources), stale-wrapper removal including the sparse empty-dir case, interrupted-conversion recovery, relative-symlink canonicalization (physical, `..`-free), stranded-temp sweep, tracked-skill pins, setup.sh delegation.

### Changed

- Tracked user-owned skills pin models directly in frontmatter: `/deep-research` → `model: sonnet` (Step 2), `/ai-review-loop` → `model: opus` (Step 9). Frontmatter `model:` switches the model for the rest of the invoking turn; the session model (Fable) resumes on the next user prompt, so gate boundaries double as model boundaries.
- `skills/requesting-code-review` converted from a sparse dir-symlink to an untracked real dir holding the generated wrapper (regenerated by setup.sh — not tracked like deep-research-style vendoring; the sparse installer's real-dir guard skips it and its external cache still refreshes).

## [0.50.0] - 2026-07-21

**The gated 9-step workflow is back (ADR-0016, reversing ADR-0015): one week of the gate-less working agreement made Codex — the user's daily driver via the generated projection — noticeably worse, and the owner called the restore. Hook hardening from v0.49.0 stays.**

### Restored

- `CLAUDE.md` at its v0.48.0 gated form: mandatory 9-step pipeline, per-step approval gates, instruction precedence, Step → Skill mapping, skill whitelist / mandatory-invocation rule, triviality carve-out, Step-4 design discipline, /ship→/ai-review-loop auto-chain.
- `codex/AGENTS.header.md` gated adapter header; projections regenerated (`AGENTS.global.md`, `AGENTS.project.md`) so Codex consumes the gated workflow again.
- Gate-era language in `rules/operating-principles.md` (Conditional Clarification "Inside a Step", Step-4 references, "during ANY workflow step") and `rules/repo-self-management.md` (workflow-era semver wording).

### Changed

- `codex/parity-contract.json`: `budgets.global_max_bytes` 32768 → 36864 — the gated projection plus the post-v0.48 First Principle section (2ec9213, preserved) exceeds the old effective limit; reserve unchanged at 4096.
- Restored CLAUDE.md updated where v0.48 text had gone stale against kept v0.49.0 reality: precedence tier 3a now lists the full unconditional hard-refuse set (`--no-verify`, `reset --hard` on main, fail-closed parsing), the Testing section names the Codex-parity and ai-review-loop suites, the Detailed-rules index lists the preserved First Principle, and the v0.49.0 "never weaken a hook to get unblocked" rail is re-added to CLAUDE.md and the Codex adapter header (it had lived only in the deleted working agreement).
- Cross-reference cleanup: ADR-0015 marked Superseded by ADR-0016 (including its ADR-0012 auto-chain amendment, now reversed), TESTING.md's parity-scenario note re-inverted (scenarios 1-6 are the live release gate again), and the obsolete ADR-0015 kill-criterion review TODO closed in TODOS.md.
- `settings.json` (local machine state riding this branch): Orca agent-hook guards hardened (`-f`/`-r`/`-x` checks + stdin drain when the script is absent) and `effortLevel` raised medium → high.

### Kept from v0.49.0

- All hook hardening (unconditional hard-refuse tier, fail-closed parsing, bypass-resistant matching), shellcheck CI, narrowed git allows, and their bats coverage — per ADR-0015's own rollback contract. 136/136 bats green after the restore.

## [0.49.0] - 2026-07-13

**The gated 9-step workflow is gone (ADR-0015): CLAUDE.md is a ~55-line working agreement, skills are on-demand tools, the PR merge is the only human gate — and the safety hooks got strictly harder to compensate.**

### Removed

- Mandatory 9-step pipeline, per-step approval gates, workflow successor map, Step-5 verification menu, skill whitelist / mandatory-invocation rule, and the /ship→/ai-review-loop auto-chain. All skills remain installed as user/agent-invoked tools.
- The tiered-triage machinery (tier-guard hook, declare-tier CLI, tier-repos, tier-sensitive-paths) that was built earlier on this branch per the /autoplan review, then removed when the user chose the review's stronger "full deletion" alternative. Code retrievable from branch history; re-add only on the ADR-0015 kill criterion.

### Changed

- `hooks/block-dangerous-git.sh`: hard-refuse tier now exits 2 UNCONDITIONALLY (fixes the latent prose/code mismatch where "always non-zero" actually dry-ran without MYSYSTEM_HOOKS_ENFORCE=1); fails closed with an environment-naming message on unparseable payloads (jq → python3 fallback); rules anchored to command-start with quoted-segment stripping (echoed/grepped/heredoc/commit-message mentions can no longer false-positive); block messages are agent-actionable (problem + cause + fix; hook-edit bypass is human-only, documented in TESTING.md, never printed to the agent).
- New hard refuses: `git commit --no-verify` / bundled `-n` (defense for repos carrying pre-commit hooks — NOT a secret-scanner bypass, which is a PreToolUse hook unaffected by --no-verify) and `git reset --hard` while on main/master (runtime branch check, fail-open soft on detached/undeterminable).
- The git hook's enforced blocks now log to `~/.claude/logs/hook-blocks.log` (real-friction signal for /retro); `~/.claude/logs/` whitelisted in dangerous-command-blocker (traversal-proof lookahead).
- `settings.json`: broad git allows narrowed (`git push *` → `git push origin HEAD` / `-u origin *`; `git add *` → `git add -- *`).
- `rules/operating-principles.md`: Conditional Clarification rewritten without step/gate references.
- CLAUDE.md rewritten as a working agreement (judgment defaults, one-sentence pause rule, evidence-before-completion, skills-as-tools); Codex parity markers preserved; projections regenerated.

### Added

- ADR-0015 (remove workflow gates; supersedes ADR-0001's pipeline aspect, amends ADR-0006), with coverage-delta acceptance, durable-vs-Fable-5-contingent tags, kill criterion (2-3 same-class incidents → re-add ONE targeted rail), and rollback procedure.
- 30 new bats contracts: hard refuse with ENFORCE unset (regression class), --no-verify/-n/-anm blocks with a false-positive suite (quoted mentions, echo/grep/heredoc, `-am`, `push -n`), an adversarial-bypass suite from the pre-landing review (quoted arguments, newline separation, `VAR=x` prefixes, `bash -c` wrappers, exec-prefix words sudo/command/xargs/nohup/time/then, reordered force flags, brace groups, `bash -lc`, `--git-dir=`, heredoc-tag edge cases, `logs/../` traversal), fail-closed malformed payload, deterministic jq-absent/no-tools stubs, hook-blocks.log assertion, reset --hard branch fixtures, blocker logs-whitelist cases.

### Hook-enforcement candidates

- "Evidence before completion claims" is now prompt-level only (was backed by the Step-5 gate). Candidate: a Stop-hook verifier or /goal-style check; promote if /retro logs unverified completion claims.

## [0.48.0] - 2026-07-10

**Codex now consumes a native, generated projection of the same canonical 9-step workflow as Claude Code, with safe links, typed skill ownership, shared hooks, structural diagnostics, and an explicit live behavioral release gate.**

### Added

- `codex/parity-contract.json`, Codex adapter header, deterministic global/project `AGENTS.md` projections, and tracked default hook registration.
- Isolated renderer, recoverable parity installer, shared portable shell library, and read-only doctor with `core`, `material-ui`, `browser`, and `figma` profiles.
- Safe migration of the recorded legacy project/default Codex instructions, hook copies, and user skill copies into canonical links; unknown real content fails closed.
- Thirty Bats parity contracts, opt-in real-dispatch hook canaries, macOS CI coverage, and ADR-0014.

### Changed

- `setup.sh` is now one public Claude/Codex command family with `--check`, `--parity-only`, `doctor`, `--recover`, and repeatable `--codex-home`.
- SessionStart keeps external refresh behavior but runs the parity phase read-only and promotes its log atomically.
- `deep-research`, `aside-qa`, and `ai-review-loop` now state their provider adapters; portable workflow skills link into `~/.agents/skills` while gstack-generated Codex skills remain gstack-owned.
- Budget reporting separates the generated global compatibility guardrail from the project-document budget. README, SETUP, CONTEXT, TESTING, and ADR-0009 now describe the current architecture.
- Review hardening binds durable migration state to the exact managed write set and backup content identity, rejects linked state/lock leaves, hashes every tree entry type/mode/target, fsyncs transaction boundaries, makes recovery retry-safe, closes the hook contract against its exact argv registration, confines renderer outputs, validates gstack ownership, preserves malformed-contract JSON diagnostics, and prints local stage timings.

### Safety and release boundary

- Default and alternate runtime auth, histories, sessions, config, databases, plugins, MCP credentials, and host metadata remain provider-owned and are never copied.
- Structural parity does not claim live model adherence or MCP authentication. Ordinary and Orca Codex must pass the bounded scenarios in `TESTING.md` before release completion.
- The 2026-07-10 release gate passed in ordinary and Orca Codex for workflow routing, approval succession, Step 5/9 policy, profile preflight, project isolation, Bash/Edit hook dispatch, and the Aside live browser fallback.

### Hook-enforcement candidates

- None. Existing safety scripts are shared by link and verified structurally plus harmless dispatch canaries; no new git-mutating hook was introduced.

## [0.47.1] - 2026-07-07

**Two noisy integrations are gone: the rtk token-compression hook no longer rewrites every Bash command, and the learning-opportunities plugin family no longer fires post-commit learning nudges (it false-positive-triggered on non-commit git commands, including twice during this very removal session).**

### Removed

- **rtk PreToolUse hook** — the `rtk hook claude` Bash-matcher hook block, all six `rtk *` permission allowlist entries, `RTK.md` (and its `.gitignore` whitelist line + `CLAUDE.md` `@RTK.md` import), and setup.sh's RTK verification step (banners renumbered `[1/5]`→`[1/4]`). Direct `rtk` CLI use still works for anyone who has the binary; MySystem just no longer wires or documents it.
- **learning-opportunities plugin family** — `learning-opportunities`, `learning-opportunities-auto`, and `orient` removed from `enabledPlugins`, and the DrCatHicks marketplace removed from `extraKnownMarketplaces`. The plugins were also uninstalled locally (`claude plugin uninstall` × 3 + marketplace remove); on any other machine, run the same uninstalls once after pulling — key removal alone does not clear machine-local installed state.

### Changed

- **`CLAUDE.md`** — dropped the "Exception — learning-opportunities plugin" whitelist carve-out and the `RTK.md` mention in precedence level 3b; the skill whitelist now has no exceptions.
- **Docs consistency sweep** — README/SETUP/CONTEXT plugin tables now match `settings.json` exactly (including the previously undocumented `figma` plugin); `CONTEXT.md` drops the RTK.md and DrCatHicks rows; `operating-principles.md` "Harness, Not Model" example rewired after losing its rtk example; ADR-0006 gained an amendment note (rtk hook-ordering prose is now historical); two `.out-of-scope/` records (`custom-frequency-wrapper`, `learning-goal-paired-skill`) closed with status notes — their reconsider-triggers could never fire post-removal.

### Hook-enforcement candidates

- (none this release — this release deletes hooks rather than adding prompt-only rules)

## [0.47.0] - 2026-07-07

**Step 4 gains a design-discipline layer: native `/frontend-design` (taste) + a machine-checkable `DESIGN.md` rider (bans), wired on material UI changes. The broader "narrate silent decisions" rule was reviewed and deliberately held — no real trigger yet.**

Full pipeline ran: /office-hours (design doc, re-scoped twice — UI-taste → generation-time guardrail → domain-agnostic silent-decision surfacing), /deep-research (Anthropic docs + GitHub: frontend-design semantics, taste-skill MIT/extractable, decision-surfacing prior art, hook-enforceability), /autoplan with four adversarial voices (Codex + CEO/Eng/DX subagents) that converged on holding the narration half.

### Added

- **`templates/DESIGN.md`** — per-project design rider (copied in like CONTEXT.md.template). Machine-checkable bans only (h-screen→min-h-[100dvh], emoji-as-icon, flex-% math→grid, generic spinner→skeleton, mandatory loading/empty/error states, bold-variance no-centered-hero, packed-density no-card-in-card) + named design presets (calm/balanced/bold, never a raw number) + a human-facing "how to tune this" header. Adapted from `Leonxlnx/taste-skill` (MIT), stack-agnostic subset only — the whole SKILL.md was NOT vendored.
- **`docs/adr/0013-taste-rider-and-held-narration.md`** — records native frontend-design + extracted rider vs vendored taste-skill, the domain-agnostic surfacing concept, and why narration was held.

### Changed

- **`CLAUDE.md`** — Step→Skill table Step 4 now loads `/frontend-design` + the `DESIGN.md` rider on a *material UI change*; `/frontend-design` added to the autonomous whitelist as a **materiality-gated carve-out** (new UI or reshaping, NOT any UI file touched); new "Step 4 — design discipline" subsection defines the two-layer load, the explicit-load requirement (frontend-design does not read DESIGN.md), and precedence (frontend-design wins on taste; rider bans are hard).
- **`rules/operating-principles.md`** — "Harness, Not Model" records the narration rule as a resolved hook-enforcement candidate (negative result).

### Hook-enforcement candidates

- **inline-decision-narration** — HELD, not shipped. Investigated and found irreducibly prompt-level: no hook event fires on a model's judgment (`MessageDisplay` is display-only), so it cannot be enforced. Also lacked a real trigger. Documented negative result, not a TODO. Re-open only after 2-3 real silent-Step-4-decision incidents are logged; if built, pair with a `/retro` transcript-sampling audit + default-to-delete kill date.

## [0.46.0] - 2026-07-03

**Step 9 ships: `/ai-review-loop` — every AI reviewer reachable on a PR becomes one converging review committee, with the user's prior decisions constitutionally senior to any model's re-litigation.**

Pattern proven manually on Tapit PR #137 (2026-07-02, 3 rounds vs Copilot), generalized to a 3-tier fan-out and promoted to a formal workflow step. Full pipeline ran ahead of it: /office-hours design doc (adversarial-reviewed 9/10), /deep-research on GitHub API semantics (20 sources), /autoplan with dual Claude+Codex voices per phase (48 decisions, 11 cross-model overlapping findings folded in).

### Added — `skills/ai-review-loop/` (user-owned, tracked)

- **SKILL.md** — agent protocol: startup/resume, round protocol (re-trigger → wait → collect → triage → classify → fix → reply), canonical convergence predicate (empty untriaged queue + zero valid findings; rounds unbounded per user decision), escalation-as-awaiting-user model, idempotent resume by phase.
- **bin/detect-reviewers.sh** — 3-tier registry detection; per-reviewer `retrigger` method (research finding: `requested_reviewers` re-POST is a silent no-op for Copilot — the working paths are `gh pr edit --add-reviewer @copilot` under a PAT, comment commands for Greptile/CodeRabbit, or push-triggered).
- **bin/collect-reviews.sh** — three comment surfaces (reviews + inline + issue comments), no page-1-304 trust (per-page ETags can mask appended comments), edited-in-place detection via body hash, `--gist` deterministic fingerprint normalization (stopword-stripped 8-token, CJK-safe).
- **bin/preflight.sh** — gh/PR hard stops, advisory-lock check, active-loop schema fail-closed, prettier-drift warning (the Tapit lint-staged pollution pitfall), CI baseline snapshot.
- **bin/round-budget.sh** — staged-diff budget gate (≤20 lines/round; ≤40/loop cumulative tracked in the skill layer), binary-diff escalate, rename-normalized **sensitive-path matcher** (hooks/, settings.json, workflows, secret globs — always escalate).
- **bin/post-reply.sh** — the only PR-posting path: body-file only (no shell interpolation of untrusted comment text), loop marker embedding, 403/429 backoff, 404 thread-root re-resolve.
- **bin/loop-markers.sh** — reconstructs the replied-set from PR markers, filtered to the loop's own account BEFORE extraction (a triaged bot can't forge a marker to fake convergence — harness-enforced, not prompt-only).
- **state-schema.md / escalation-templates.md / runbook.md** — frozen state schema (schema_version 1), fixed per-class escalation messages with resume commands, owner manual.
- **tests/ai-review-loop.bats** — 42 offline contract tests against a stub `gh` (detection incl. suffix-login spoof rejection + expected-bot seeding + unknown-bot exclusion, all three surfaces paginated/id-filtered incl. appended-page reviews, edited-comment, gh-network-failure ≠ empty-increment, gist goldens incl. adversarial injection title, budget boundary 20/21 + sensitive/rename/binary + --range, reply marker + backoff, forged-marker rejection).

### Changed — constitution (ADR-0012)

- CLAUDE.md CRITICAL rule: git mutations only via `/ship`, **`/ai-review-loop` (within its per-round budget)**, or explicit user request; step table + successor map gain Step 9 (auto-chains only when /ship created a PR); whitelist gains `/ai-review-loop`; the "NEVER proceed without approval" paragraph gains the single 8→9 exception; Steps 6/7 vs 9 complementarity note (pre-merge diff vs PR artifact).
- `rules/repo-self-management.md`: carve-out spelled out; explicitly non-precedential.
- ADR-0012 records the rejected alternatives (per-fix approval, batched-per-round approval — both models' preference, declined twice by the user), the harness-enforced bounds, and a sunset trigger (vendor-native fix loops, or zero-invocation prune).
- CONTEXT.md: workflow diagram 8→9 steps; glossary entries (AI reviewer loop, fingerprint, valid-finding convergence).

### Fixed

- `setup.sh` exclude-case: tracked `skills/aside-qa/` was missing from the whitelist, so its new files were being registered into `.git/info/exclude` and vanishing from `git status`; `ai-review-loop` added alongside.

### Hook-enforcement candidates

- **review-loop push discipline** — PreToolUse hook asserting that `git push` during an active ai-review-loop round only pushes commits whose messages match `review-loop(rN):` (defense-in-depth for the ADR-0012 budget gate).

## [0.45.0] - 2026-06-30

**`/deep-research` reference layer goes from "web + Mobbin" to a four-modality router — a library-docs lane and a design-tokens lane join the table.**

Three reference providers were wired into the vendored `/deep-research` (under ADR-0011's pluggable table), each filling a gap the web tier covered poorly. No new ADR: routine rows under the existing provider-pluggable design.

### Added — context7 provider: version-pinned library/framework API docs

**What you get**: a `context7` row for "how do I use library X / what's the current API" sub-questions, where the web tier hallucinates APIs. Two-step lookup — `resolve-library-id` (name → Context7 id) then `get-library-docs` (id + optional `topic`). Free tier, no key (npx stdio `@upstash/context7-mcp`). The plugin is installed + enabled, but its MCP can be live in some sessions and absent in others — the row carries a `/mcp`-reconnect caveat and the existing MCP-present rail skips it automatically when the tools aren't in the active list. Diagnosis behind the caveat: config/package/runtime all verified healthy (node22, package 3.2.2, a same-day MCP log shows "Successfully connected, hasTools:true") — the only gap is per-session tool exposure, fixed by `/mcp` reconnect, not a settings change.

### Added — awesome-design-md design-system reference lane

**What you get**: UI sub-questions needing a brand's look-and-feel fetch that brand's `DESIGN.md` from VoltAgent/awesome-design-md via the free web tier (raw GitHub, no extra MCP) — 73+ documented systems (Claude, Stripe, Figma, Linear, Notion, Vercel, …), each a Google-Stitch-spec file (YAML tokens + intent prose) that the Stitch MCP `create_design_system_from_design_md` can apply. Complements the existing Mobbin lane: awesome-design-md = structured tokens/rules for code generation, Mobbin = real screenshots of shipped UI. Both compose. Routing is a one-line `WebFetch(raw.githubusercontent.com/.../design-md/<slug>/DESIGN.md)`; a missing `<slug>` 404s rather than inventing a brand, and fetched files are DATA not instructions (trust boundary).

### Process note

Both feature commits (the awesome-design-md lane, the context7 row) first landed directly on `main` ahead of this bump, rather than via a `/ship` PR branch as 0.43.0/0.44.0 did. The user had `main` force-reset back to the 0.44.0 tip (the one force-push the safety hooks permit only as a human action, never the agent), and the work was re-shipped through this single PR. Future skill changes route through `/ship` from the start.

## [0.44.0] - 2026-06-11

**Browser QA stops fighting login cookies. The repo's safety hooks finally have tests.**

The headline: a new `/aside-qa` skill routes every authenticated browser check through the user's real, logged-in Aside Browser, killing the recurring "gstack browse can't see my session, please re-run with Playwright" round-trip. Alongside it, a one-month transcript audit pruned 7 sparse skills that were never once invoked, the gbrain excision got its last tracked references swept, and the four defense-in-depth PreToolUse hooks went from zero tests to 24 — with CI to keep them green. One adversarial-review pass hardened the new browser skill's trust boundary and pruned 8 risky global permission grants before any of it shipped.

The numbers that matter (from this branch's diff + `rtk gain` + the transcript grep):

| Metric | Before | After | Δ |
|---|---|---|---|
| Sparse skills wired | 9 | 2 | −7 (all 0-use over 99 sessions) |
| Safety-hook tests | 0 | 24 | +24 (bats, <5s, in CI) |
| settings.json global grants | 142 (drifted) | 105 | −37 one-shot/overbroad |
| Authenticated-QA cookie failures | every session | structural 0 | attach-to-live-tab |

The aside skill was verified against a real logged-in `vprop.ai/admin` tab — snapshot in 118ms, no login redirect. That 118ms is the whole point: the agent reads the admin UI as the user, no cookie import, no Playwright detour.

What this means for the daily workflow: browser verification (`/qa-only`, `/design-review`, Quick Visual Check) just works on logged-in apps, the workflow's skill list reflects what's actually used, and the security hooks have a regression net even though they stay dry-run (Auto Mode's permission gate remains the live risk adjudicator — see ADR note below). Run `bats tests/` before any hook edit.

### Itemized changes

### Added — /aside-qa: real-browser verification layer via aside MCP

**What you get**: browser-driven verification (`/qa-only`, `/design-review` browser actions, Quick Visual Check) now drives the user's real Aside Browser instead of the gstack headless browse daemon. The recurring failure this kills: gstack browse can't reach login cookies, so every authenticated QA pass required the user to manually redirect the agent to Playwright. aside's MCP `repl` tool attaches to live browser tabs (sessions just work) and exposes the full Playwright API plus `snapshot()` diffs and `annotatedScreenshot()` — a functional superset of both the browse daemon and Playwright MCP for verification purposes.

**Shape**: user-owned skill `skills/aside-qa/SKILL.md` (driver patterns: attach-before-open, console capture, snapshot/diff loop, 1440px evidence shots, 120s-per-call chunking) + CLAUDE.md "Browser layer (v0.44.0+)" paragraph routing browser verification through it (level-3 precedence over gstack skill internals). gstack `/browse` remains the announced fallback for public unauthenticated pages or when aside is down. aside MCP registered at user scope in `~/.claude.json` (machine-local). Stale `mcp__Playwright__browser_navigate` reference in Quick Visual Check (Playwright MCP no longer registered) replaced in the same edit.

### Removed — 7 unused sparse skills pruned (evidence-based)

**What you get**: `SPARSE_SKILLS` shrinks from 9 entries to 2, and CLAUDE.md's invocation policy stops documenting branches that never fire. Transcript audit (99 sessions, 2026-05-12 → 2026-06-11; grep pattern validated against known-used skills: autoplan 28, office-hours 25, requesting-code-review 20) found **zero invocations** for 7 of the 9 v0.37.0 sparse cherry-picks: `/test-driven-development`, `/diagnose`, `/grill-with-docs`, `/prototype`, `/triage`, `/zoom-out`, `/handoff` — all 4 user-invoked skills (never typed) and 3 autonomous alternates (trigger conditions never occurred; `/handoff` chained off `/context-save`, itself at 0 uses). Kept: `/requesting-code-review` (20 sessions) and `/verification-before-completion` (10).

**Mechanics**: entries removed from `setup.sh` `SPARSE_SKILLS`, symlinks removed from `skills/`, clones removed from `external-skills/` (plus the orphaned `external-skills/deep-research` cache left behind by the v0.43.0 vendoring). Re-adding any skill is one `SPARSE_SKILLS` line + `./setup.sh`. The Vertical-Slice TDD principle in `rules/operating-principles.md` is untouched — only the opt-in skill wrapper was dropped. CLAUDE.md's "Debug Step 1 rule" keeps its diagnose-derived hypothesis discipline (the pattern was absorbed into prose; the skill was the unused part). Stale Step 2 source attribution ("sparse cherry-pick ECC, needs firecrawl") corrected to "vendored, provider-pluggable (ADR-0011)" in the same pass.

### Removed — gbrain excised (ADR-0008 superseded; rollback triggers fired)

**What happened**: PGLite's WASM runtime fails to initialize on macOS 26.x (gbrain issue #223, `Aborted()`), silently killing auto-capture (stalled 2026-05-29), reads, search, and the MCP bridge at once. The user ran the documented teardown (`rollback-gbrain.sh` + launchd unload; corpus tarballed to `~/.gbrain-rollback-bak-*.tar.gz`): `rules/gbrain-protocol.md` and `scripts/gbrain-ingest-sessions.sh` deleted, ADR-0008 marked SUPERSEDED, CLAUDE.md persistent-recall section rewritten around file-based memory + the seungwon-wiki vault. This release completes the sweep by deleting the now-targetless `scripts/rollback-gbrain.sh` (its rollback target `~/.gbrain` no longer exists; recoverable from git history) and clearing the last tracked references that still told a fresh machine to set gbrain up: `README.md` and `SETUP.md` (the `/setup-gbrain` Path-3 post-install step is gone — exactly the PGLite-local path macOS 26 breaks) plus the ADR-0009 cross-reference to the deleted rule file. The K1-K4 rollback triggers in ADR-0008 fired as designed — the experiment captured 8 sessions (May 20–29) before dying.

### Changed — safety-hook docs now match reality (dry-run, not "constitutional")

The four defense-in-depth PreToolUse hooks were documented as "effectively constitutional, exit non-zero on violation," but `MYSYSTEM_HOOKS_ENFORCE` is unset by design — so outside the two hard-refuse tiers (force-push to main/master, private-key commit) they detect-and-log, they don't block. The decision stands (Auto Mode's permission gate already adjudicates command risk; enabling enforce would double-gate and only add false positives), so this aligns the prose to it instead of flipping the switch: the instruction-precedence entry (3a), `TESTING.md`, and `rules/operating-principles.md` now say dry-run-by-default with hard-refuse-always. The new `tests/hooks.bats` exercises both the enforce-mode block path and the default dry-run path so either regressing surfaces.

### Hook-enforcement candidates

- Browser-layer routing rule ("browser verification goes through /aside-qa, fallback must be announced") — prompt-only; a PreToolUse hook on Bash could warn when gstack browse commands run while the aside MCP server is connected.
- Flip `MYSYSTEM_HOOKS_ENFORCE=1` — deferred. Revisit after reviewing `~/.claude/logs/hook-dry-run.log` for false-positive rate; only promote if the soft-refuse tiers prove low-noise AND Auto Mode's gate is judged insufficient on its own.

## [0.43.0] - 2026-06-01

### Changed — /deep-research vendored + provider-pluggable (ADR-0011, supersedes ADR-0010)

**What you get**: `/deep-research` is now owned and customizable, and routes across providers by task fit instead of being locked to exa. The skill was a sparse cherry-pick (a symlink into an untracked ECC clone), so any local edit was clobbered on the next `setup.sh` — durable customization was impossible. It is now **vendored**: `skills/deep-research/` is a tracked real directory (copied from ECC @ `64cd1ba2`), removed from `SPARSE_SKILLS`, whitelisted in `.gitignore` (mirroring verify-test), with the Codex `agents/openai.yaml` variant dropped. The vendored dir survives `setup.sh` re-runs primarily because the `SPARSE_SKILLS` entry is gone (the loop never touches it); a defense-in-depth guard (`[ -d ] && [ ! -L ]`) protects any future vendored-from-sparse skill, and a `deep-research) continue` arm in the `.git/info/exclude` regeneration loop keeps the now-tracked path from being re-excluded.

**Pluggable, judgment-guided**: the SKILL.md body now carries an inline provider table (`builtin`/`exa`/`apify`/`firecrawl`/`scrapling`/`crawl4ai`) with `best_for`/`cost` as agent-routing input. Default tier is free built-in `WebSearch`/`WebFetch` (routine research costs $0 of any metered budget); the agent reads each provider's strengths and escalates by fit (exa for neural depth, Scrapling/crawl4ai for bot-walled/JS pages, apify/firecrawl for managed scrape). A sibling `providers.yaml` was rejected because only `SKILL.md` auto-loads into context. Selection is model judgment; only the safety rails are deterministic (skip a provider whose MCP isn't in the active tool list, fetch-only rows never originate a search, auth errors STOP rather than silently swap). The two built-in caveats are encoded against the builtin row: the subscription `WebSearch` 429 bug (Claude Code #27074) falls back to exa, and `WebFetch`'s lossy small-model extraction triggers a sharper re-fetch / raw `curl` before escalating. In this release the user also wired two providers beyond the documented-but-off baseline: **Scrapling** (free/OSS, installed via `uv tool` + browser stack, MCP at user scope) for bot-walled/Cloudflare pages, and **apify** ($5/mo credit, npx stdio + user `APIFY_TOKEN`) for managed scrape — both registered + enabled. `firecrawl` stays disabled (registered but out of credits) and `crawl4ai` is documented-but-off.

**Decision record**: [ADR-0011](docs/adr/0011-deep-research-vendored-provider-pluggable.md). Provider MCP tool names were verbatim-verified by a 12-agent research workflow (adversarial verification caught a hallucination: apify's tool is `apify--rag-web-browser`, double hyphen, not the slash Actor-ID form). The plan passed `/autoplan` dual-voice review (Codex gpt-5.5 + 3 Claude subagents, CEO/Eng/DX) — both converged "approach sound, spec needs-work", and 14 confirmed fixes were folded in (the `.git/info/exclude` loop, the guard expression, the frontmatter description, falsifiable verification, the deterministic selection block).

**Workflow note**: A User Challenge surfaced at the `/autoplan` gate — both models flagged carrying ADR-0010's ">700 exa req/mo" B-real trigger forward verbatim, because free-by-default moves exa off the hot path and invalidates exa-count as a research-volume proxy. The trigger is **restated qualitatively** in ADR-0011 (build B-real when manual provider-override friction recurs, ~3x/mo) rather than anchored to an unmeasurable number. B-real (the code shim) stays deferred. Third instance of the dual-voice User Challenge mechanism redirecting an in-progress decision.

## [0.42.1] - 2026-05-29

### Added — ADR-0010: /deep-research free stack (exa-only; crawl4ai wrapper rejected)

**What you get**: `/deep-research` runs for $0 with no firecrawl credits. exa is registered (free tier, 1,000 req/mo, no credit card) and pinned to `exa-mcp-server@3.2.1`; the provider-agnostic skill uses exa for both search (`web_search_exa`) and deep-read (`web_fetch_exa`). The firecrawl credit wall that was blocking `/deep-research` is gone. The exa MCP config lives in `~/.claude.json` (machine-local, outside this repo), so this release is the decision record only.

**Decision record**: [ADR-0010](docs/adr/0010-deep-research-free-stack-exa-only.md) records why the richer crawl4ai-container wrapper (Approach B) was rejected. office-hours premise challenge + `/autoplan` dual voices (CEO 6/6 + Eng 6/6 consensus, Codex gpt-5.5 + Claude subagent) converged that B was over-scoped — it optimized an unmeasured exa cap (~50 → ~100 researches/mo for one solo user) — AND structurally unbuildable as a "thin wrapper": provider routing and the exa-budget guard are prose in a SKILL.md, not enforceable, which violates "harness, not model." B is only viable as a deterministic code proxy. The ADR records the revisit trigger (>700 exa req/mo, measured at dashboard.exa.ai) and the B-real shape so the dead end is not re-attempted.

**Workflow note**: Second instance of `/autoplan` dual voices redirecting an in-progress feature via the User Challenge mechanism (after v0.42.0's references cut). This time the Eng phase additionally found the approved design structurally unbuildable, flipping the choice from B (crawl4ai wrapper) to A (exa-only) at the gate.

## [0.42.0] - 2026-05-28

### Removed — references/ corpus (613MB, 12 read-only repos) plus the "grep references first" rule

**Background**: 698 Claude Code session transcripts showed only 1-2 genuine `references/` activations (~0.3%). Both `/autoplan` dual voices (Codex + Claude subagent) independently flagged the corpus as a falsified portfolio — building harness infrastructure to surface low-value material is sunk-cost rescue. The user confirmed the cut after a reframing exercise made the actual pain visible (Claude's UI output quality, not references discoverability per se).

**Removed**:
- `references/` directory: 12 cloned repos (`system-design-primer`, `awesome-scalability`, `papers-we-love`, `awesome-falsehood`, `awesome-design-patterns`, `engineering-blogs`, `awesome-llm`, `awesome-ai-agents`, `awesome-design-md`, `awesome-design-systems`, `awesome-tailwindcss`, `awesome-react-components`) plus `INDEX.md`.
- `setup.sh`: `REFERENCE_REPOS` array, the `[4/6]` clone loop, the `.git/info/exclude` inner loop for references. Setup step count renumbered 6 → 5.
- `rules/operating-principles.md`: "Consult References Before Searching the Web" section (the prompt-only rule that was supposed to drive activation).
- `README.md`: "References (treasure trove — read-only knowledge bases)" section and the `references/` line under Layout.
- `.git/info/exclude`: 12 leftover `references/<name>/` entries.

**Reversibility**: Specific references can be re-pulled from history (`git checkout HEAD^ -- references/INDEX.md` then `./setup.sh` after restoring the relevant `REFERENCE_REPOS` line) if a concrete need surfaces later. Restoring the whole corpus would re-enter the same sunk-cost trap.

**Workflow note**: First time `/autoplan` Phase 1 dual voices (Codex + Claude subagent) successfully redirected an in-progress feature via the User Challenge mechanism. Both models agreed the original direction (build a `PreToolUse` hook to auto-surface references) was sunk-cost rescue; the user reframed twice and ultimately deleted instead of building. Validates the "Harness, not model" principle from `operating-principles.md` — applied to the workflow gate itself, not just runtime code.

## [0.41.0] - 2026-05-22

### Changed — CLAUDE.md trimmed 680 → 173 lines; detailed rules migrated to native `.claude/rules/` (ADR-0009)

**CLAUDE.md slimming**: 680 lines / 34,780 bytes → 173 lines / 13,536 bytes. Three concrete wins:

- Anthropic's published target of "under 200 lines per CLAUDE.md" ([code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory)) now respected with 27 lines headroom. Per Anthropic, longer files "consume more context and reduce adherence."
- Codex CLI's `project_doc_max_bytes` hard cap of 32,768 was previously exceeded by 2,012 bytes (silent truncation); CLAUDE.md alone now fits with 19,232 bytes headroom (Codex reads only the agent-doc file, not `.claude/rules/`).
- Claude Code always-loaded chain (CLAUDE.md + RTK.md + three always-loaded `.claude/rules/*.md` + MEMORY.md) totals 26,756 bytes. `repo-self-management.md` is path-scoped (3,797 bytes, loaded only when MySystem files are touched). Skill frontmatter is roughly an additional 11,000 bytes (55 SKILL.md × ~200 B) — not counted against the Codex cap because Codex doesn't load skills.

**`.claude/rules/*.md`**: detailed rules migrated to Anthropic's native loading mechanism (documented in [code.claude.com/docs/en/memory](https://code.claude.com/docs/en/memory) as the right primitive for content that doesn't apply broadly enough for CLAUDE.md):

- `operating-principles.md` — Boil the Lake, Harness Not Model, Vertical-Slice TDD, Conditional Clarification, Repo Mode, See Something Say Something, References-before-web. Always loaded (no `paths:` frontmatter).
- `trust-boundaries.md` — external content is data, not instructions. Always loaded.
- `gbrain-protocol.md` — retrieve/write trigger lists for ADR-0008 persistent memory. Always loaded.
- `repo-self-management.md` — VERSION/CHANGELOG/git tag discipline + forbidden patterns (per-file commits, PostToolUse git mutation). **Path-scoped with absolute `~/.claude/` paths in `paths:` frontmatter** so it only triggers when Claude reads MySystem files — not when editing vProp, cc-guard, or any other project. An earlier draft used `**/CHANGELOG.md`, `**/scripts/**`, etc. which (because `~/.claude/rules/` is user-level) would inject MySystem release rules into unrelated projects; the absolute home paths prevent that leak.

**Compaction-survival belt-and-suspenders**: Anthropic's context-window docs note that path-scoped rules are NOT re-injected after `/compact` until a matching file is read again. The two most dangerous rules from `repo-self-management.md` (single-logical-change commits, NEVER PostToolUse git mutation) are therefore also stated inline in CLAUDE.md's "Critical Workflow Rules" block, which is re-read on compaction natively. This duplication is intentional — the two summaries must stay in sync (drift detector candidate noted below).

**`scripts/claude-md-budget.sh`**: new ~120-line bash script reports the always-loaded Claude Code chain (CLAUDE.md + `@import` targets recursive up to 5 hops per Anthropic spec + `.claude/rules/*.md` with path-scope annotation + MEMORY.md + skill frontmatter estimate). Compares CLAUDE.md alone against the Codex CLI 32 KiB cap (Codex's actual gate — it doesn't load `.claude/rules/` or skill frontmatter). Read-only, idempotent. Run manually to track budget over time.

### Motivation — Anthropic native solutions over custom workarounds

This release abandons two layers of custom infrastructure that the workflow's `/autoplan` review surfaced as either unnecessary or wrong-pattern:

1. **Original 5-PR / R1-R5 plan** (UserPromptSubmit workflow router + 4 `mysystem-*` skill extractions + `/si:review`/`/si:promote` adoption + AGENTS.md symlink + budget script across 5 commits, 5 ADRs, 5 VERSION bumps). Cross-model consensus during `/autoplan` Phase 1 CEO dual voices (Claude subagent + Codex) challenged the scope on 8/8 dimensions as over-engineered for a solo repo. Aligned with `feedback-trigger-driven-shipping` memory's precedent — the 12-factor-agents v0.40 abort.
2. **Option D — single PR with `SessionStart(matcher: "compact")` hook + extracted `~/.claude/critical-rules.md`** — workaround for compaction-loss fear. Scaffolding was written (hook + critical-rules.md + settings.json entry) before a deeper read of `code.claude.com/docs/en/memory` surfaced: *"Project-root CLAUDE.md survives compaction: after `/compact`, Claude re-reads it from disk and re-injects it into the session."* The hook would be parallel infrastructure for a problem Anthropic already solves natively. Rolled back before commit; only the budget script was preserved into Option E.

The pivot is documented in ADR-0009. The "Harness, Not Model" principle (now in `.claude/rules/operating-principles.md`) gets a strengthening case: **prefer native Claude Code features over custom workarounds**.

### Verification (run during release)

```
wc -l ~/.claude/CLAUDE.md                          # 173 (target ≤ 200)
wc -c ~/.claude/CLAUDE.md                          # 13536 (Codex cap 32768)
~/.claude/scripts/claude-md-budget.sh              # exits 0 with headroom report
ls ~/.claude/rules/                                # operating-principles, trust-boundaries, repo-self-management, gbrain-protocol
grep -E "(CRITICAL RULE|Auto Mode|NEVER|MUST)" ~/.claude/CLAUDE.md | wc -l    # surviving rules in trimmed file
```

**Smoke test** (manual, after first session post-merge to validate `.claude/rules/*.md` actually loads natively):

1. Open a fresh `claude` session in `~/.claude/`.
2. Ask: "What is the Boil the Lake principle?" — content lives only in `~/.claude/rules/operating-principles.md`. A correct answer confirms always-loaded rules trigger.
3. Open a fresh `claude` session in some other project (e.g., `~/Documents/vprop/`).
4. Edit any file. Verify Claude does NOT bring up "Bump VERSION" / "Update CHANGELOG" — those live in path-scoped `repo-self-management.md` which should NOT trigger outside `~/.claude/`.

If step 2 fails: rules don't load natively in this Claude Code version — fall back to inline (see ADR-0009 "Retire when"). If step 4 surfaces MySystem rules: the absolute path globs are not honored as intended — restore `<important if="modifying the MySystem repository (~/.claude/) itself">` tag pattern from v0.40.0.

### Rollback

Single revert: `git revert <merge-commit>` restores CLAUDE.md, removes the four `.claude/rules/*.md`, removes `docs/adr/0009-*.md`, removes `scripts/claude-md-budget.sh`. VERSION + CHANGELOG also revert. ~30 seconds.

If only the rule migration fails (Claude Code doesn't actually load `.claude/rules/*.md` in your build) and the content needs to come back inline, the prior CLAUDE.md is reconstructable from this commit's diff + the four migrated rule files.

### Hook-enforcement candidates

(per the Harness-Not-Model rule's logging discipline)

- **`/compact` recovery monitoring** — none needed (Anthropic handles natively for root CLAUDE.md); placeholder for any future drift detection if Anthropic behavior changes.
- **CLAUDE.md size CI gate** — `scripts/claude-md-budget.sh` exits non-zero on cap violation. A pre-commit or PostToolUse(Write|Edit on CLAUDE.md) hook could fire this script automatically. Promote when the size starts creeping back up.
- **`.claude/rules/` paths-frontmatter validation** — a hook checking that path-scoped rules' `paths:` globs actually match expected files (and only those). Defer until a rule misfires.
- **CLAUDE.md ↔ `.claude/rules/repo-self-management.md` duplication drift detector** — the two most dangerous rules (single-logical-change commits, NEVER PostToolUse git mutation) live in both files for compaction safety. A pre-commit or PostToolUse hook could diff the canonical summaries and flag drift. Promote once a real divergence happens. For now, manual sweep: search `grep -c "PostToolUse hooks that mutate git" CLAUDE.md rules/repo-self-management.md` should return 2 (one each).

### Also in this commit (small, unrelated)

- `settings.json`: bump `effortLevel` `high → xhigh` (Opus 4.7 default). Carried in from prior session; bundled here rather than reverted because xhigh is the intended steady state. Not load-bearing for the v0.41.0 thesis.

### Not in scope (deferred to TODOS / future ADRs)

- `@AGENTS.md` import or `CLAUDE.md → AGENTS.md` symlink for cross-tool (Codex/Cursor/Cline) portability. Defer until concrete Codex-CLI-doesn't-read-instructions report.
- Promptfoo regression suite for CRITICAL workflow rules — adds test infra dependency. Pilot when a CRITICAL RULE actually fails in measurable form.
- WHY / Retire-when metadata tags on each rule. Layer on top of `.claude/rules/` after observing which rules age out fastest.
- Anthropic memory tool / context-editing API integration — API beta, not exposed in Claude Code surface yet. Track for next quarter.
- Skill cherry-pick of alirezarezvani `/si:review` + `/si:promote` — operationalizes the "three is the trip-wire" rule. Pilot when MEMORY.md actually hits 200-line cap.

## [0.40.0] - 2026-05-20

### Added — gbrain persistent memory: CLAUDE.md triggers + hourly auto-capture (ADR-0008 amendment)

**CLAUDE.md section**: New `## Persistent Memory (gbrain)` block adds explicit
retrieval triggers (call `mcp__gbrain__search` / `get_page` / `recall` BEFORE
generating, on cues like "어제 그거" / "remember when" / `/office-hours` Phase 1 /
cross-repo references) and write triggers (call `put_page` / `add_link` /
`add_timeline_entry` AFTER decision moments). Skip rules carved out for routine
grep/read, trivial yes/no, ephemeral chitchat — anything `git log` or `grep`
would surface later.

**Auto-capture pipeline**: New `scripts/gbrain-ingest-sessions.sh` extracts
user + assistant text from `~/.claude/projects/**/*.jsonl` (filtering out
`tool_use`, `tool_result`, system reminders, hook output) and writes one gbrain
page per session with slug `cc-session-<repo>-<short-uuid>`. Idempotent via
marker files in `~/.gbrain/ingested/` keyed on `<size>-<mtime>`. Hourly via
`~/Library/LaunchAgents/com.user.gbrain-session-capture.plist` (machine-local,
not tracked — same principle as ADR-0008 Section 6 "Machine-local state").

**Backfill knob**: `TIME_WINDOW=<minutes> bash scripts/gbrain-ingest-sessions.sh`
overrides the 65-minute default (catches last hour + 5 min slack). Manual sweep
of last week: `TIME_WINDOW=10080 …`. Per-session content cap 500KB
(`MAX_SIZE_KB`); oversize sessions logged and skipped, not truncated.

**ADR-0008 Amendment 2026-05-20**: Section 6 "CLAUDE.md untouched" reframed as
v0.38.0 release-discipline boundary, not permanent rule. Section 2 ("additive,
not replacement") stays in force. K-criteria K1-K4 re-verified: the launchd job
is user-installed not gbrain-installed, so K1 still holds; the Anthropic memory
MCP at `modelcontextprotocol/servers` is third-party install, not Claude Code
native, so K3 doesn't fire.

**Why amendment, not new ADR**: The underlying decision (gbrain as additive
retrieval sidecar, chosen over agentmemory after 4-reviewer autoplan at v0.38)
is unchanged. Only the release-boundary deferrals lift. New ADR would inflate
the registry; in-place amendment preserves continuity.

### Motivation

v0.38.0 activated gbrain MCP but deferred two pieces of the design's intent —
(a) the CLAUDE.md trigger block, and (b) the actual capture mechanism behind
`transcript_ingest_mode=incremental`. Observed state by 2026-05-20:
`gbrain stats` reported Pages: 1, Embedded: 0 — tool registered, never used.
This release closes both gaps without swapping tools, preserving the 250-line
ADR-0008 + rollback script + SHA-pin policy investment.

### Slug + content design (gotchas surfaced during script bring-up)

- **Repo extraction** strips `^-Users-<user>-` plus common parent dirs
  (`Documents-`, `src-`, `code-`, `projects-`) so
  `~/.claude/projects/-Users-seungwonkim-Documents-vprop` becomes `vprop`,
  not `Documents-vprop`. The longer form caused early put-failures via some
  slug-canonicalization path in gbrain v0.37.
- **UUID prefix is 12 chars**, not 8 — collision-resistant for sibling sessions
  like `agent-abedcab6a60d02b4f` vs `agent-aee9164889e9d64ab`.
- **`GBRAIN_MAX_FENCES_PER_PAGE` raised to 2000** (default 100). Code-heavy
  sessions routinely exceed the default; the cap cascades into "Page not found"
  put-failures rather than just warning.
- **Frontmatter `type: transcript`** lets `list_pages --type transcript` and
  `list_pages --tag cc-transcript` filter cleanly.

### Verification (run during release)

```
gbrain stats          # before:  Pages: 1, Chunks: 1, Embedded: 0
gbrain stats          # after:   Pages: 12, Chunks: 996, Embedded: 0
mcp__gbrain__search "12-factor adoption gbrain reactivation"   # returns score 0.99
launchctl list | grep gbrain         # com.user.gbrain-session-capture registered
tail ~/.gbrain/ingest-log.jsonl      # second run: 8 processed, 6 ingested, 0 errored
```

Embedded stays 0 because no embedding backend is configured. PGLite + tsvector
keyword search works without it. If semantic retrieval becomes a real need
(e.g., recall a discussion by paraphrase, not keyword), evaluate Ollama + local
embedding model then.

### Rollback

`~/.claude/scripts/rollback-gbrain.sh` (existing from v0.38.0) plus:

```
launchctl unload ~/Library/LaunchAgents/com.user.gbrain-session-capture.plist
rm ~/Library/LaunchAgents/com.user.gbrain-session-capture.plist
rm scripts/gbrain-ingest-sessions.sh
rm -rf ~/.gbrain/ingested/ ~/.gbrain/ingest-log.jsonl
git revert <this-commit>     # undoes CLAUDE.md + ADR-0008 + VERSION + CHANGELOG
```

### Not shipping in this release — v0.40 was originally scoped for 12-factor F5/F9 adoption

The 8-step workflow ran (/office-hours → /deep-research → /autoplan with
CEO/Eng/DX subagent review) for humanlayer/12-factor-agents F5 (unify state) +
F9 (compact errors) adoption. Three reviewer voices flagged: (a) F9 MVP was a
placebo (surfaces a count to humans, doesn't feed compacted errors back to the
LLM), (b) Task 5 hook trailer was technically wrong (3 of 4 PreToolUse hooks
are Python — bash trailer can't be appended), (c) STATE_INDEX.md was the wrong
primitive per CEO ("2014 wiki-thinking, F5 spirit is unified state object the
agent reads, not another doc humans grep"), (d) effort/output ratio inverted —
1.5h planning for a minor bump = meta-project drift. User aborted cleanly per
the new `feedback-trigger-driven-shipping` memory: workflow-completion inertia
< trigger-driven shipping discipline.

The artifacts (design doc, deep-research report, autoplan with reviews) live at
`~/.gstack/projects/seungwonkim-v6x-MySystem/` for the next time a real trigger
("2nd time I couldn't find an ADR" / native equivalent doesn't ship) makes this
work load-bearing. Until then, the gbrain-as-memory-layer reactivation captures
more of the underlying retrieval intent at lower cost than F5/F9 hook infra
would have.

---

## [0.39.0] - 2026-05-20

### Added — md→html auto-preview hook (system-wide PostToolUse)

**Hook**: New `hooks/render-md.sh` wired as a PostToolUse handler on
`Write|Edit|MultiEdit`. Auto-renders any markdown file written by Claude
(in any repo) to `~/.claude/previews/latest-md.html`. Open it once in VS
Code Live Preview; every subsequent md write refreshes the view
automatically.

**Motivation**: v0.38.0 produced 5 markdown artifacts (design doc +
research + autoplan + ADR-0008 + .out-of-scope) totaling ~28KB. The user
had to open each as raw .md text. The existing v0.32.0 Stop-event preview
(`latest.html`) captures the last assistant turn, not file writes — a
different signal. This hook closes the gap for file artifacts without
disturbing the turn-based preview.

**Reuses verbatim**:
- `hooks/preview-template.html` (kami-parchment, marked.js render
  pipeline, Source Serif Pro + IBM Plex Mono)
- The jq + sed + base64 + atomic-rename pattern from
  `hooks/preview-stop.sh`
- `~/.claude/previews/` output directory

**Different signal from latest.html**:
- `latest.html`    = last substantive assistant turn (Stop event)
- `latest-md.html` = last markdown file written (PostToolUse event)
- Both update independently; neither replaces the other.

**Filters (skip render)**:
- Not a `.md` file (case-insensitive)
- File >256KB (sed-arg sanity ceiling)
- Path under `~/.claude/previews/`, `~/.claude/external-skills/`,
  `~/.claude/skills/gstack/`, `~/.claude/references/`, `~/.gstack/`,
  `*/node_modules/`, `*/.git/`, `*/__pycache__/`, `*/.next/`, `*/dist/`,
  `*/build/`
- File unreadable / missing (handles mid-rename Edit races)

**Fail-open guarantee**: PostToolUse hooks **cannot block tools** per
Claude Code docs (`code.claude.com/docs/en/hooks`). Render errors are
logged to `~/.claude/logs/md-render.log`; the original Write/Edit always
succeeds. `set -e` deliberately omitted from the hook so internal errors
log+continue rather than propagate.

**Re-entrancy**: Doc-confirmed safe. Hook commands are subprocesses;
filesystem writes from inside the hook do not invoke Claude's Write/Edit
tool and therefore do not re-trigger PostToolUse. The
`~/.claude/previews/` path-prefix filter is belt-and-suspenders.

**System-wide by construction**: Lives in `~/.claude/settings.json`, so
the hook fires equally in MySystem, vProp, cc-guard, and any future
repo. Cross-repo adoption requires zero per-repo configuration.

**Sidecar `latest-md.md`**: Mirrors v0.32.0 pattern — the raw source
markdown is copied to `~/.claude/previews/latest-md.md` for grep /
re-render convenience.

### Files

- `hooks/render-md.sh` — new (~80 lines bash, `chmod +x`)
- `settings.json` — `+1 PostToolUse[]` block (the 5 PreToolUse hook
  scripts and their sha256 hashes are untouched; v0.38.0 K1 baseline
  `4607c437c7b8fe126bd440157afddf473a1447cf4031e2e3f4107cf20cdaa90a`
  remains valid)
- `CHANGELOG.md` — this entry
- `VERSION` — 0.38.0 → 0.39.0

### Plan invariants verified

- ✅ CLAUDE.md unchanged (workflow contract intact)
- ✅ 5 PreToolUse hook scripts unchanged (sha256 baseline preserved)
- ✅ `hooks/preview-stop.sh` + `hooks/preview-template.html` unchanged
- ✅ Fail-open by mechanism (PostToolUse can't block)
- ✅ Cross-repo by construction (settings.json applies globally)

### Hook-enforcement candidates

(None this release — this release IS a harness migration, taking a manual
"open and read every md file" loop and moving it to PostToolUse hook
enforcement.)

## [0.38.0] - 2026-05-20

Theme: **Activate gbrain as experimental retrieval sidecar — fill the
conversation/decision/reasoning layer gap; document agentmemory rejection.**

The 7 memory layers from v0.37.0 (auto-memory, gstack artifacts,
learnings.jsonl, timeline.jsonl, references/, ADRs, CONTEXT.md) all
miss one thing: the back-and-forth of a live session — user reframes,
dismissed-but-later-right options, the chain of reasoning that never
crystallizes into an ADR. gbrain (gstack's sibling tool, same
maintainer) fills that gap and was already cited by every gstack skill
preamble, just silently taking the "not configured" branch on this
machine. v0.38.0 activates it.

Framed as an **experimental sidecar**, not a canonical layer. CLAUDE.md
+ ADRs + CONTEXT.md remain the source-of-truth contract; gbrain is
additive (capture-first) augment. Kill criteria K1-K4 in ADR-0008 are
safety triggers (hook installed / upstream abandoned / Anthropic native
ships / workflow disruption), not arbitrary search-count thresholds.

### Added

- **gbrain CLI activated via Bun global install** with SHA pin
  `bc9f7774bf85c14113d799af73bdb2234a203f3a` (gbrain v0.37.0.0,
  2026-05-20T01:12:01Z). Install command:
  `bun install -g git+https://github.com/garrytan/gbrain.git#<sha>`.
  Pinning rationale: gbrain ships 2-4 minor/patch bumps per day with
  schema migrations in nearly every minor and no GitHub Releases tags
  — tracking master is unsafe. Pattern adapted from ADR-0007 for
  Bun-installed CLI (mechanics differ: refresh uses
  `gh api repos/garrytan/gbrain/compare/<old>..master`, not local git
  log on a clone).
- **PGLite engine** at `~/.gbrain/brain.pglite/` (in-process WASM
  Postgres, zero accounts, ~2s init, 78 migrations applied).
  `~/.gbrain/config.json` at mode 0600.
- **Claude Code MCP registration** at user scope, stdio transport,
  absolute bin path. Written directly to `~/.claude.json`
  mcpServers.gbrain (no `claude` CLI in this VSCode-native
  environment). Existing entries (firecrawl, notion, pencil, stitch)
  preserved.
- **Per-remote policy** = `read-write` for
  github.com/seungwonkim-v6x/mysystem (the source repo).
- **gstack config:** `artifacts_sync_mode=off` (local-only — Supabase
  + cross-machine deferred), `transcript_ingest_mode=incremental`
  (capture forward, no historical bulk).
- **[ADR-0008](docs/adr/0008-gbrain-as-memory-layer.md)** records the
  full activation decision, SHA-pin refresh process, K1-K4 kill
  criteria, corpus retention policy, and CLAUDE.md-untouched
  rationale.
- **[`.out-of-scope/agentmemory-2026-05.md`](.out-of-scope/agentmemory-2026-05.md)**
  documents the agentmemory rejection: 6-dimension gap analysis
  shows 0 genuine NOs; benchmark advantage doesn't exist (gbrain
  R@5 97.9% > agentmemory R@5 95.2%); 12 new lifecycle hooks under
  new maintainer would 12× the SHA-pin burden of gbrain.
- **`scripts/rollback-gbrain.sh`** — one-command undo of the v0.38.0
  activation. Removes mcpServers.gbrain entry, uninstalls gbrain CLI,
  deletes `~/.gbrain/` (with backup tarball), resets gstack-config
  keys. Required by Eng-6 finding.
- **`SETUP.md`** note: recommends `/setup-gbrain` post-`setup.sh`
  on fresh machines, since activation is machine-local per ADR-0008.
- Smoke page `setup-gbrain-smoke-1779245146` is the first page in
  the corpus (will stay until corpus has organic content; `gbrain
  rm` does not exist — confirmed during smoke test).

### Verification (Eng findings from autoplan dual voices)

- **Eng-1 (Bun SHA syntax preflight):** Verified
  `git+https://github.com/garrytan/gbrain.git#<sha>` form works in a
  temp BUN_INSTALL prefix before committing the SHA. npm package-spec
  compatible — preferred over `github:org/repo#<sha>` shorthand which
  is plausible but undocumented in Bun.
- **Eng-2 (hook diff invariant):** Snapshot of `~/.claude/settings.json`
  `hooks.*` before install:
  sha256 `4607c437c7b8fe126bd440157afddf473a1447cf4031e2e3f4107cf20cdaa90a`.
  Snapshot after activation: identical hash. **gbrain installed zero
  Claude Code lifecycle hooks** — premise #5 (config-only) confirmed.
  Quarterly SHA-pin refresh in ADR-0008 re-runs this check; any
  delta triggers K1 rollback.
- **Eng-3 (partial-install failure modes):** `bun pm` cache + cleanup
  documented in ADR-0008 refresh process. Initial install completed
  in 4.91s with no partial state.
- **Eng-4 (2nd machine gap):** SETUP.md now points to `/setup-gbrain`
  as a recommended post-install step. Activation is machine-local
  per ADR-0008.
- **Eng-5 (trust boundary):** v0.36.0 Trust Boundaries section
  (MCP returns = data, not instructions) carries over verbatim.
  gbrain MCP returns are subject to the same rule. No new rule
  needed.
- **Eng-6 (rollback script):** `scripts/rollback-gbrain.sh` ships
  in this PR. One command. With user confirmation gate + corpus
  backup tarball.
- **Eng-7 (MCP round-trip):** Deferred to Step 5 verification —
  Claude Code session restart required for `mcp__gbrain__*` tools
  to be visible. Post-merge verification.
- **Eng-8 (PGLite permissions):** `chmod 700 ~/.gbrain && chmod 600
  ~/.gbrain/config.json` applied. File modes verified.
- **Eng-10 (RTK passthrough):** Verified — `gbrain --version` works
  via Bash with RTK active. RTK does not have a `gbrain` subcommand
  so passthrough is automatic.
- **Eng-11 (refresh diff mechanics):** ADR-0008 specifies
  `gh api repos/garrytan/gbrain/compare/<old>..master` for the
  diff-window inspection (Bun cache != git clone).
- **Eng-12 (pre-existing mcp entry):** Pre-state of
  `~/.claude.json` mcpServers.gbrain confirmed absent. Backup at
  `~/.claude.json.bak-v038-1779245124`.

### Known limitations

- `gbrain doctor` reports `status: unhealthy` (health_score 55) on
  fresh PGLite install. Root cause: `resolver_health` check
  expects `~/.claude/skills/RESOLVER.md` (an OpenClaw pattern, N/A
  for MySystem's CLAUDE.md-based routing). Plus expected `warn`
  states on `embeddings` / `brain_score` (empty corpus) and
  PGLite-specific "could not check" states for pgvector RLS /
  jsonb_integrity. **Functionally OK** — connection succeeds,
  schema 78 latest, FK clean, smoke test passed. Documented in
  ADR-0008 so future re-runs don't trigger false K4 alarms.
- Bun 1.3.5 is below gbrain's stated minimum (`>=1.3.10` in
  package.json engines). engines is enforced as a soft preference
  by Bun, not a hard gate — install + run succeeded. Upgrade Bun
  at user's convenience.
- gbrain corpus initially contains 1 smoke-test page. Organic
  ingest via the `signal-detector` skill (inside gbrain's own
  agent prompt loop, not via Claude Code hooks) populates it over
  normal use. No bulk historical ingest.

### Not changed

- `CLAUDE.md` (workflow contract untouched — `/setup-gbrain`
  Step 8 normally writes a `## GBrain Configuration` block; we
  skipped that step per the plan).
- `setup.sh` (gbrain is not a SPARSE_SKILL; per-machine activation).
- `hooks/` (no new lifecycle hooks).
- `settings.json` (MCP entry lives in `~/.claude.json`, untracked).
- The 5 PreToolUse hooks (secret-scanner, dangerous-command-blocker,
  env-file-protection, block-dangerous-git, RTK) — matchers + scripts
  identical, sha256 `4607c437c7b8fe126bd440157afddf473a1447cf4031e2e3f4107cf20cdaa90a`.

### Tracked-repo additions (machine-independent)

- `.gitignore` (+4 lines: `scripts/` whitelist so the rollback script ships).
- `scripts/rollback-gbrain.sh` (new — destructive ops require `--yes` flag or
  interactive tty confirmation; backup tarball must succeed before corpus delete).
- `docs/adr/0008-gbrain-as-memory-layer.md` (new — activation decision + SHA-pin
  refresh + K1-K4 kill criteria + corpus retention policy).
- `.out-of-scope/agentmemory-2026-05.md` (new — agentmemory rejection rationale).
- `SETUP.md` (+19 lines — post-install /setup-gbrain note for fresh machines).
- `CHANGELOG.md` + `VERSION` — this entry.

Nothing gbrain-runtime-related lives in the tracked repo: `~/.gbrain/config.json`
and `~/.claude.json mcpServers.gbrain` are machine-local per ADR-0008.

### Hook-enforcement candidates

(per the v0.36.0 CRITICAL RULE — paired-hook hopefuls for prompt-only
rules added this release)

- **K1 hook-installed check** — could be a PreToolUse hook on `bun`
  invocations that diffs `~/.claude/settings.json` `hooks.*` before/after
  any `bun install -g` to gbrain. Currently manual at quarterly refresh.
- **K4 workflow-disruption telemetry** — could be a PostToolUse hook
  on `mcp__gbrain__*` tool calls that logs error rate + latency, with
  a threshold trigger that surfaces to /retro. Currently relies on
  user noticing.

### Decision evidence

- Office-hours design doc: `~/.gstack/projects/seungwonkim-v6x-MySystem/seungwonkim-main-design-20260520-111035.md`
- Deep-research report: `~/.gstack/projects/seungwonkim-v6x-MySystem/gbrain-vs-agentmemory-research-20260520.md`
- Autoplan with 4 dual voices + final gate: `~/.gstack/projects/seungwonkim-v6x-MySystem/seungwonkim-main-autoplan-20260520-v0.38.md`

### Attribution

- `gbrain` by Garry Tan (https://github.com/garrytan/gbrain) — MIT.
- 4 reviewer voices (CEO subagent, CEO codex, Eng subagent, Eng codex)
  surfaced the reframe from "canonical activation" to "experimental
  sidecar" + 10 mechanical fixes (Eng-1 through Eng-12). User
  feedback during the final gate corrected the kill-criteria framing
  from "<5 searches in 30 days" (wrong KPI) to safety-only K1-K4
  triggers (capture itself has value from day 1; retrieval frequency
  is downstream).

---

## [0.37.0] - 2026-05-18

Theme: **Skill cherry-pick batch — 8 new SPARSE_SKILLS + SHA pinning for autonomous picks.**

Translates the v0.36.0 best-practices research catalog
(`~/.gstack/projects/seungwonkim-v6x-MySystem/best-practices-research-20260518.md`)
into 8 new external skill installations via `SPARSE_SKILLS`. 4 are added
to the autonomous workflow whitelist (in CLAUDE.md Step → Skill Mapping);
4 are user-invoked only.

### Added — 8 SPARSE_SKILLS entries

**obra/superpowers (Iron Law skills):**
- `verification-before-completion` — autonomous Step 5 augment. SHA-pinned to `f2cbfbefebbf`.
- `test-driven-development` — user-invoked Step 4 modifier. Unpinned (manual invocation = source visible to user).

**mattpocock/skills (engineering bucket):**
- `diagnose` — autonomous Debug Step 1 alternate. SHA-pinned to `e74f0061bb67`.
- `grill-with-docs` — autonomous pre-Step-3 option. SHA-pinned to `e74f0061bb67`.
- `prototype` — user-invoked throwaway runnable code. Unpinned.
- `triage` — user-invoked issue management (collaborative repos). Unpinned.
- `zoom-out` — user-invoked navigation aid. Unpinned.

**mattpocock/skills (productivity bucket):**
- `handoff` — autonomous cross-agent continuation doc. SHA-pinned to `e74f0061bb67`.

### Added — `setup.sh` format extension (amends ADR-0005)

`SPARSE_SKILLS` entries now accept an **optional 5th field** for commit
SHA. When present, `setup.sh` runs `git checkout <SHA>` after clone
instead of tracking branch tip. If the SHA becomes unreachable (upstream
history rewrite), setup.sh exits 1 with a clear remediation message.

**Pin policy** (per ADR-0007):
- **Autonomous skills MUST be pinned** — supply-chain mitigation. The
  agent invokes these silently; a compromised upstream commit would
  become live behavior.
- **User-invoked skills MAY remain unpinned** — owner sees the content
  before invocation, so silent drift is acceptable.

This is the smallest possible amendment to ADR-0005's "unpinned by
design" original: it pins 4 of 11 entries (the 4 autonomous v0.37.0
adds). The 2 pre-existing unpinned entries (requesting-code-review,
deep-research) stay unpinned for backward compatibility.

### Added — ADR-0007

[`docs/adr/0007-skill-cherry-pick-batch-v0.37.md`](docs/adr/0007-skill-cherry-pick-batch-v0.37.md) documents the batch decisions:
- Per-skill rationale + autonomy classification
- ADR-0005 amendment for SHA pinning
- setup.sh format extension
- Initial SHA capture (2026-05-18 via `gh api`)
- Refresh log template for future pin bumps

### Updated — CLAUDE.md

- **Step → Skill Mapping** now references the 4 autonomous v0.37.0 skills
  inline (with their workflow integration points).
- **New "v0.37.0 skill additions — invocation policy" section** under
  Step → Skill Mapping spells out autonomous vs user-invoked
  classification + the SHA-pin gradient.

### Updated — references/INDEX.md

New "Skill authoring" section (not clone targets, just citable docs):
- `anthropics/skills` SKILL.md authoring contract (2-field frontmatter,
  body <500 lines, pushy descriptions, explain WHY over ALL-CAPS — with
  documented data-hygiene exception per
  `.out-of-scope/all-caps-rules-in-user-owned-skills.md`)
- `wshobson/agents` sub-agent frontmatter convention (name + description
  + model + 5-section body)

### Updated — README.md and SETUP.md

`SPARSE_SKILLS` table grows from 2 to 10 rows. New rows show:
- Pin status (pinned <SHA> vs unpinned)
- Notes column maps each skill to its workflow role + invocation mode

### What did NOT change

- 8-step workflow (Steps 1-8 + Debug Step 1 alternate) — autonomous
  skills augment existing steps, don't add new steps.
- gstack full clone — unchanged.
- Plugin marketplace mechanism — unchanged.
- ADR-0005 itself — amended via ADR-0007's reference but not edited.
- Reference repos (12 clones in `references/`) — unchanged.

### Process

Step 5 verification skipped (no behavior to test mechanically — skills
are external clones the user fetches via `setup.sh`). /review focused on
internal consistency between CLAUDE.md whitelist, setup.sh format, and
ADR-0007 claims. /requesting-code-review focused on supply-chain edge
cases (e.g., upstream rewriting history past pinned SHA, refresh process
realism, repo-rename handling).

### Hook-enforcement candidates

Per v0.36.0's "every CRITICAL RULE should aspire to harness enforcement"
sweep heading. Tracking these for next-patch consideration:

- **SHA-pin tampering detection** — Could be enforced by a setup.sh
  post-clone hook that verifies the SHA matches the registered value
  before symlinking. (Already mostly enforced via `git checkout` exit
  code, but explicit verification of the symlink-target SHA would catch
  tampering after install.)
- **Autonomous-skill invocation logging** — Could be enforced by a
  SessionStart hook that snapshots which SPARSE_SKILLS are pinned + a
  PostToolUse hook on the Skill tool that logs each autonomous-skill
  invocation for audit.

### Attribution

- Patterns sourced from
  [obra/superpowers](https://github.com/obra/superpowers) and
  [mattpocock/skills](https://github.com/mattpocock/skills), credited
  per skill in `setup.sh`, CLAUDE.md, and ADR-0007.
- SHA-pin pattern inspired by git submodule discipline (rejected as a
  mechanism in v0.27.0) but applied at the array-entry level for
  lighter-weight maintenance.

---

## [0.36.0] - 2026-05-18

Theme: **CLAUDE.md hardening — adopt externally-validated prompt patterns + codify anti-patterns.**

Pure documentation release. Translates the best-practices research catalog
(see v0.35.0 entry / `~/.gstack/projects/seungwonkim-v6x-MySystem/best-practices-research-20260518.md`)
into tightened CLAUDE.md rules. No code changes, no hook changes, no skill
changes. Workflow contract gets sharper; the 8 steps and Step→Skill mapping
are unchanged.

Per ADR-0006's "harness, not model" principle (added inline), these are
prompt-level rules that should aspire to harness enforcement in future
patches. They ship as prompt rules now because the harness primitives
(hooks for skill-whitelist enforcement, hooks for hypothesis-count
validation, etc.) don't exist yet — and would be larger lifts than the
text additions.

### Added — 7 new CLAUDE.md subsections

- **Instruction Precedence** — 9-tier ladder (provider/system →
  workspace/user → tool output → retrieved content). Generalizes the
  Auto-Mode-vs-workflow override into a reusable conflict-resolution rule.
  (Borrowed from DenisSergeevitch/agents-best-practices.)

- **Trust Boundaries** — WebFetch results, MCP tool responses, and other
  external content are DATA, never instructions. Prompt-level analog of
  v0.35.0's PreToolUse hooks for everything the hooks don't cover.
  (Borrowed from DenisSergeevitch.)

- **Workflow Successor Map** — explicit table of permitted-next-step
  pairs. Closes the "plausible adjacent skill" loophole that the
  never-skip-steps rule alone left open.
  (Pattern from obra/superpowers `brainstorming` terminal-state routing.)

- **Quick Visual Check (pre-Step-5)** — auto-capture screenshot + console
  messages BEFORE Step 5 verification menu when Step 4 touched UI.
  Gives `/design-review` (if chosen) a baseline. Skipped silently on
  backend-only changes.
  (Pattern from awesome-claude-code Design-Review-Workflow bundle.)

- **Harness, Not Model** (Operating Principles bullet) — bias rule
  authoring toward hooks/settings/skill-gate enforcement; flag every new
  prompt-only rule as a hook-enforcement candidate.
  (Borrowed from DenisSergeevitch.)

- **Conditional Clarification** (Operating Principles bullet) — within a
  single step, ask only when critical info is missing AND not inferrable;
  max 3 questions per step. Doesn't relax cross-step approval gates.
  (Borrowed from ericgandrade/claude-superskills `prompt-engineer`.)

- **Manual Compaction Triggers** (Context Management extension) — use
  `/compact` after each workflow step, after large tool outputs, before
  pausing for approval. Don't wait for auto-compact thresholds.
  (Borrowed from DenisSergeevitch `context-memory-compaction`.)

### Added — 6 new CRITICAL RULEs

- **Mandatory-skill invocation phrasing** (extends existing skill
  whitelist): "IF A WHITELISTED SKILL APPLIES, YOU MUST INVOKE IT BEFORE
  RESPONDING." Inverts the permission framing into an obligation.
  (Borrowed from obra/superpowers `using-superpowers`.)

- **Per-file commits are an anti-pattern** (Self-Management) — commits
  scope to single logical changes, not single files. Explicitly inverts
  shanraisshan/claude-code-best-practice's "one commit per file" rule.

- **Every CRITICAL RULE should aspire to harness enforcement** (Operating
  Principles) — prompt-only rules rot under context pressure; log each as
  a future hook-enforcement candidate.

- **Repeated multi-step prompts are missing skills** (Operating
  Principles) — the third repetition of a hand-walked dance is a
  promotion-to-skill trigger.
  (Anti-pattern from shanraisshan, inverted into action rule.)

- **NEVER install PostToolUse hooks that auto-create git commits**
  (Self-Management — new Forbidden Patterns subsection). Commits come
  only from `/ship` or explicit user request.
  (Anti-pattern from davila7 `smart-commit.json`, rejected.)

- **Vertical-slice TDD only** (Operating Principles) — one test → one
  implementation → repeat, never batch test-writing then batch
  implementation. Auto Mode's "boil the lake" instinct can push toward
  batch writing during Step 4; this rule overrides.
  (Borrowed from mattpocock/skills `tdd` skill.)

- **3-5 ranked falsifiable hypotheses for debug Step 1** (Debugging
  workflow) — break the single-plausible-hypothesis anchor. Plus "after 3
  failed fixes, question the architecture" rule for fix-rathole exit.
  (Borrowed from mattpocock/skills `diagnose` + obra/superpowers
  `systematic-debugging`.)

### Added — .out-of-scope entry

- [`.out-of-scope/all-caps-rules-in-user-owned-skills.md`](.out-of-scope/all-caps-rules-in-user-owned-skills.md) —
  documents why Anthropic's official "don't write ALL-CAPS NEVER/ALWAYS in
  skill bodies" guidance is **rejected for the CLAUDE.md workflow contract
  specifically** but **accepted for user-owned skills under `skills/`**.
  The Instruction Precedence ladder formalizes the level distinction.

### Process

No /verify-test (text-only changes; no behavior to verify mechanically).
/review focused on internal consistency (no contradictions between new
rules and old). /requesting-code-review focused on whether the new rules
materially close loopholes in the existing workflow.

### What did NOT change

- 8-step workflow and Step→Skill mapping (unchanged from v0.34.0).
- Any skill file (`skills/verify-test/` unchanged).
- Any hook (`hooks/*` unchanged from v0.35.0).
- VERSION bump is **minor** because the workflow contract is sharpened,
  not changed. The agent already followed all 8 steps in order; v0.36.0
  just makes that harder to misread.

### Attribution

All borrowed patterns credited in the relevant CLAUDE.md section with
upstream source. Anti-patterns sourced from shanraisshan, davila7, and
mattpocock as noted in each CRITICAL RULE.

### Post-review hardening (applied during /review + /requesting-code-review)

`/review` caught 3 issues fixed inline: Auto-Mode reminders mis-classified in
Instruction Precedence ladder (level 1-3 → level 7, fixing direct
contradiction with existing Auto Mode CRITICAL RULE); Workflow Successor
Map ambiguous on user-typed off-workflow skills (now explicit); Trust
Boundaries missed sub-agent outputs (now covered).

`/requesting-code-review` (2nd-pass) caught 3 critical + 6 important fixed
inline:

- **C1** mandatory-skill-invocation + conditional-clarification interaction:
  added explicit precedence note ("3-question budget covers within-skill
  clarification, NOT skill-selection deliberation").
- **C2** Workflow Successor Map silently forbade `/retro` and other
  off-workflow utilities: enumerated allowed user-typed skills explicitly.
- **C3** mandatory-invocation lacked triviality carve-out: added scope
  qualifier (typo / single-char / comment-only / explicit-trivial framing).
- **I1** Auto-commit ban was under-broad (text said commits only, spirit
  covered all git-state mutation): generalized to "PostToolUse hooks that
  mutate git state — stage, commit, amend, push, PR-create".
- **I3** "Log as hook-enforcement candidate" had no target file: now
  specifies a `### Hook-enforcement candidates` heading in the active
  CHANGELOG entry, swept during patch-release planning.
- **I4** `.out-of-scope/all-caps-rules-in-user-owned-skills.md` claimed
  `/verify-test` follows Anthropic's reasoned-prose convention, but
  verify-test has 2 ALL-CAPS rules ("ALWAYS delete test files...", "tests
  NEVER staged..."). Added a "Documented exception: data-hygiene rules"
  section to the .out-of-scope entry — ALL-CAPS permitted for irreversible
  side-effect / one-way-door classes; behavioral rules still use prose.
- **I5** Instruction Precedence level 3 conflated CLAUDE.md prose with
  settings.json hooks (different bypass semantics): split into 3a
  (hook-enforced safety, effectively constitutional) and 3b (prompt rules,
  bypassable).
- **I6** voice drift in 3 spots: cleaned the "obra/superpowers
  systematic-debugging rule applies" inline-attribution drift into a
  proper imperative + closing parenthetical, matching the convention used
  elsewhere.

Remaining issues from /requesting-code-review deferred to v0.36.1 or later
with rationale in the review log:
- I2 (3-5 hypotheses operability — needs a worked example, sizable
  addition)
- M1-M4 (minor wording / future-proofing / Playwright availability)

### Hook-enforcement candidates

Tracking section per the new "Every CRITICAL RULE should aspire to harness
enforcement" rule. Each entry: rule name + one-sentence hook event that
could enforce it. Reviewed at next patch-release planning to decide which
to promote to actual hooks.

- **Mandatory-skill-invocation** — Could be enforced by a session-start
  hook that lists whitelisted skills + a UserPromptSubmit hook that flags
  when the agent's response begins without a skill invocation for a
  feature/bug-level request. (Heuristic; needs LLM-judge component.)
- **Vertical-slice TDD** — Could be enforced by a PostToolUse(Write) hook
  that detects "new test file + no corresponding implementation file
  modified" and surfaces a warning.
- **3-5 ranked hypotheses for debug** — Could be enforced by a
  PreToolUse(Edit|Write) hook on bug-fix branches that checks for a
  hypothesis-list artifact (e.g. `~/.gstack/projects/<slug>/<branch>-hypotheses.md`)
  before allowing code edits.
- **Never auto-mutate git state** — Could be enforced by a settings.json
  hook-validation step that scans `hooks.PostToolUse` for any command
  containing `git add`, `git commit`, `git push`, `gh pr create`.

---

## [0.35.0] - 2026-05-18

Theme: **Security defense-in-depth — always-on PreToolUse hooks (dry-run first).**

Closes the always-on safety gap: until now, destructive-command protection lived
only in opt-in `/careful` and `/guard` skills (user had to remember). v0.35.0
adopts 4 hand-vendored PreToolUse hooks that fire unconditionally for
catastrophic operations. Ships in **dry-run mode** (`MYSYSTEM_HOOKS_ENFORCE`
unset); a v0.35.1 patch flips to enforce after a 48-hour zero-false-positive
observation window per the calibrate-before-enforce pattern.

Source: best-practices research catalog
(`~/.gstack/projects/seungwonkim-v6x-MySystem/best-practices-research-20260518.md`,
44 patterns across 10 repos). Reviewer-driven revisions (Claude subagent
CEO + Eng reviews) applied: fail-open templates, hand-vendor with attribution,
hard-refuse for force-push to main, dry-run mode, simplified hook-ordering
rationale. See [ADR-0006](docs/adr/0006-defense-in-depth-pretooluse-hooks.md).

### Added — 4 PreToolUse hooks (hand-vendored, fail-open, dry-run default)

- **`hooks/secret-scanner.py`** — intercepts `git commit` variants. Scans
  staged diff against 11 regexes (Anthropic, OpenAI, AWS, Stripe, GitHub,
  Slack, MongoDB/MySQL/Postgres connection strings, JWT). Hard-refuses 2
  private-key header patterns regardless of bypass. Soft-bypass:
  `MYSYSTEM_ALLOW_SECRET_COMMIT=1` for intentional test fixtures.
  Adapted from davila7/claude-code-templates.

- **`hooks/dangerous-command-blocker.py`** — blocks `rm -rf /` on system
  paths (allows `/tmp/`, `/private/tmp/`, `/var/folders/`), `dd` to block
  devices, `mkfs`, redirects into `.git/` and `.claude/`, shred `-u`, fork
  bombs, `curl | bash`. No bypass — manual UI for legitimate use.
  Adapted from davila7/claude-code-templates.

- **`hooks/env-file-protection.py`** — blocks Write/Edit/MultiEdit on any
  `.env*` path. Rewritten from upstream's matcher-conditional approach to
  portable Python check on `tool_input.file_path`. No bypass.
  Adapted from davila7/claude-code-templates.

- **`hooks/block-dangerous-git.sh`** — blocks `git push`, `git push --force`,
  `git reset --hard`, `git clean -f[d]`, `git branch -D`, `git checkout .`,
  `git restore .`. **Hard-refuses force-push to origin main/master regardless
  of `MYSYSTEM_ALLOW_FORCE_PUSH=1`** (prompt-injection defense — env var
  could be set by injected tool output). Bypass works only for feature
  branches. Adapted from mattpocock/skills git-guardrails-claude-code.

All 4 scripts wrap their logic in try/except → log to
`~/.claude/logs/hook-errors.log` → exit 0 on internal error (**fail-open**).
A buggy hook never bricks the workflow.

### Added — settings.json hardening

- **`permissions.ask`** list — 10 risk-tiered Bash patterns (rm, rmdir,
  shred, dd, mkfs, chmod, chown, kill, killall, pkill). Always-on
  confirmation prompt without breaking flow on read-only ops. Package
  managers deliberately excluded (would prompt-spam during normal dev).
  Adapted from shanraisshan/claude-code-best-practice.

- **`respectGitignore: true`** — keeps `node_modules/`, `.venv/`, build
  outputs out of search index. Adapted from shanraisshan.

- **PreToolUse hook ordering** — 3 Bash blockers prepended before existing
  `rtk hook claude` so BLOCKED stderr messages surface uncompressed.
  Each PreToolUse hook receives the original `tool_input` independently —
  the original "rtk pipeline-mutates downstream" claim in draft v1 of the
  plan was wrong; corrected in ADR-0006.

### Added — Stop hook desktop notification

- **`hooks/preview-stop.sh`** — appended `osascript -e 'display
  notification ...'` (macOS conditional, fail-silent). Existing kami HTML
  preview rendering unchanged. Adapted from davila7.

### Added — operational infrastructure

- `~/.claude/logs/hook-errors.log` and `hook-dry-run.log` (created on
  first hook fire). Use `tail -f ~/.claude/logs/hook-dry-run.log` to watch
  what WOULD have been blocked during the 48-hour observation window.

### Decisions deliberately NOT changed

- **`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` stays at `25`** (not bumped to 80 as
  the shanraisshan template suggests). v7.1.0 deliberately set it to 25
  for Opus 4.7's 1M context; RTK.md documents the rationale. The general
  advice doesn't apply when context is 4× larger. Logged in ADR-0006
  "Decisions deferred" section.

### Verification — required before v0.35.1 enforce flip

1. Benchmark per-Bash overhead < 200ms (Python cold-start × 2 + bash × 1).
   Record to `~/.gstack/projects/seungwonkim-v6x-MySystem/v0.35.0-hook-benchmark.md`.
2. Run normal workflow 48 hours with `MYSYSTEM_HOOKS_ENFORCE` unset.
   Review `~/.claude/logs/hook-dry-run.log`. Zero false positives required.
3. End-to-end /ship dry-run: verify gstack's `git push` (with
   `MYSYSTEM_ALLOW_FORCE_PUSH=1`) succeeds for feature branches AND that
   force-push to `origin main` is still hard-refused.
4. Fail-open verification: manually break one hook (add `1/0` to Python or
   garbage line to bash); confirm Bash commands still proceed; error
   logged to `hook-errors.log`.

When all 4 pass: edit `settings.json` to add `"MYSYSTEM_HOOKS_ENFORCE": "1"`
in the `env` block, bump VERSION to 0.35.1, document in CHANGELOG, tag.

### Rollback

Each hook is independently removable:
1. Delete the script from `hooks/`
2. Remove the corresponding entry from `settings.json` `hooks.PreToolUse`
3. Tag as v0.35.x patch with revert note

If `permissions.ask` becomes too noisy: trim the list (no full revert needed).

### Documentation

- [ADR-0006](docs/adr/0006-defense-in-depth-pretooluse-hooks.md) — captures
  the design decisions, reviewer concerns, and alternatives considered.

### Attribution

- Hook script logic adapted from
  [davila7/claude-code-templates](https://github.com/davila7/claude-code-templates)
  (secret-scanner, dangerous-command-blocker, env-file-protection,
  desktop-notification-on-stop) and
  [mattpocock/skills](https://github.com/mattpocock/skills)
  (git-guardrails-claude-code). Settings.json patterns
  (`permissions.ask`, `respectGitignore`) from
  [shanraisshan/claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice).
  License verification at vendor time (MIT/Apache assumed; verify upstream
  before next refresh).

### Post-review hardening (applied during /review + /requesting-code-review)

A 2nd-pass adversarial review surfaced 4 critical + 8 important findings.
All criticals + actionable importants addressed inline before /ship; remaining
items documented in ADR-0006 with rationale.

- **Hard-refuse for force-push to main/master** now covers all known refspec
  variants: `--force origin main`, `--force-with-lease origin main`,
  `HEAD:main`, `+main`, `+refs/heads/main`, and `git -c key=val push ...`
  prefix bypass. Hard-refuse is unconditional regardless of
  `MYSYSTEM_ALLOW_FORCE_PUSH=1`.
- **`rm -rf` detection** broadened to catch separated flags (`rm -r -f`),
  uppercase variants (`-fR`, `-Rf`), and `bash -c "rm -rf /etc"` wrappers.
- **OpenAI key regex** tightened from `sk-[A-Za-z0-9]{32,}` to require the
  `T3BlbkFJ` substring (present in every real key). Eliminates false
  positives on doc placeholders like `sk-EXAMPLE...`.
- **`datetime.utcnow()` deprecation** eliminated across all 3 Python hooks
  (Python 3.13+ compatibility).
- **`.env*` multi-suffix paths** now matched (`.env.production.local`,
  `.env.development.local`, etc.).
- **Absolute-path `.claude/` redirects** now blocked
  (`echo evil > /Users/foo/.claude/CLAUDE.md`).
- **`git -c key=val commit` bypass** in secret-scanner closed (same
  `GIT_VERB` pattern as block-dangerous-git.sh).

---

## [0.34.0] - 2026-05-18

Theme: **Decision-record discipline — borrow mattpocock's structure.**

Adopts three organizational patterns from
[mattpocock/skills](https://github.com/mattpocock/skills) (89k ⭐) without
touching workflow semantics:

### Added — three new tracked surfaces

- **`docs/adr/`** — Architecture Decision Records start landing as real
  documents instead of just a template. Five retrospective ADRs cover the
  big v0.30-0.33 decisions:
  - 0001 workflow harness consolidation
  - 0002 SPARSE_SKILLS install mechanism
  - 0003 references treasure trove
  - 0004 kami-parchment HTML preview hook
  - 0005 plugin marketplace for hook-bearing plugins
- **`.out-of-scope/`** — Explicit "considered, chose no" rationales. Five
  seed entries capture decisions that would otherwise be buried in CHANGELOG
  prose:
  - `learning-goal-paired-skill.md` (deferred 6 weeks, with re-check date)
  - `sparse-skills-for-hook-plugins.md` (technical reason: `${CLAUDE_PLUGIN_ROOT}`)
  - `custom-frequency-wrapper.md` (philosophical reason: "harness, don't build")
  - `superclaude-parallel-system.md` (architectural reason: parallel ≠ complementary)
  - `subagents-directory.md` (zero-invocation reason: 20 unused agent files)
- **`CONTEXT.md`** at the repo root — project glossary. Vocabulary
  (harness-don't-build, skill whitelist, boil the lake, repo mode), 8-step
  workflow shape, install-mechanism table, external-dependency surface, and
  a "what to read first" pointer for onboarding.

### Why borrow from mattpocock

`docs/adr/` and CHANGELOG answer different questions: CHANGELOG captures
*what changed*, ADRs capture *why this trade-off*. Until v0.34.0 MySystem
had only the template for ADRs and zero actual ADRs — a contradiction for
a repo that records lots of trade-offs.

`.out-of-scope/` solves a different gap: decisions to *not* do things
disappear into CHANGELOG prose ("Why not learning-goal", "not a fork", etc.)
and are hard to find when re-deciding six months later. A dedicated file
per "no" gives each rejection a permanent address.

`CONTEXT.md` exists because the project finally has enough vocabulary
(harness-don't-build, skill whitelist, three install mechanisms, repo mode)
that requiring a new reader to derive it from `CLAUDE.md` + CHANGELOG +
git log is wasteful.

### Skipped from mattpocock's pattern

- **Bucket folders** (`skills/engineering/`, `skills/productivity/`, etc.) —
  MySystem's `skills/` has only `verify-test/` as user-owned; everything
  else is external. Bucketing would impose structure on content that isn't
  there.
- **`.claude-plugin/plugin.json`** — MySystem uses `settings.json`
  `enabledPlugins` directly. Different mechanism, no duplication needed.
- **`scripts/list-skills.sh`** — gstack already prints the equivalent.
- **MIT LICENSE + public distribution** — MySystem stays personal for now;
  the "switch to public" decision is its own ADR when (if) it happens.

### .gitignore updates

Whitelists `CONTEXT.md`, `docs/`, `docs/**`, `.out-of-scope/`,
`.out-of-scope/**` under the "ignore everything, whitelist tracked"
strategy.

### Migration

```
cd ~/.claude && git pull
# No script to run. The new directories are docs; no behavior change.
```

## [0.33.0] - 2026-05-17

Theme: **Adopt learning-opportunities — deliberate practice while AI-coding.**

Wires [DrCatHicks/learning-opportunities](https://github.com/DrCatHicks/learning-opportunities)
into MySystem via Claude Code's plugin marketplace mechanism. `learning-opportunities-auto`
nudges Claude to offer a 10-15 minute science-based learning exercise (prediction,
retrieval practice, generation) whenever the Bash tool's command/output contains
both "git" and "commit". Hard cap: 2 offers per session via a session-scoped temp
file; the cap is consumed by false positives too (e.g. `git log`, `git show`).
"Decline → stop offering" is a prompt-level instruction in the hook's
`additionalContext`, **not enforced state** — context compaction may revive offers
within the 2-offer budget.

### Why

The 8-step workflow optimizes task completion; expertise growth is incidental.
For a junior developer with high AI-assist usage, the gap between "AI shipped
it" and "I understand it" compounds silently. learning-opportunities closes
that gap **at the moment of architectural change** — when retrieval practice
costs ~10 minutes but pays back for months.

User insight that drove the adoption choice: "I will never invoke it manually."
If the trigger isn't automatic, the skill is effectively uninstalled.
PostToolUse hook on `git commit` solves that without piling work onto every
Bash invocation.

### Added — three plugins

- **learning-opportunities** — core skill. Offers ≤2 lesson invitations per
  session after architectural work. Built-in pause protocol prevents Claude
  from leaking the answer into the question.
- **learning-opportunities-auto** — PostToolUse hook (matcher: Bash) that
  matches the loose regex `git.*commit` against the Bash payload (commands or
  output), then nudges Claude to consider whether the work warrants a lesson.
  Session-scoped 2-offer cap (`${TMPDIR}/lo_auto_<session>.state`). Decline
  semantics are prompt-only — see CLAUDE.md skill-whitelist exception.
- **orient** — generates a repo-specific `orientation.md` for the core skill.
  Explicit-invocation only (`disable-model-invocation: true`). Useful when
  entering a new codebase (cc-guard, vprop-beatsync, …).

### Settings (single file)

- `settings.json` — `extraKnownMarketplaces.learning-opportunities` registered
  (git URL, tracking the upstream `main` branch — not pinned to a commit;
  unforced upstream changes propagate to every machine on the next session
  start). `enabledPlugins` adds three entries.
- `CLAUDE.md` — explicit exception to the **Skill whitelist** rule documents
  that the PostToolUse auto-nudge is allowed; learning-opportunities operates
  *outside* the 8-step workflow as a single-shot interaction.

### Adoption mechanism — not SPARSE_SKILLS

Initial design assumed `setup.sh` SPARSE_SKILLS would suffice. Deep-research
caught the trap: `learning-opportunities-auto/hooks/hooks.json` invokes
`${CLAUDE_PLUGIN_ROOT}/hooks/post-tool-use.sh`. That environment variable is
**only set by the plugin loader**, not by symlinking the skill directory into
`skills/`. SPARSE_SKILLS would import the files and silently break the hook.
Plugin marketplace registration is the supported integration path; it matches
the existing `claude-plugins-official` pattern in `settings.json`.

### Adoption mechanism — not a fork

learning-opportunities-auto's 2-offer-per-session hard counter is the only
enforced frequency control upstream provides. A custom wrapper (option C in
/office-hours) was rejected — it crosses MySystem's "harness, don't build"
line. Trade-off accepted: looser-than-ideal trigger semantics in exchange for
zero maintenance burden.

### Why not learning-goal (yet)

[DrCatHicks/learning-goal](https://github.com/DrCatHicks/learning-goal) — the
paired pre-work skill that applies Mental Contrasting with Implementation
Intentions before a task — is intentionally deferred. Re-evaluate after six
weeks of learning-opportunities use; premature inclusion = scope creep.

### Migration (other machines)

```
cd ~/.claude && git pull
# Next Claude Code session auto-fetches the new marketplace.
# Verify with: /plugin list  (the three new entries should appear enabled)
```

No setup.sh re-run required; no firecrawl-style API key.

### Attribution

`learning-opportunities`, `learning-opportunities-auto`, and `orient` © Dr.
Cat Hicks 2026 — licensed [CC-BY-4.0](https://creativecommons.org/licenses/by/4.0/),
provided as-is without warranty. Source: <https://github.com/DrCatHicks/learning-opportunities>.

### Verification needed (Step 5)

`git commit` in a new Claude Code session should produce a learning-opportunities
nudge. If it does not after restart, run `/plugin list` and confirm the three
entries show as enabled.

## [0.32.0] - 2026-05-17

Theme: **Auto-render every substantive assistant turn as HTML.**

Adds a Stop hook that captures the last assistant message, writes it to
`~/.claude/previews/latest.{md,html}`, and lets a VS Code Live Preview
panel (or a browser tab) auto-reload it. Markdown stays the wire format;
HTML becomes the read surface.

### Added

- **`hooks/preview-stop.sh`** — Stop hook. Reads the standard stop payload
  from stdin, extracts the last assistant text turn from the transcript
  JSONL via `jq`, skips short / low-signal turns (< 800 chars and no
  markdown structure), base64-embeds the markdown into a static HTML
  template, and writes `latest.md` + `latest.html` atomically.
- **`hooks/preview-template.html`** — kami-parchment editorial template.
  Visual system adapted from
  [nexu-io/html-anything](https://github.com/nexu-io/html-anything)'s
  `doc-kami-parchment` skill (Apache-2.0). Source Serif Pro + IBM Plex
  Mono, parchment ground, ink-blue accent, hairline rules. Mechanism is
  original to MySystem.
- **`settings.json` Stop hook registration** — wires the hook into
  Claude Code.

### Viewer setup (one-time, on the user)

- **VS Code**: install the Live Preview extension
  (`ms-vscode.live-server`), open `~/.claude/previews/latest.html` in it
  once. The extension watches the file and auto-reloads.
- **Browser fallback**: double-click `latest.html` once. Embedded
  `visibilitychange` listener reloads on tab focus.

The hook intentionally does **not** call `open` — that would spawn a new
OS-default tab on every session start.

### Why

Markdown in a CLI sidebar is hard to read for substantive workflow output
(plans, deep-research, reviews). HTML in a side panel is dramatically
better, and the cost is one Stop hook plus a one-time viewer setup. The
short-turn filter keeps the preview from flashing for routine
back-and-forth.

## [0.31.0] - 2026-05-17

Theme: **References — curated treasure trove of CS / AI / design knowledge.**

Introduces a third install mechanism alongside `EXTERNAL_REPOS` (full-clone
skills) and `SPARSE_SKILLS` (cherry-picked skills): `REFERENCE_REPOS`. These
are plain `git clone`s into `references/<name>/` — **not** skills. The agent
greps them when a task touches the matching domain (system design, schema
validation hazards, design systems, etc.) instead of going straight to web
search.

### Added

- **`REFERENCE_REPOS` mechanism in `setup.sh`** — clone-only, no symlinks, no skill
  behaviour. Auto-registered in `.git/info/exclude`.
- **`references/INDEX.md`** (tracked) — curated entry point with "use when"
  hooks for each repo.
- **12 seed reference repos** (~640MB total):
  - Engineering wisdom: `system-design-primer`, `awesome-scalability`,
    `papers-we-love`, `awesome-falsehood`, `awesome-design-patterns`,
    `engineering-blogs`
  - AI / LLM: `awesome-llm`, `awesome-ai-agents`
  - Design / Frontend: `awesome-design-md`, `awesome-design-systems`,
    `awesome-tailwindcss`, `awesome-react-components`
- **CLAUDE.md** — new "Consult References Before Searching the Web" operating
  principle. The agent must grep `references/` before falling back to web
  search when the task touches one of the listed domains.

### Why

The agent burns fresh context rediscovering things the community already
indexed — every name-validation discussion is awesome-falsehood, every
distributed-systems decision is papers-we-love + system-design-primer. Local
clones flip the default: grep first, web second. Cost is disk (~640MB);
upside is faster lookups, version-pinned to last pull, and zero per-query
token cost.

### Updated

- `setup.sh` — new `[4/6]` step for reference repos; `.git/info/exclude`
  generator now also covers `references/<name>/`.
- `.gitignore` — `!references/` + `!references/INDEX.md` whitelisted.
- `README.md`, `SETUP.md` — new sections documenting the references area.

## [0.30.1] - 2026-05-17

Theme: **Pre-commit templates — defense layer below `/review`.**

Adds two template files under `templates/` so any new project can opt into a
fast local hook layer before reaching the LLM `/review` step.

### Added
- `templates/.pre-commit-config.yaml.template` — secrets / lint / format / simple SAST checks, <5s target on small diffs.
- `templates/PRE-COMMIT-SETUP.md` — how to bootstrap in a new project.

### Why
`/review`'s value is in trust boundaries, SQL safety, and conditional side effects — things hooks genuinely can't catch. Catching secrets/style/lint with pre-commit hooks first cuts what `/review` has to look at by 60-70% and keeps LLM tokens spent on the hard stuff.

## [0.30.0] - 2026-05-17

Theme: **Workflow harness consolidation — stop building, start adopting.**

Reshapes the workflow around a strict step→skill mapping. Drops three user-owned
skills that gstack/context7/MCP already cover, replaces `/bugbot` with an
adversarial cherry-picked review from `obra/superpowers`, adds a `/deep-research`
step backed by `affaan-m/everything-claude-code` + firecrawl MCP.

### Workflow

- **Step count: 9 → 8.** Removed `/slow-down` (concretization redundant with `/autoplan`'s plan-writing phase).
- **Step 6 / Step 7 are now adversarial.** `/review` (gstack, structural+SQL+LLM-trust) and `/requesting-code-review` (superpowers, fresh-eye Critical/Important/Minor) both run; clean pass on one does not skip the other.
- **New CLAUDE.md table**: canonical step→skill mapping. The agent must call exactly the listed skill for each step — no substitutions.
- **New CRITICAL RULE**: skill whitelist. Skills outside the mapping table run only when the user types the name. No proactive suggestions for off-workflow skills.

### Skills

- **Removed (4)** — `slow-down`, `search-first`, `documentation-lookup`, `bugbot`. The first three weren't used by the workflow; `bugbot` was replaced by `requesting-code-review`.
- **Added via sparse cherry-pick** — `requesting-code-review` from [obra/superpowers](https://github.com/obra/superpowers), `deep-research` from [affaan-m/everything-claude-code](https://github.com/affaan-m/everything-claude-code).
- **Kept user-owned (1)** — `verify-test`. No public alternative found across 9+ skill collections.

### setup.sh

- New `SPARSE_SKILLS` list (format `"skill-name|url|branch|subpath"`). Clones repo into `external-skills/<name>/` and symlinks one subpath into `skills/<name>/`. Use when you want one skill from a larger collection without inheriting siblings.
- `EXTERNAL_REPOS` (full-clone) and `SPARSE_SKILLS` (cherry-pick) are now the two install mechanisms.
- `.git/info/exclude` regeneration now covers `external-skills/` plus every non-whitelisted skill dir found post-install.

### MCP / Config

- **Added**: `firecrawl` MCP at user level (`~/.claude.json`). Powers `/deep-research`. Key stored as plain text in `mcpServers.firecrawl.env.FIRECRAWL_API_KEY` (file is outside the tracked repo).
- **Scoped to vProp only**: `Playwright`, `trigger` — moved from user-level to `projects."/Users/seungwonkim/Documents/vprop".mcpServers`. They only activate when Claude Code runs inside that workspace, keeping vProp's git tree untouched.
- **Removed**: `dev_manager` (no longer needed).
- **User-level MCPs after this release**: `context7`, `firecrawl`, `pencil` only.

### Cleanup

- Deleted `agents/` (20 files; MySystem never invoked any of them).
- Deleted `commands/sc/` (SuperClaude — parallel system, not part of the harness).
- Deleted stale backups: `settings.json.bak*` (×3), `backup-pre-superclaude-20260507-165651/`, `.mysystem-archive/`, `.skill-update.log`.

### Docs

- `CLAUDE.md` — new step→skill mapping table; skill-whitelist rule; "Harness, Don't Build" principle; self-management rule 7 (mapping changes are major bumps).
- `README.md`, `SETUP.md` — external-dependencies table now distinguishes full-repo from sparse cherry-pick; firecrawl-key bootstrap documented.

### Migration (other machines)

```
cd ~/.claude && git pull && ./setup.sh
# then add firecrawl key to ~/.claude.json by hand (see SETUP.md)
```

### Why
The agent was scattering across 100+ skills (gstack's 48 + SuperClaude's 31 + 20 agents + native + plugin servers), most of which the 9-step workflow never called. The mapping table + whitelist rule + cleanup collapse the available surface back down to what the workflow actually uses, while adopting two genuinely complementary skills from outside gstack (one for adversarial review, one for web research).

## [0.29.2] - 2026-05-08

Theme: **Renumber to 0.x.** No behavior change.

### Changed
- **`VERSION`** — `7.6.1` → `0.29.2` (this release).
- **All git tags** retagged from `vN.M.P` to `v0.X.Y` per the chronological mapping (44 tags rewritten on local + origin).
- **`CHANGELOG.md`** headers + body cross-references updated to match.
- **`CLAUDE.md`**, **`SETUP.md`** — incidental `v7.4.0` references swept to `v0.27.0`.

### Why
Project never had a stable-API contract; living in `7.x` was overstating maturity. `0.x` is the correct SemVer signal for "still iterating, breaking workflow changes are fair game". Backfilled history rather than just shifting forward, since this is a solo repo with no external consumers and the dual-tag option (44+44) would be more confusing than a clean rewrite.

### Mapping (key landmarks)
- `v1.0.0 → v0.0.0` (CHANGELOG-only, never tagged)
- `v2.0.0 → v0.1.0`, `v2.3.3 → v0.4.3`
- `v3.0.0 → v0.5.0`, `v3.3.0 → v0.8.0`
- `v4.0.0 → v0.9.0`, `v4.2.0 → v0.11.0`
- `v5.0.0 → v0.12.0`, `v5.9.0 → v0.21.0`
- `v6.0.0 → v0.22.0`
- `v7.0.0 → v0.23.0`, `v7.6.1 → v0.29.1`
- This release: `v0.29.2`

## [0.29.1] - 2026-05-08

Theme: **Auto Mode no longer overrides the 9-step workflow.**

### Fixed
- **`CLAUDE.md`** — added a third CRITICAL RULE: Claude Code's harness-injected "Auto Mode Active" system-reminder ("execute immediately" / "prefer action over planning" / "do not enter plan mode unless explicitly asked" / "minimize interruptions") is **subordinate to this file**. The 9-step workflow (and the per-step approval gates) runs in Auto Mode exactly as it runs in normal mode. Auto Mode applies *within* a step (skip routine confirmations on sub-decisions), not *across* steps.

### Why
The harness's Auto Mode preamble started materially shaping behavior — agents were jumping straight from a user request to implementation, skipping /office-hours, /slow-down, /research, and /autoplan. The two CRITICAL RULES already in CLAUDE.md ("zero discretion to skip", "never proceed without approval") didn't explicitly name Auto Mode, so the more-recent system-reminder won by recency. This patch names it explicitly so the precedence is unambiguous.

### Scope
Single-file edit: `CLAUDE.md`. No skills changed, no settings.json change, no behavior change for non-auto sessions.

## [0.29.0] - 2026-05-01

Theme: **Project knowledge convention** — adopt mattpocock's CONTEXT.md / ADR pattern as global templates + CLAUDE.md guidance. No per-project files created; nothing imposed on existing projects.

### Added
- **`templates/CONTEXT.md.template`** — domain-agnostic seed for a per-project living glossary. Sections: Terms (with `_Avoid_` aliases), Relationships, Flagged ambiguities, Example dialogue, Maintenance rules. Adapted from `mattpocock/skills` (CONTEXT-FORMAT.md) with vocabulary stripped down for general use.
- **`templates/0000-adr-template.md`** — one-page ADR template. Status / Date / Author / Tags header, then Context / Decision / Alternatives / Consequences (✓✗?) / References / Maintenance. Numbering is monotonic per project.
- **`CLAUDE.md` § "Project knowledge: CONTEXT.md / ADR (optional)"** — when to add to a project, per-project structure, when to write ADRs, when to update CONTEXT.md, anti-patterns, and the managed-region fence convention. ~36 lines.
- **`.gitignore`** whitelist for `templates/` and `templates/**`.
- **Managed-region fence convention** in both templates: `<!-- mysystem:managed-start -->` … `<!-- mysystem:managed-end -->`. No tooling consumes these yet — convention reserved for future automation (e.g., a `/context-write` skill that updates terms without trampling hand-written sections). Cost is two HTML-comment lines per template; benefit is future-proofing alignment with emerging norms (claude-evolve, oop-architect both ship the same shape).

### Rationale
The 9-step workflow, gstack skills, and `.claude/memory/` already cover process and team-shared decisions. What was missing: a per-project source of truth for *language* (terminology that gets aliased) and *deliberate decisions with rationale* (separate from PR descriptions, which are commit-shaped not decision-shaped). mattpocock's pattern (48k stars) is the validated answer; this release imports it as templates only — no scaffolding skill, no auto-load hook, nothing forced on existing projects.

### Scope discipline
Explicitly NOT in v0.29.0:
- New skills (`/setup-context`, `/context-write` were considered, deferred — ship templates first, see if anyone copies them)
- Session-start auto-loading of `CONTEXT.md`
- Any change in vProp, cc-guard, or other project repos
- Modification of gstack skills

If no project copies the templates within ~2 weeks, mark the convention `Deprecated` in v0.29.x and remove. If templates get used, consider scaffolding skill in a future release.

### 15-day ecosystem scan (ref only)
Surveyed Claude Code skill / agent harness repos created or updated 2026-04-15 to 2026-05-01. Findings:
- **claude-evolve** (jack60810) — Self-evolving CLAUDE.md with managed-region fences. Inspired this release's fence convention.
- **unclog** (thomaschill) + **claude-atlas** (grippado) — `~/.claude/` audit tooling. Bookmarked for v0.30.x; revisit when 50-skill count grows or duplicates surface.
- **skill-audit** (okjpg) + **skill-doctor** (xigua-wang) — SKILL.md linters with `evals/evals.json`. Bookmarked for v0.30.x to validate the 5 user-owned skills.
- **cavemem** (JuliusBrussee) — Memory-layer compression. Orthogonal to RTK (Bash-tool layer); not adopted, noted.
- **Modular CLAUDE.md router** pattern (wenjygal, jimhy, ZhongliangGuo) — validates the v0.29.0 split (process in CLAUDE.md, project knowledge in CONTEXT.md/ADR).
- **Skipped**: design-system skills (wrong domain), harness alternatives (we're firmly on Claude Code), multi-LLM consensus voting (gstack `/codex` already covers this), token-dashboard (RTK's `rtk gain` already covers this).

## [0.28.0] - 2026-05-01

Theme: **Housekeeping pass.** "Remove what isn't used; document what is."

### Removed
- **`agents/ralph-planner.md`** and the entire `agents/` whitelist concept. Zero non-ralph agents had been added in 6+ weeks. `setup.sh` agent → skill validation block (~17 lines) deleted; `.gitignore` `!agents/` whitelist removed; `setup.sh` summary no longer reports an `Agents:` count.
- **`~/.claude/ralph/`** (untracked, 88K) — `claude-auto-resume.sh`, `ralph-smart.sh`, `vprop/` ralph-autonomous wrapper. Ralph Loop usage stopped (see prior memory entry on idle-`.` waste). `~/.claude/plugins/data/ralph-loop-claude-plugins-official/` empty stub directory also removed.
- **`mempalace/` tracked residue** — `wings/vprop/entities.json`, `wings/vprop/mempalace.yaml`, `wings`. v0.26.0 declared mempalace removed but left these in the working tree; this release actually `git rm`'s them. Same lineage as v0.27.0's "actually-applies-the-removal" entry.
- **cc-guard hooks** in `settings.json`: PreToolUse Bash matcher, PreToolUse `mcp__.*` matcher, SessionEnd `cc-guard learn --auto`. User moved to Claude Code's built-in auto permission mode and prefers no extra prompt layer.

### Added
- **RTK verification step** in `setup.sh` (`command -v rtk` with version echo on hit, warn-without-fail on miss). Catches the silent no-op case where `rtk hook claude` fires but the binary is gone.
- **Expanded `RTK.md`**: install path (`~/.local/bin/rtk`), current build (`v6x.260421.1`), reference to voyagerx Slack history thread, post-install verify checklist, sanity-check guidance (`rtk gain` should show climbing totals if the hook is firing). Replaces the prior 30-line stub.

### Captured
- **`settings.json` accumulated drift**: WebFetch domain allow-list expansions (developers.openai.com), MCP `query_dataset`/`search`/`get_properties`/`get_charts`/`query_chart`/`get_chart_definition_params` (claude_ai Amplitude), `slack_search_channels`/`slack_search_users` (claude_ai Slack), and `verify-test-vp553` `additionalDirectories`. Permissions accumulated through normal use; v0.28.0 commits the current state so future drift is diffable.
- **`autoCompactEnabled: false`** committed. Model is Opus 4.7 (1M context); the previous `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=25` (v0.24.0) was firing too aggressively against the 1M window — repeatedly invalidating the 5-min Anthropic prompt cache and burning generation tokens on summaries for sessions that would never have hit the hard wall anyway. Disabling auto-compact preserves the cache prefix, lets `/clear` handle task boundaries, and trusts the 1M ceiling. The v0.24.0 env override remains in `env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` but is now superseded by `autoCompactEnabled: false`.

### Safety implications (cc-guard removal)
- `rm -rf`, `git push --force`, `DROP TABLE`, etc. no longer hit a regex-based PreToolUse block before execution. Auto permission mode does not replace that safety net — it auto-approves rather than gates. User accepts the trade-off; treat destructive commands with extra care from this version forward. To restore protection: re-add the cc-guard hook entries (binary still installed at `~/Documents/cc-guard/dist/cc-guard`).

### Rationale
Two conflicting forces were resolved this release:
1. **"Used or remove"** — ralph hadn't been run in weeks, mempalace was already deprecated, cc-guard was about to become noise after enabling auto permission mode. Three concrete dead-or-redundant subsystems.
2. **"Used and managed"** — RTK demonstrably saves ~35M tokens (94.6% efficiency, 4,623 commands lifetime per `rtk gain`). It is the most-used tool with the worst documentation in the repo. Promoted from "ghost dependency" to documented dependency.

### Deferred (not in v0.28.0)
- CONTEXT.md / ADR convention from `mattpocock/skills` — explored in /office-hours, deferred to v0.29.0 to keep this release focused on cleanup.
- The `feedback_ralph_loop_usage_waste.md` auto-memory entry is now stale (ralph removed) but lives at `~/.claude/projects/.../memory/` which is symlinked into the vProp repo's tracked memory. Cleanup requires a vProp commit; out of scope this session.

## [0.27.1] - 2026-04-27

### Fixed
- **`hooks/update-skills.sh` no longer relies on `flock`.** macOS does not ship `flock`, so v0.27.0's hook silently exited (`flock: command not found` → `|| exit 0`) without ever calling `setup.sh` — same silent-no-op failure mode as the v0.27.0 bug it was meant to fix. Replaced with an atomic `mkdir`-based lock (`.skill-update.lock.d`) cleaned up via `trap EXIT`. Tested end-to-end: hook now actually invokes `setup.sh` and pulls gstack.

## [0.27.0] - 2026-04-27

### Changed
- **External skills are no longer git submodules.** `skills/gstack` is now an independent clone managed by `setup.sh`, always pulled at latest `main` instead of pinned to a fixed commit. SessionStart hook no longer errors out trying to roll back to stale SHAs.
- **`.gitignore` restructured to explicit allow-list.** User-owned skills whitelisted by name; external skills (gstack + anything it installs) stay ignored by default. No maintenance when gstack adds/removes skills.
- **`setup.sh` rewritten.** Now clones/pulls external repos (declared in `EXTERNAL_REPOS`), runs each external repo's own `./setup`, then validates symlinks and agent → skill mappings. Idempotent.
- **SessionStart hook rewritten to match the post-submodule world.** Old `hooks/submodule-auto-update.sh` iterated `git submodule status` (empty after the migration) and so silently stopped updating gstack — local stayed pinned at v1.4.1.0 while upstream moved to v1.15.0.0. New `hooks/update-skills.sh` delegates to `setup.sh` (the SSOT), uses `flock` for single-flight against concurrent sessions, and truncates its log every run so stale errors don't get re-reported every session start.

### Added
- `install.sh` — one-shot installer for new machines. `bash <(curl -fsSL .../install.sh)` backs up any existing `~/.claude`, clones MySystem, and runs `setup.sh`.
- `README.md` — repo landing page with two entry points (ask Claude, or curl one-liner).
- `SETUP.md` — single source of truth for install/update/troubleshoot. Shareable URL you can hand to Claude: "read SETUP.md and execute it."
- CLAUDE.md rule 6: adding an external skill repo → edit `EXTERNAL_REPOS` in `setup.sh` and update the README/SETUP tables; never submodule.

### Removed
- **Submodules deleted (4):** `gstack`, `superpowers`, `playwright-skill`, `code-review-skill`. `.gitmodules` file removed. `.git/modules/skills/*` refs cleaned.
- **Unused skill dirs deleted:** `skills/superpowers/`, `skills/playwright-skill/`, `skills/code-review-skill/`, `skills/systematic-debugging/`, `skills/.gstack-backup-0.11.19.0/`. CHANGELOG 7.3.0 claimed playwright/code-review were removed but the working tree still had them — this release actually applies that removal.

### Rationale
Submodules pin a specific commit, which directly contradicts the "always latest" requirement for gstack (active development, frequent releases). Every SessionStart hook was failing to `git submodule update` because the pinned SHA kept rolling back manual gstack upgrades. The new model: declare the dependency (in `setup.sh`), let git clone freely, never pin.

Trade-off: MySystem no longer snapshots exact versions of external skills at release time. Acceptable because (a) gstack releases its own semver; (b) reproducibility for a personal config repo matters less than staying current; (c) the declaration in `setup.sh` is readable and diff-friendly.

## [0.26.0] - 2026-04-21

### Removed
- **mempalace system fully removed.** 30-day usage analysis showed ~5 queries/day average and zero writes in the last 5 days; ROI did not justify the ~3,000 tokens injected per session. gstack's local storage (`~/.gstack/projects/`) plus per-project `.claude/memory/` cover the same needs with less overhead.
  - `~/.claude.json`: removed `mempalace` MCP server
  - `settings.json`: removed SessionStart wake-up hook, Stop auto-mine hook, and mempalace-related permissions/directories
  - `hooks/mempalace-wake-up.sh`, `hooks/mempalace-auto-mine.sh`: deleted
  - `~/.mempalace/palace/` data preserved (recoverable if needed)
- **Unused plugins removed**: `context7`, `playwright`, `figma`, `frontend-design` (all `claude-plugins-official`). Duplicates of global MCPs or unused.
- **Unused MCP servers removed** (`~/.claude.json`): `pencil`, `Framelink Figma MCP`, `chrome_devtools` (overlaps with Playwright).
- **Unused skills removed (20)**: benchmark, benchmark-models, canary, cso, design-consultation, design-html, design-shotgun, devex-review, plan-devex-review, plan-tune, make-pdf, pair-agent, connect-chrome, context-restore, context-save, health, learn, open-gstack-browser, playwright-skill, code-review-skill.

### Rationale
- Token savings: roughly 6,000–7,000 tokens per session start.
- gstack local storage already integrates with the team-shared `.claude/memory/` + `MEMORY.md` auto-load flow. The mempalace KG/drawer/tunnel abstractions were over-engineered for the actual usage pattern.

## [0.25.0] - 2026-04-21

### Added
- **Boil the Lake (Completeness Principle)** section in CLAUDE.md — recommend the complete implementation over shortcuts; AI makes the last 10% cost near-zero. Flag "oceans" (rewrites of systems you don't control) as out of scope.
- **Repo Mode (Solo vs Collaborative)** in CLAUDE.md — agent behavior adapts to who owns issues. Solo repos (cc-guard, MySystem): proactive fixes for noticed issues. Collaborative repos (vProp): flag-only, default to asking. "See Something, Say Something" rule — never let a noticed issue silently pass.
- **Step 6 Verification** — added `/design-review` option. Options expanded to A (all) / B (verify-test only) / C (qa-only only) / D (design-review only) / E (both functional) / F (skip). For non-UI work, the design-review entries are dropped automatically.

### Rationale
- gstack's `/review` already runs Codex adversarial automatically (above the ~50-line threshold), so adding a separate `/codex` step would be redundant. Skipped.
- `/land-and-deploy` and `/canary` overshoot for repos like vProp that already have team review + merge flow plus Vercel + Sentry observability. Left out of the default flow.
- The two new principles (Boil the Lake, Repo Mode) are the highest-leverage parts of gstack's philosophy to absorb as judgment criteria — they shape decisions without requiring workflow changes.

## [0.24.0] - 2026-04-20

### Changed
- Context Management: replaced "Compact at 50%" manual rule with auto-compaction via `CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=25`. Opus 4.7 (1M context) triggers auto-compaction at ~250K tokens, much earlier than the 83% default — Opus 4.7 burns tokens too fast for the default threshold.
- settings.json: added `env.CLAUDE_AUTOCOMPACT_PCT_OVERRIDE=25`, `effortLevel: xhigh` (Opus 4.7 default), permissions (Skills for office-hours/autoplan/review/ship, editJiraIssue, vprop libs/src/image, stripe list_subscriptions), additionalDirectories (cc-guard subdirs, verify-test tmp dirs).
- hooks: added `SessionEnd` cc-guard learn; `PreToolUse` Bash uses absolute path to `cc-guard check`.

## [0.23.1] - 2026-04-15

### Changed
- mempalace-auto-mine.sh: `--extract general` for structured memory extraction (decision/problem/milestone instead of raw exchange snippets).
- settings.json: added permissions (Slack search, Notion search, Playwright, cc-guard hook, mempalace), additional directories, PreToolUse cc-guard hook.

## [0.23.0] - 2026-04-15

### Changed
- **Breaking**: Removed custom ensemble system entirely. Coordinator now invokes gstack skills directly.
- **Breaking**: CLAUDE.md rewritten (213→113 lines). Gstack-native execution model.
- Workflow step 6 (Verification) now presents 4 options: both, verify-test only, qa-only only, or skip.
- settings.json: removed PreToolUse Agent hook, removed disabled plugins, cleaned permissions.
- settings.local.json: wildcard permission consolidation (96→41 entries).

### Added
- Context Management section in CLAUDE.md (/compact at 50%, /rewind, /clear).
- `<important if>` conditional tag for Repo Self-Management.
- submodule-auto-update.sh: error reporting via additionalContext on SessionStart.
- `cc-update` alias in ~/.zshrc for daily Claude Code updates.

### Removed
- 10 custom agent definitions (kept only ralph-planner.md).
- `require-subagent-type.sh` hook (ensemble enforcement no longer needed).
- Ensemble Execution Rule, Subagent Permission Rules sections from CLAUDE.md.
- `superpowers` and `feature-dev` disabled plugin entries from settings.json.

## [0.20.1-rollback] - 2026-04-15

### Reverted
- Rolled back from v0.22.0 to v0.20.1. Reverted CLAUDE.md and VERSION.
- v0.21.0 (Ralph Autonomous Mode) and v0.22.0 (ensemble removal, workflow unification) changes undone.
- `agents/ralph-planner.md` retained as it's a standalone addition.

## [0.22.0] - 2026-04-14

### Changed
- **Breaking**: Removed ensemble (3x subagent per step). Each step now calls 1x subagent directly.
- **Breaking**: Interactive vs Ralph difference reduced to approval only. Same workflow, same agents.
- **Breaking**: Ralph switched from screen + `claude -p` to Ralph Loop plugin (Stop Hook based).
- Simplified subagent invocation: call via `subagent_type` directly, coordinator must not re-interpret or re-inject skill content.
- Only /autoplan retains 3 subagents (role division: CEO + Design + Eng).
- Updated ralph-start and ralph-report skills to Ralph Loop plugin based.

### Removed
- Ensemble Execution Rule section entirely
- 3x parallel subagent execution pattern
- screen + ralph-autonomous.sh based autonomous execution

## [0.21.0] - 2026-04-14

### Added
- **Ralph Autonomous Mode**: Autonomous execution of MySystem workflow while user is away. Each iteration = 1 task x 1 workflow step. Steps 1~8 auto-execute, /ship always requires human.
- **`ralph-planner` agent** (`agents/ralph-planner.md`): Detailed implementation plan writer for autonomous execution
- **Ralph runtime** (`~/.claude/ralph/{project}/`): ralph-autonomous.sh (main loop), next-step.py (task/step selection), advance-step.py (step advancement, atomic write), safety-autonomous.md (safety rules)
- **CLAUDE.md**: Added Ralph Autonomous Mode section (Interactive vs Autonomous comparison, safety measures, file locations)
- **Available Custom Subagents table**: Added `ralph-planner`

### Design Decisions
- Runtime files stored outside repo (`~/.claude/ralph/`) to avoid git status pollution
- Reuses existing agents (`--agent` flag) — no separate methodology prompts needed
- Single agent per step (not ensemble) — 1/3 token cost, suitable for autonomous execution
- `--disallowed-tools` CLI hard block + `safety-autonomous.md` soft block dual safety

## [0.20.1] - 2026-04-10

### Added
- **Central mempalace wing configs** (`mempalace/wings/vprop/`): moved `mempalace.yaml` and `entities.json` out of project directories into MySystem so they don't pollute project git status/diff

## [0.20.0] - 2026-04-10

### Added
- **3 external skill submodules**: `code-review-skill` (React/TS/Vue review), `playwright-skill` (E2E tests), `superpowers` (systematic-debugging)
- **Submodule auto-update hook** (`submodule-auto-update.sh`): SessionStart fetches latest for all submodules in background, restores broken symlinks if updated
- **systematic-debugging** skill symlink from superpowers

### Changed
- `investigator` agent: added `systematic-debugging` skill (4-phase execution guardrails)
- `code-reviewer` agent: added `cso` (OWASP/STRIDE) + `code-review-skill` (React 19/TS review)
- `eng-reviewer` agent: added `health` (code quality dashboard)
- `test-verifier` agent: added `playwright-skill` (E2E test generation)

## [0.19.0] - 2026-04-10

### Added
- **setup.sh**: Clone-and-run bootstrap script — inits gstack submodule, restores broken skill symlinks, verifies all agent → skill mappings. Run `cd ~/.claude && ./setup.sh` on any new machine.

## [0.18.0] - 2026-04-10

### Added
- **MemPalace integration**: Replaced claude-mem with MemPalace for persistent memory (raw verbatim storage, 96.6% R@5 retrieval)
- **SessionStart hook** (`mempalace-wake-up.sh`): Injects MemPalace L0+L1 wake-up context (~170 tokens) at every session start
- **Stop hook** (`mempalace-auto-mine.sh`): Auto-mines session transcript into MemPalace on session end
- **MCP server** (`mempalace`): Registered as user-scope MCP for semantic search across all sessions

### Removed
- **claude-mem**: Plugin uninstalled, launchd workers/updater removed

### Changed
- Subagent models switched from opus to sonnet (cost reduction)

## [0.17.0] - 2026-04-09

### Added
- **3 new custom subagents**: `office-hours`, `slow-downer`, `test-verifier` — every ensemble step now has a dedicated subagent with preloaded skills
- **PreToolUse hook** (`require-subagent-type.sh`): Blocks Agent calls without `subagent_type`. Hard enforcement — coordinator cannot bypass by using generic Agent(model: "opus")

### Changed
- Step Details table: all steps now reference named subagents, no more "generic" entries
- All 10 subagents have `skills:` frontmatter for automatic SKILL.md preloading

## [0.16.2] - 2026-04-09

### Fixed
- **Enforce subagent_type usage**: Added CRITICAL rule + correct/wrong examples to prevent coordinator from ignoring custom subagents and spawning generic `Agent(model: "opus")` with inline prompts instead

## [0.16.1] - 2026-04-09

### Fixed
- **/autoplan two-phase flow**: Coordinator must write a plan via EnterPlanMode, get user approval via ExitPlanMode, THEN pass the full approved plan to CEO/Design/Eng reviewers. Previously coordinator was skipping the plan phase and writing its own inline summary directly into subagent prompts.

## [0.16.0] - 2026-04-09

### Changed
- **Correct subagent invocation**: Rewrite CLAUDE.md to use `Agent(subagent_type: "name")` pattern
- **Skills preloading**: Add `skills:` frontmatter to agent files — SKILL.md content is preloaded at session start, no runtime file reads needed
- **Agent frontmatter hardened**: Add `permissionMode: dontAsk`, `effort: high` to all agent definitions
- **Execution Steps / Step Details consistency**: Both now unified around `subagent_type` invocation

### Fixed
- Disconnect between Execution Steps (inline prompts) and Step Details (custom agent names) resolved
- Subagents no longer need to read SKILL.md at runtime — replaced with skills preloading

## [0.15.0] - 2026-04-09

### Added
- **Custom Subagents** (`~/.claude/agents/`): 7 dedicated subagent definitions created
  - `ceo-reviewer.md`, `design-reviewer.md`, `eng-reviewer.md` (role-based for /autoplan)
  - `code-reviewer.md`, `bug-hunter.md` (dedicated for /review and /bugbot)
  - `investigator.md`, `researcher.md` (dedicated for /investigate and /research)
- Each agent embeds its own model, tools, and instructions — no more passing long prompts at runtime

### Changed
- Step Details table: skill file references replaced with custom subagent references
- Subagent invocation: Agent tool + inline prompts replaced with pre-defined `.claude/agents/` files

## [0.14.0] - 2026-04-09

### Changed
- **/autoplan**: Same skill x3 replaced with role-based subagents (Agent 1=CEO, Agent 2=Design, Agent 3=Eng). Each subagent reads and executes its own role's SKILL.md.
- **Implementation**: Excluded from ensemble, coordinator runs directly (needs file write permissions)

## [0.13.0] - 2026-04-09

### Changed
- **Opus-only ensemble**: Subagent model changed from sonnet to opus. Codex CLI and Gemini CLI removed (unstable).
- **Subagents run skills internally**: Coordinator no longer extracts/summarizes methodology. Each subagent reads SKILL.md and runs the full methodology itself.
- **Fixed at 3 perspectives**: 3 opus subagents. Coordinator only synthesizes.

### Fixed
- Coordinator was proceeding after only 1 subagent returned — now waits for ALL 3
- Coordinator was advancing to next workflow step without user approval — now requires explicit approval after every step
- Subagent prompts were truncated to ~300 chars — now require full context + "read SKILL.md yourself" instruction

### Removed
- Codex CLI integration (unstable invocation)
- Gemini CLI integration (unstable invocation)

## [0.12.0] - 2026-04-09

### Changed
- **Base reverted to v0.8.0**: Rolled back Scion-based v4.x architecture. Step-detail table (v0.11.0) retained.
- **Ensemble fixed at 5 perspectives**: 3 Claude sonnet subagents + Codex CLI + Gemini CLI. Removed "3-5" variable range.
- **Codex CLI flags updated**: `--read-only` to `-s read-only`, `--write` to `-s workspace-write` (Codex v0.118.0)
- **Repo Self-Management**: Skill sync changed from copy to symlink

### Added
- **Gemini CLI v0.36.0**: Added as cross-model voice alongside Codex (`gemini -p "<prompt>" --approval-mode plan -o text`)
- **Graceful degradation**: Continue with Claude ensemble alone if Codex/Gemini CLI fails
- **Long diff handling**: tmp file + stdin pipe pattern documented

### Removed
- **Scion CLI dependency**: "THE ONE RULE" (mandatory scion-ensemble first call) removed
- **Docker/Scion container ensemble**: 4-agent Scion architecture fully removed
- **Per-step prose descriptions**: Replaced with step-detail table

### Fixed
- v4.x workflow failing every session due to Scion CLI not being installed
- Codex CLI v0.118.0 flag compatibility

## [0.11.0] - 2026-04-08

### Changed
- **Complete CLAUDE.md rewrite**: reduced from 190 lines to 70 lines. One rule at the top: "your first tool call is /scion-ensemble". Everything else supports that one rule.
- **"THE ONE RULE" pattern**: instead of 10+ CRITICAL/NEVER/MANDATORY directives that agents ignore, one clear behavioral instruction that's impossible to misinterpret.
- **Table-based step details**: replaced verbose per-step prose with a compact table mapping step → skill file → what to extract.
- **Removed redundant rules**: "ZERO discretion", "NEVER skip", "NEVER reorder" etc. all consolidated into workflow ordering + "user interrupts if they want to skip".

### Fixed
- Agent was reasoning "this is overkill" and skipping ensemble because the old CLAUDE.md had too many rules competing for attention. New version has one rule.

## [0.10.0] - 2026-04-08

### Changed
- **Step Details rewritten**: every step now explicitly reads the relevant skill's SKILL.md, extracts the methodology, and inlines it into the /scion-ensemble task prompt. Prevents agents from ignoring ensemble and running solo.
- **Methodology extraction pattern**: Gemini/Codex can now follow gstack skill methodologies (investigate 4-phase, review criteria, etc.) even though they can't read SKILL.md files directly — the methodology is embedded in the task prompt.
- **No diff/non-diff distinction**: all steps use /scion-ensemble uniformly. Same prompt for all 4 agents.

### Fixed
- Agent was ignoring Ensemble Execution Rule and running skills directly (solo) because Step Details said "Run /investigate" without mentioning /scion-ensemble.

## [0.9.0] - 2026-04-08

### Added
- **scion-ensemble skill**: New `/scion-ensemble` custom skill that spawns a 4-agent multi-model ensemble: 1 local Claude (Agent tool) + 3 Scion containers (Claude Opus, Gemini 2.5 Pro, Codex). Collects results and synthesizes into Consensus / Unique catches / Disagreements.
- **poll-agents.sh**: Standalone polling script for Scion agent completion. Supports per-model timeouts, quorum checking, and timestamped agent names.
- **Scion integration**: Diff-based workflow steps (review, bugbot) now use Google Scion for container-isolated multi-vendor AI review.

### Changed
- **Breaking**: Ensemble Execution Rule rewritten. Diff-based steps (review, bugbot) use `/scion-ensemble` (4 agents, 3 vendors). Non-diff steps retain the old Agent tool + Codex pattern until Phase 2.
- **Breaking**: Requires Scion CLI + Docker for full ensemble. Falls back to local-only Agent tool ensemble if unavailable.
- Step 7 (/review) and Step 8 (/bugbot) now reference `/scion-ensemble` instead of "Codex runs in parallel"

## [0.8.0] - 2026-04-08

### Changed
- Research-backed ensemble: structured perspectives, not just paraphrasing

## [0.5.0] - 2026-04-05

### Added
- **Ensemble Execution Rule**: Every workflow step spawns 3-10 identical subagents in parallel, synthesizes results into one report. Core leverage of the system.
- **Step 3: /research**: New mandatory step — search docs, codebase, existing solutions before planning. Uses search-first + documentation-lookup skills.
- **Step 6: /verify-test**: New mandatory step — generate throwaway code-based tests, run them, delete after. Tests never committed.
- **search-first skill**: Copied from affaan-m/everything-claude-code. Research existing tools/libraries before writing code.
- **documentation-lookup skill**: Copied from affaan-m/everything-claude-code. Fetch live docs via Context7 MCP.
- **verify-test skill**: Custom. Generate, run, and discard code-based verification tests.
- **Subagent Permission Rules**: Read-only by default (Read, Grep, Glob, Bash). Only coordinator can write files or use git.

### Changed
- **Breaking**: Workflow expanded from 7 steps to 9 steps (added /research and /verify-test)
- **Breaking**: Debugging flow expanded (added /research step)
- Ensemble rule applies to ALL steps (not just review/bugbot)

## [0.4.3] - 2026-03-27

### Fixed
- Clarified that /autoplan runs IMMEDIATELY after /slow-down approval, no asking
- "Plan acceptance ≠ plan review" — ExitPlanMode does not replace /autoplan
- Agent was skipping /autoplan entirely after user accepted a plan

## [0.4.2] - 2026-03-27

### Fixed
- Added "NEVER reorder steps" and "NEVER write code before /slow-down and /autoplan are done"
- Agent was running /investigate then jumping straight to implementation, skipping /slow-down and /autoplan entirely

## [0.4.1] - 2026-03-27

### Fixed
- Clarified that agent must NEVER ask "should we skip?" or suggest skipping
- User interrupts if they want to skip — agent just runs the next step

## [0.4.0] - 2026-03-27

### Changed
- **Breaking**: ALL workflow steps are now MANDATORY — agent has ZERO discretion to skip
- Removed all IF/THEN conditional logic that allowed agent to judge whether a step applies
- Only the user can skip a step by explicitly saying "skip [step]"
- Debugging flow also requires /slow-down and /autoplan (no shortcuts)

## [0.3.0] - 2026-03-27

### Added
- CHANGELOG.md for version history tracking
- Repo self-management rules in CLAUDE.md: agents must bump VERSION, update CHANGELOG, create git tag, and sync global files on every change

## [0.2.0] - 2026-03-26

### Changed
- Workflow now has 7 explicit numbered steps, not just 3 gates
- Every skill (office-hours, autoplan, plan-*, review, bugbot, ship) has a designated position with IF/THEN trigger rules
- Added debugging flow: /investigate → /slow-down → implementation → /review → /bugbot → /ship
- Added weekly retrospective: /retro with explicit trigger condition
- Removed separate "Skill Inventory" table — skills are defined by their workflow position

## [0.1.0] - 2026-03-26

### Changed
- **Breaking**: All content rewritten in English (was Korean)
- **Breaking**: CLAUDE.md restructured as enforceable IF/THEN gates (was advisory workflow)
- slow-down SKILL.md rewritten in English with original article quotes

### Added
- gstack added as git submodule at skills/gstack/
- VERSION file for version tracking

## [0.0.0] - 2026-03-26

### Added
- Initial setup: CLAUDE.md, settings.json, bugbot skill
- slow-down skill: 5-step pre-coding concretization process
- Global workflow rules: slow-down (mandatory) + bugbot (mandatory)
