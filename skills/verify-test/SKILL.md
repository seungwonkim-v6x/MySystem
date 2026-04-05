---
name: verify-test
description: Generate throwaway code-based tests to verify a feature works, run them, then delete the test files. Tests are never committed. Auto-triggers after implementation, before code review.
---

# /verify-test — Throwaway Verification Tests

Generate code-based tests to verify the implemented feature works correctly. Tests are disposable -- generated, executed, and deleted. Never committed.

## When to Run

1. **Automatic**: After implementation step, before /review
2. **Manual**: User invokes `/verify-test`

## Workflow

### Step 1: Analyze Changes

```bash
# Identify what changed
git diff develop..HEAD --stat
git diff develop..HEAD
```

Determine:
- Which functions/modules were added or modified
- What the expected behavior should be
- Which test framework the project uses (vitest, jest, mocha, pytest, go test, etc.)

### Step 2: Generate Test Files

Write test files to `/tmp/verify-test-{timestamp}/`:
- One test file per changed module
- Cover: happy path, edge cases (null, empty, boundary), error cases
- Import directly from the project source
- Use the project's existing test framework and patterns

```
/tmp/verify-test-{timestamp}/
  module-a.test.ts
  module-b.test.ts
  ...
```

### Step 3: Execute Tests

Run the tests using the project's test runner:

```bash
# Example for vitest
npx vitest run /tmp/verify-test-{timestamp}/ --reporter=verbose

# Example for jest
npx jest /tmp/verify-test-{timestamp}/ --verbose

# Example for pytest
python -m pytest /tmp/verify-test-{timestamp}/ -v
```

### Step 4: Report Results

Present to the user:

```markdown
## Verify-Test Results

### Passed (N)
- module-a: all 5 cases passed
- module-b: all 3 cases passed

### Failed (N)
- module-c: 2/4 failed
  - FAIL: handles null input -- expected null, got undefined
  - FAIL: boundary condition -- off-by-one at max value

### Summary
X/Y tests passed. [Issues found / All clear]
```

### Step 5: Cleanup

**ALWAYS delete test files after reporting, regardless of pass/fail:**

```bash
rm -rf /tmp/verify-test-{timestamp}/
```

Test files are NEVER staged, committed, or kept.

## Rules

- **Throwaway only** -- tests exist solely to verify, then disappear
- **No project pollution** -- all test files in /tmp, never in project tree
- **Use project conventions** -- match the project's test framework, import style, patterns
- **Code-based only** -- no browser, no login, no external services
- **Report before delete** -- always show results to user before cleanup
- **Failed tests are signal** -- if tests fail, report the issue. Do not fix the tests. The implementation may need fixing.
