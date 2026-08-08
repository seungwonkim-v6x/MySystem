# Handoff: intermittent CI failure in the concurrent-installer test

**Status:** open, not root-caused. Non-blocking — it has failed once.
**Opened:** 2026-08-08, during the v0.59.0 ship (PR #20).
**Owner:** unassigned.

Read this end to end before touching anything. The last session spent a
significant amount of its budget characterizing this and could not reproduce it;
the value here is in what has already been ruled out, so you do not repeat it.

---

## The symptom

`tests/codex-parity.bats` → **"concurrent installers preserve a valid final state
and expose only lock contention"** failed on a macOS CI runner.

```
not ok 16 concurrent installers preserve a valid final state and expose only lock contention
# (in test file tests/codex-parity.bats, line 391)
#   `grep -q 'INSTALL_LOCK_BUSY' "$TEST_ROOT/concurrent.$index.log"' failed
```

The test launches 10 installers concurrently and asserts that any which fail did
so **only** with `INSTALL_LOCK_BUSY`. So one loser exited non-zero with a
different failure. Which one is unknown — see *What was already changed*.

### Exact coordinates

| | |
|---|---|
| Failing job | run `31264264997` / job `93119757451`, `macos-latest` |
| Commit | `db14615` (v0.59.0, pre-merge) |
| **Sibling job, same commit** | run `31264263096` / job `93119751847`, `macos-latest` → **pass** |
| ubuntu-latest, same commit | both runs pass |
| Merged as | `64cff05` on `main` |

The same commit passing and failing on two macOS runners is the proof that this
is a race, not a defect in the change under test.

---

## What has been ruled out (do not redo)

| Hypothesis | Method | Result |
|---|---|---|
| Deterministic regression from v0.59.0 | ran the test 8× locally on `HEAD` (v0.59.0) and 8× on `HEAD~1` (v0.58.0), macOS | 0/8 failures both |
| Load sensitivity | 10× locally with six `yes >/dev/null` CPU hogs, macOS | 0/10 failures |
| Linux-specific | ubuntu-latest, both runs, same commit | pass |
| Pre-existing and frequent | `gh run list --workflow test.yml --limit 12` | 12 runs, first failure ever observed |

Total: **26 local runs, zero reproductions.** Do not start by trying to reproduce
locally on a fast machine; that has been done.

---

## Why it plausibly appeared now (unproven)

v0.59.0 added `scope-check` to `.profiles.core.skills`, so
`install-codex-parity.sh` links one more portable skill per run. That lengthens
the installer's critical section, which widens every race window in the lock
protocol. This is a hypothesis about *probability*, not about correctness: the
lock protocol either has a race or it does not, and v0.59.0 does not touch it.

Do not "fix" this by reverting the skill.

---

## Prime suspects, in order

All of these live in `scripts/codex-parity-lib.sh`, inside the Python heredoc of
`parity_acquire_lock()`. Line numbers are as of `64cff05`.

### S1 — unguarded `mkdir` on the reclaim path (`:426-429`)

```python
os.rmdir("install.lock", dir_fd=parent_fd)      # 426
os.fsync(parent_fd)
os.mkdir("install.lock", 0o700, dir_fd=parent_fd)  # 428  <-- not inside a try
```

The `except FileExistsError` at `:379` wraps **only the first** `mkdir` at
`:377`. If another installer wins the gap between the `rmdir` at `:426` and the
`mkdir` at `:428`, this one raises an uncaught `FileExistsError`, the heredoc
dies with a traceback, and the caller reports something that is **not**
`INSTALL_LOCK_BUSY` — which is exactly the observed symptom.

Reaching `:426` requires falling past the freshness gate at `:407-410`, i.e. a
lock directory that exists, carries no `pid`, and is **older than 5 seconds**.

### S2 — `rmdir` on a directory that just became non-empty (`:426`)

Same window, other side: if the true owner writes its `pid` between this
process's `listdir` at `:384` and its `rmdir` at `:426`, the `rmdir` fails with
`ENOTEMPTY`. Also uncaught, also not `INSTALL_LOCK_BUSY`.

### S3 — the `RuntimeError` family → `INSTALL_LOCK_STALE_UNSAFE`

`:382` (lock leaf linked/unowned/group-writable), `:386` (lock dir contains
anything other than `pid`), `:393` (pid leaf unsafe), `:396` (pid malformed).
These surface as `INSTALL_LOCK_STALE_UNSAFE` at `:457`, which the test's grep
does not accept. `:386` is the interesting one under concurrency — any transient
leaf inside the lock dir trips it.

### The 5-second grace window (`:408`)

```python
if time.time() - fresh.st_mtime < 5.0:
    print("pending"); raise SystemExit(2)     # -> INSTALL_LOCK_BUSY
```

The comment at `:400-406` explains the design: a fresh, pid-less lock is live
contention, not an abandoned one. On a slow runner with 10 contenders, whether a
lock is judged fresh depends on wall-clock scheduling. **This constant is the
knob most likely to matter, and the one most likely to be tuned for the wrong
reason.** Raising it hides S1/S2 rather than fixing them.

---

## What was already changed

`tests/codex-parity.bats` now prints the losing installer's log when the grep
fails. **The assertion is unchanged** — verified by sabotage (swapping the token
for one that is never emitted still turns the test red, and now prints the log).

That means the next occurrence tells you which failure code it actually hit, and
that single line probably decides between S1/S2 and S3. **If CI is currently
green, your cheapest move is to wait for the next occurrence rather than to
theorize.**

---

## If you want to force it rather than wait

The lock protocol is the unit under test; the installer is not. Drive
`parity_acquire_lock` directly instead of paying for 10 full installs:

1. Source `scripts/codex-parity-lib.sh` in a scratch `$MYSYSTEM_STATE_DIR`.
2. Spawn 20-50 concurrent `parity_acquire_lock` calls in a tight loop.
3. To exercise the reclaim path deliberately: create `install.lock/` with no
   `pid` and back-date its mtime past 5 seconds
   (`touch -t` / `os.utime`), then start contenders.
4. Assert every non-zero exit is `INSTALL_LOCK_BUSY`.

Constrain the runner (`taskpolicy -c background`, a single-CPU container, or
`ulimit`) — the failure appeared on a slow shared runner, not a fast laptop.

---

## Acceptance criteria

Do not close this until:

- [ ] The actual failing code is known — from a real occurrence or a forced
      reproduction, not inference.
- [ ] The fix makes every losing installer exit with `INSTALL_LOCK_BUSY`, and a
      forced-contention loop (≥ 50 iterations, constrained CPU) shows zero other
      codes.
- [ ] The test's assertion is still `INSTALL_LOCK_BUSY` only. **Widening the grep
      to accept `INSTALL_LOCK_STALE_UNSAFE` is not a fix** — the whole point of
      the test is that a loser must be distinguishable from a corrupted lock.
- [ ] `tests/codex-parity.bats` gains a case for whichever path was at fault, and
      that case fails against the pre-fix `codex-parity-lib.sh`.

## Constraints

- `scripts/codex-parity-lib.sh` is safety-adjacent: the lock exists so two
  installers cannot interleave symlink migrations. Do not simplify the ownership
  and `O_NOFOLLOW` checks to make the race easier to reason about.
- The repo's convention is that a watchdog reporting green over a broken
  invariant is worse than no watchdog. Prefer failing loudly.
- Raising the 5-second grace window is a symptom mask unless S1/S2 are shown to
  be impossible.

## References

- Test: `tests/codex-parity.bats`, `@test "concurrent installers …"`
- Lock: `scripts/codex-parity-lib.sh` → `parity_acquire_lock()`, `:340-500`
- Failure codes: `:453` (`INSTALL_LOCK_BUSY`), `:457` (`INSTALL_LOCK_STALE_UNSAFE`)
- Caller + `trap`: `scripts/install-codex-parity.sh:20`
- CHANGELOG `[0.59.0]` records the flake and the diagnostic
