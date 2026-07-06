# ADR-0006: Defense-in-depth via hand-vendored PreToolUse harness hooks (dry-run first)

**Status:** Accepted (2026-05-18)
**Amendment (2026-07-07):** the `rtk hook claude` PreToolUse hook and `RTK.md`
were removed from MySystem (see CHANGELOG). References to rtk hook ordering
and RTK.md below are historical; the four defense-in-depth hooks are now the
only PreToolUse hooks.
**Context window:** v0.35.0 release
**Supersedes:** none
**Superseded by:** none

## Context

Until v0.34.0, MySystem's destructive-command protection lived only in opt-in
skills (`/careful`, `/guard`). The user had to remember to invoke them. The
best-practices research sweep
(`~/.gstack/projects/seungwonkim-v6x-MySystem/best-practices-research-20260518.md`,
44 patterns across 10 repos) found 3 different repos (davila7, mattpocock,
shanraisshan) converged on PreToolUse Bash hooks as the canonical
defense-in-depth layer. This ADR captures the v0.35.0 adoption decision.

The work was planned through `/autoplan` and reviewed by Claude subagent
CEO + Eng. Single-voice review (Codex CLI binary ENOENT on this machine);
acceptable for repo-self-management changes per the autoplan degradation
matrix. Reviewer findings prompted 7 plan revisions before approval.

## Decision

### 1. Adopt 4 PreToolUse hooks (hand-vendored, fail-open)

- `secret-scanner.py` — intercept `git commit`, scan staged diff
- `dangerous-command-blocker.py` — block `rm -rf /`, `dd`, `mkfs`, etc.
- `env-file-protection.py` — block Write/Edit/MultiEdit on `.env*` paths
- `block-dangerous-git.sh` — block dangerous git verbs

Plus `permissions.ask` list for 10 destructive Bash patterns
(rm/dd/mkfs/chmod/chown/kill/etc).

### 2. Hand-vendor, do not SPARSE_SKILLS-clone

Hook scripts live in MySystem's tracked git tree at `~/.claude/hooks/`,
NOT as SPARSE_SKILLS picks. Each script's header includes
`# Adapted from <repo-url>@<commit-SHA>` attribution. Treat as
MySystem-owned code, refresh manually when upstream improves. Mitigates
supply-chain risk (Eng F6.1): a malicious upstream commit can't auto-pull.

### 3. Ship in dry-run mode (calibrate before enforce)

v0.35.0 ships with `MYSYSTEM_HOOKS_ENFORCE` unset. Hooks detect matches
but exit 0 + write to `~/.claude/logs/hook-dry-run.log`. After 48 hours
of normal-workflow observation with zero false positives, v0.35.1 patch
release adds `"MYSYSTEM_HOOKS_ENFORCE": "1"` to settings.json `env` block.

This is the "calibrate before enforce" pattern CEO review (#2) requested.

### 4. Fail-open on internal error

Every script wraps its logic in try/except (Python) or `set +e` + explicit
error log (bash). Internal errors → log to `~/.claude/logs/hook-errors.log`
→ exit 0 (allow). A buggy hook never bricks the workflow. Addresses Eng F5.1.

### 5. Hard-refuse for prompt-injection-resistant patterns

Two pattern classes block even with bypass env vars set:
- **Private-key headers** in secret-scanner — `BEGIN RSA/EC/DSA/OPENSSH PRIVATE KEY`
- **Force-push to origin main/master** in block-dangerous-git

Rationale: bypass env vars (`MYSYSTEM_ALLOW_SECRET_COMMIT=1`,
`MYSYSTEM_ALLOW_FORCE_PUSH=1`) could be set by tool output containing
prompt-injected shell snippets. Hard-refuse classes have no env-var
override. Addresses Eng F4.2.

### 6. Benchmark before flip

v0.35.0 acceptance criterion: per-Bash overhead < 200ms (Python cold-start
× 2 + bash × 1). Record to
`~/.gstack/projects/seungwonkim-v6x-MySystem/v0.35.0-hook-benchmark.md`.
If above 200ms: collapse Python hooks into single dispatcher (one
Python startup) OR rewrite in bash. Addresses Eng F3.1.

### 7. Hook ordering by clean-message preference (not pipeline necessity)

Original v1 draft claimed "blockers must run before rtk so they see literal
text before rtk rewrites." This was wrong. Each PreToolUse hook receives
the original `tool_input` independently; rtk does not pipeline-mutate
downstream hooks (it's a tool-result token rewriter, not an input
transformer). Corrected rationale: blockers prepend rtk so their BLOCKED
stderr messages surface uncompressed. Ordering is by message clarity, not
pipeline correctness. Addresses Eng F1.1.

## Consequences

### Positive

- Catastrophic mistakes (secret commits, `rm -rf /`, force-push to main)
  blocked regardless of skill invocation or Auto Mode state.
- Fail-open + dry-run + hand-vendor combo: failure modes contained.
  - Hook bug → workflow unaffected, error logged
  - Bad upstream commit → no impact (vendored)
  - Overly aggressive regex → caught in 48h dry-run window before flip
- Encodes DenisSergeevitch's "harness, not model" principle: every
  prompt-only CRITICAL RULE should aspire to harness enforcement.
- Pairs with existing `/careful` and `/guard` skills — those are
  "verbal opt-in" surface; hooks are "always-on unconditional" surface.

### Negative

- Adds spawned processes per Bash call. Benchmark-gated (<200ms acceptance);
  if exceeded, fallback plan documented above.
- Hand-vendor means manual refresh when upstream improves. Acceptable for
  the 4 small hooks (under 200 lines each); not auto-update.
- New file surface (`~/.claude/logs/`) — first-write creates the dir.
  Gitignored implicitly (not added to repo).
- `permissions.ask` adds confirmation prompts on `rm`, `dd`, etc. Slightly
  more friction during destructive operations; mitigated by trimmed list
  (excludes package managers, where prompting would be intolerable).

## Decisions deferred

- **`CLAUDE_AUTOCOMPACT_PCT_OVERRIDE` stays at `25`** (not bumped to 80 as
  shanraisshan template suggests). v7.1.0 set it to 25 deliberately for
  Opus 4.7's 1M context; RTK.md documents the rationale. shanraisshan's
  general-context advice (compact at 80% utilization) doesn't apply when
  context is 4× larger and degradation begins around 300-400k tokens.
- **`enableAllProjectMcpServers: true`** (shanraisshan) — auto-trusts
  repo-checked-in `.mcp.json` configs. Deferred pending CSO threat-model
  review (would auto-connect to a hostile MCP if a repo ships one).
- **`ai-bash-guard`** (davila7) — Haiku judges every Bash. Latency + token
  cost not measured. Deferred until v0.37+; benchmark first.

## Alternatives considered

| Alternative | Reason rejected |
|---|---|
| `SPARSE_SKILLS` clone of hook scripts | Supply-chain risk; scripts small enough to vendor |
| Single mega-hook dispatcher script | Per-hook isolation makes failure containment easier; dispatcher is fallback if benchmark fails |
| Keep skill-only protection | Exactly the gap this closes is "forgot to invoke /careful" |
| Skip dry-run, flip enforce immediately | CEO review #2: calibrate before enforce; 48h log-only window required |
| Pipe-stdin to one hook that fans out | Claude Code hook protocol expects per-hook stdin; not pipelined |
| Native `Write(.env*)` conditional matcher | Matcher syntax for tool-input patterns not verified against Claude Code docs; switched to portable Python check on `file_path` |

## Reviewer findings addressed

(References to `~/.gstack/projects/seungwonkim-v6x-MySystem/eng-subagent-review-20260518.md` and `ceo-subagent-review-20260518.md`)

- Eng F1.1 (hook ordering): rationale rewritten — clean-message preference, not pipeline
- Eng F2.1 (no /ship e2e test): added as v0.35.0 acceptance criterion
- Eng F3.1 (Python perf unverified): benchmark step before enforce flip
- Eng F4.2 (prompt-injection on bypass): hard-refuse for main/master + private-key headers
- Eng F5.1 (no fail-open): every hook wraps try/except + exit 0 on error
- Eng F6.1 (supply chain unspecified): hand-vendor with attribution
- CEO #2 (no calibration): dry-run mode for 48h before enforce
- CEO #1 (skill supply chain): see future ADR-0007 (skill picks pinned to SHA)

## 2nd-pass adversarial review findings addressed (post-/requesting-code-review)

A 2nd-pass adversarial review surfaced 4 critical + 8 important + 7 minor findings.
Addressed inline before /ship:

- **C1** (release blocker): new files untracked → must explicitly `git add` in /ship
- **C2** (hard-refuse incomplete): hard-refuse now matches `HEAD:main`, `+main`,
  `refs/heads/main`, `+refs/heads/main` refspec variants. Verified with 3 tests.
- **C3** (rm regex brittle): broadened to catch `rm -fR`, `rm -Rf`, `rm -r -f`
  (separated flags), and `bash -c "rm -rf /etc"` (quoted inside shell wrapper).
- **C4** (OpenAI false positives): tightened from `sk-[A-Za-z0-9]{32,}` to require
  the `T3BlbkFJ` substring (base64 of "OpenAI") present in every real key.
  Eliminates `sk-EXAMPLE...` doc-placeholder false positives.
- **I1** (datetime deprecation): replaced `datetime.utcnow()` with
  `datetime.now(timezone.utc)` across all 3 Python hooks.
- **I2** (module-level errors bypass fail-open): partial — `env-file-protection.py`
  no longer pre-compiles its regex (deferred to `re.search` inside `main()` so a
  malformed pattern fails inside try/except). `dangerous-command-blocker.py`
  wraps `os.path.expanduser` in try/except. Python SYNTAX errors still bypass
  (cannot be caught at all); mitigated by /verify-test running on every change.
- **I5** (`.claude/` absolute-path redirect missed): added regex matching
  `/Users/<name>/.claude/` and `os.path.expanduser("~/.claude/")` literal paths.
- **I7** (`.env.production.local` multi-suffix missed): regex now matches
  zero-or-more dot-suffix groups (`\.env(\.<suffix>)*`).
- **I8** (`git -c key=val commit` bypass in secret-scanner): applied the same
  `GIT_VERB` pattern as block-dangerous-git.sh.

## Deferred (with documented rationale)

- **I3** (MYSYSTEM_HOOKS_ENFORCE env-injection path not verified end-to-end):
  blocking task for v0.35.1 flip. Write a one-shot test: edit `settings.json` env
  block, run an obviously-bad Bash via Claude Code, confirm block (not dry-run-log).
- **I4** (bypass env-var persistence across child processes): once exported,
  `MYSYSTEM_ALLOW_FORCE_PUSH=1` inherits to subsequent calls in the same shell.
  Mitigation: document "prefer per-command env (`VAR=1 git push ...`) over
  `export`". Future enhancement: hook could detect bypass + log "bypass consumed"
  + recommend single-use pattern. Acceptable risk because the hard-refuse for
  main/master is unconditional regardless of env state.
- **I6** (heredoc bypass): `bash <<EOF\nrm -rf /\nEOF` is not detected.
  Documented limitation; heredoc detection requires shell parsing which is out
  of scope for regex hooks. The `bash -c "..."` form IS now detected (C3).
- **I2 syntax-error case**: Python SYNTAX errors at parse time bypass
  try/except entirely (no Python is interpreted yet). Mitigation: every hook
  change goes through /verify-test before /ship; verify-test would catch a
  parse error immediately. True defense would require shell-wrapping the
  command in settings.json (`python3 ... || exit 0`), which adds complexity
  and obscures real exit codes. Deferred unless a syntax-error incident occurs.
- **M1-M7 (minor)**: deferred to TODOS or v0.36+. Notable:
  - **M5** (log rotation): hook-dry-run.log + hook-errors.log unbounded growth.
    Add date-based rotation in v0.35.x patch if files exceed 10MB.
  - **M6** (Python cold-start may exceed <200ms target): pre-bake the
    dispatcher fallback (one Python startup × 3 hooks) before v0.35.1 flip in
    case benchmark fails.
  - **M7** (settings.json attribution): `respectGitignore` and `permissions.ask`
    not attributed in-line. Attribution lives in CHANGELOG; acceptable
    inconsistency since these are 1-line config values, not script code.

## Related ADRs

- ADR-0004 — kami preview hook (the existing Stop hook this release extends)
- ADR-0005 — plugin marketplace mechanism (unrelated; trust model for plugins, not hooks)
- ADR-0007 (forthcoming with v0.37.0) — skill cherry-pick batch + SHA pinning amendment to ADR-0005

## Refresh process (future)

When davila7 or mattpocock improves an upstream hook:

1. `gh repo view <upstream>/CHANGELOG.md` or read upstream commits since
   our vendored SHA.
2. Read the upstream diff.
3. If worth porting: rewrite the local hook keeping fail-open wrapper +
   bypass/enforce semantics intact; update attribution header SHA.
4. Re-run benchmark; re-enter 48h dry-run; flip enforce in patch release.
5. Note refresh in CHANGELOG.

No automatic upstream sync. Each refresh is a deliberate decision.
