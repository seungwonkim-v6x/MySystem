# Pre-commit Setup — MySystem template

How to bootstrap pre-commit hooks in a new project so `/review` only deals with what hooks can't catch.

## Why

Defense in depth: cheap-fast-local hooks (secrets, lint, format, SAST) reduce what the LLM `/review` step has to look at by 60-70%. The LLM step then focuses on trust boundaries, SQL safety, and conditional side effects — things hooks genuinely can't catch.

Performance budget: total `pre-commit run --all-files` <5s on small diffs.

## One-time install

```bash
# 1. Copy the template into your repo root
cp ~/.claude/templates/.pre-commit-config.yaml.template <repo>/.pre-commit-config.yaml

# 2. Install pre-commit (Python)
pip install pre-commit          # or: pipx install pre-commit / brew install pre-commit

# 3. Install the git hook
cd <repo>
pre-commit install

# 4. Sanity run on the whole repo (first run is slow — caches afterward)
pre-commit run --all-files
```

## Customize before committing the config

Open `.pre-commit-config.yaml` in your repo and:

1. **Pick languages**. The template ships with TS/JS sections active and Python / Rust sections commented out. Uncomment what you need; delete what you don't.
2. **Tune semgrep packs**. `p/security-audit` + `p/secrets` is a low-noise default. Add `p/owasp-top-ten` for web apps. Drop a pack entirely if it generates >2 false positives in the first week.
3. **Adjust large-file threshold**. Default is 500KB. Raise for repos with binary fixtures.

## Workflow integration

Once pre-commit is installed in a project, MySystem Step 7 `/review` is allowed to skip:
- Lint findings (oxlint/ruff already ran)
- Format issues (prettier already ran)
- Secrets (gitleaks already ran)
- Trailing whitespace, EOL, merge markers, large files
- Simple SAST patterns covered by the active semgrep packs

`/review` MUST still cover:
- Trust boundary violations (auth checks, input validation at system edges)
- SQL safety (parameterization, RLS, injection vectors hooks miss)
- Conditional side effects (off-by-one in branches, shadowed state mutations)
- Architectural drift (abstractions leaking, dead code paths)
- Logic bugs (the fresh-eye / former /bugbot lens)

## Updating

```bash
pre-commit autoupdate           # bump rev pins
pre-commit run --all-files      # verify still green
```

If a hook starts producing noise after update, pin to the previous `rev` and file a TODO to investigate.

## Uninstalling

```bash
pre-commit uninstall            # remove the git hook
rm .pre-commit-config.yaml      # remove the config
```

## Troubleshooting

- **First run takes minutes** — initial install builds tool caches. Subsequent runs are <5s.
- **Hook fails on unrelated files** — pre-commit only runs on staged files; if it's flagging the whole repo, you ran `--all-files` (intentional).
- **Network errors during install** — semgrep and gitleaks need network on first install. Run once on a connected machine; cache persists.
- **CI mismatch** — run pre-commit in CI too: `pre-commit run --all-files` in your CI pipeline ensures local + CI agree.
