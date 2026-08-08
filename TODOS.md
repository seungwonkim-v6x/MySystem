# TODOS

Deferred work items. Format: what / why / effort (human → CC) / priority.

## From /ai-review-loop plan review (2026-07-03, /autoplan)

- [x] **All four Step-9 items obsolete** — gemini tier-B reviewer row, the `review-loop(rN):` push-discipline PreToolUse hook, the Copilot GraphQL re-trigger fallback, and the extra `/ai-review-loop` CLI verbs all died with the skill (v0.54.0, ADR-0018). Restoring any of them means restoring Step 9 first.
- [ ] **shellcheck warning-level cleanup** — CI now lints hooks/scripts at error level (v0.49.0); ~8 pre-existing SC1007/SC2034/SC2088 warnings in parity scripts remain before raising to -S warning. Effort: S → S. P3.

## From harness-diet plan review (2026-07-13, /autoplan)

- [ ] **Outbound-data-transfer deny rules (curl POST, scp, gh gist)** — pareto rail from YOLO-gist research; deferred as false-positive-prone (over-blocking → rail abandonment). Effort: M → S. P3. Trigger: a real exfil near-miss or sandbox adoption.
- [x] **Gate-removal quality review (ADR-0015)** — obsolete: ADR-0016 (v0.50.0, 2026-07-21) restored the gated workflow and retired the ADR-0015 kill criterion before the review window elapsed.
- [ ] **Sandbox/container isolation layer** — strongest rail per research (survives prompt injection); an ocean today. Effort: XL → L. P3.
- [ ] **Audit non-final `[[ ]]` assertions in bats suites** — bats does not fail a test when a non-final `[[ ]]` returns false (verified 1.13.0), so mid-test assertions may be silently unenforced; sweep tests/*.bats and either move assertions last, chain `|| false`, or adopt bats-assert. Effort: S → S. P2. Trigger: found while fixing the test-72 CI failure (2026-07-13). **Second sighting 2026-08-09 (v0.59.1)**: a brand-new `INSTALL_LOCK_BUSY` assertion was written unchained and passed against the exact bug it was written to catch. The three new lock cases are chained; the rest of the suite is not. Raise to P1 on a third sighting.

## From the install-lock contention fix (2026-08-09, v0.59.1)

- [ ] **`--recover` swallows a failed lock acquisition and exits 0** — `install-codex-parity.sh:330` invokes `recover_latest_migration` as an `if` condition, which disables `errexit` for the whole function body, so the `parity_acquire_lock` at `:239` returning 1 does not abort. Reproduced by the fresh-context reviewer with a live peer holding the lock: the installer prints `FAIL INSTALL_LOCK_BUSY`, performs the symlink migration the lock exists to serialize, and returns success. Install mode (`:343`) is fine. This is the "watchdog reporting green over a broken invariant" the repo forbids, and v0.59.1 raises its reachability by routing more losers to BUSY. Fix: `recover_latest_migration || status=$?` (or `parity_acquire_lock || return 1`) plus a bats case asserting `--recover` exits non-zero under a live lock. Effort: S → S. **P1.**
- [ ] **The errno-classification branch has no deterministic test** — the three v0.59.1 lock cases all exit via the freshness gate, the reclaim path, or `RuntimeError`; none enters `except OSError`. Its only coverage is the 10-installer concurrent test, which is documented in that test's own comment as unreliable at reproducing this condition. Fix: extract the acquire heredoc into `scripts/internal/parity-acquire-lock.py` so it is importable, then monkeypatch `os.mkdir`/`os.open`/`os.rmdir`/`os.unlink` to raise a chosen errno at a chosen call site and assert ENOENT/EEXIST/ENOTEMPTY → exit 2 and ELOOP/EACCES/EISDIR → exit 3. Effort: M → S. P2.
- [ ] **`os.open(pid, O_RDONLY)` has no `O_NONBLOCK`** — `codex-parity-lib.sh`, contender path: a FIFO named `pid` hangs the installer forever instead of failing. Same-uid attacker or stray mkfifo only. Effort: S → S. P3.
- [ ] **No staleness ceiling on a stamped lock** — a recycled PID that happens to match a dead owner's pins the lock at `INSTALL_LOCK_BUSY` indefinitely. Effort: M → S. P3.
- [ ] **Freshness gate reads the lock directory mtime** — on NFS or any attribute-caching filesystem a cached mtime can be stale enough to reclaim a live lock. Not a concern for the local-home deployment today. Effort: M → S. P3.
