---
description: >
  Behavioral health check — verifies that code changes have meaningful tests
  that prove behavior through public interfaces, not implementation details.
  Complementary to convention-based scanning. Think: "does the test suite
  actually protect this code from regressions?"
  Triggers on: behavioral health, test quality, regression risk, behavior check.
---

# /behavioral-health — Behavioral Regression Risk Audit

Goes beyond pattern-matching to ask: "If this code broke, would any test catch it?"

**Philosophy:** A codebase with zero convention violations but no behavioral tests
is more dangerous than one with style issues and solid test coverage.

## Arguments

| Input | Mode |
|-------|------|
| *(empty)* | Audit changed files vs main |
| `src/stores/` | Audit specific directory |
| `--pr 123` | Audit PR files |
| `--full` | Full repo behavioral scan |

## Phase 1: Identify What Changed

```bash
CHANGED=$(git diff --name-only main -- 'src/**/*.ts' 'src/**/*.vue' | \
  grep -v '.test.' | grep -v '.stories.' | grep -v '.d.ts')
```

## Phase 2: For Each Changed File — Behavioral Analysis

For each file, answer these questions by reading both source and test:

### A. Public Interface Audit

Read the source file and extract:
- Exported functions/methods
- Component props + emits
- Store actions + getters
- Composable return values

Then read the corresponding test file and check:

| Question | Score |
|----------|-------|
| Does every exported function have at least one test? | ±1 per function |
| Does the test assert **behavior** (output given input)? | +1 |
| Does the test only assert implementation (mock calls, internal state)? | -1 |
| Are error/edge paths tested? | +1 per path |
| Would the test still pass if the implementation was completely rewritten? | +2 if yes |

### B. Regression Risk Score

Rate each file 1-5:

```
1 = Fully covered: behavioral tests for all public interfaces
2 = Well covered: key behaviors tested, minor gaps
3 = Partially covered: happy path only, no edge cases
4 = Weakly covered: tests exist but only test mocks/defaults
5 = Unprotected: no tests, or tests wouldn't catch regressions
```

### C. Contract Verification

For components, verify:
- Props with defaults: is the default behavior tested?
- Emits: are emit triggers tested via user interaction (click, input), not just calling the handler?
- Slots: are slot renders tested?
- v-model: is two-way binding tested end-to-end?

For stores, verify:
- Actions: are side effects tested (API calls, state mutations)?
- Getters: are computed derivations tested with varying input state?
- Subscriptions/watchers: are reactive updates tested?

For composables, verify:
- Return values change correctly when inputs change
- Cleanup happens on unmount
- Edge cases (null input, empty arrays, etc.)

## Phase 3: TDD Gap Analysis

For files scoring 3+ (risky), suggest concrete test scenarios:

```
## File: src/stores/settingStore.ts (Risk: 4/5)

Missing behavioral tests:
1. When user changes a setting → store persists to localStorage
2. When localStorage has corrupt data → store falls back to defaults
3. When two settings conflict → resolution priority is correct

Suggested TDD approach:
  RED:  it('persists setting change to localStorage', ...)
  GREEN: implement/fix the persistence logic
  RED:  it('falls back to defaults on corrupt localStorage', ...)
  GREEN: add error handling
```

## Phase 4: Report

```
/behavioral-health Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Files analyzed: N changed files

Risk Distribution:
  🟢 Protected (1-2):  5 files
  🟡 Gaps (3):         3 files
  🔴 At Risk (4-5):    2 files

## At Risk (write tests BEFORE merging)

  src/stores/settingStore.ts (5/5)
    0 of 4 public actions tested behaviorally
    Suggested: 3 test scenarios (see above)

  src/composables/useFoo.ts (4/5)
    Test exists but only asserts mock was called
    Suggested: test return value changes with input

## Gaps (strengthen before or after merge)

  src/components/MyDialog.vue (3/5)
    Props tested, emits untested
    Missing: close-on-escape, close-on-overlay-click

## Protected ✓

  src/stores/workflowStore.ts (1/5) — 12 behavioral tests
  src/utils/tailwindUtil.ts (2/5) — happy path covered
```

## Integration with /pre-pr

Add to Phase 3 of `/pre-pr`:

```bash
# After running unit tests, check behavioral coverage
/behavioral-health --changed
```

Flag files scoring 4+ as warnings in the pre-PR report.

## Rules

- **Behavior = what the public interface does given inputs**
- Tests that only verify mock.toHaveBeenCalled() are NOT behavioral
- Tests that assert computed output given props/state ARE behavioral
- A test that survives complete internal refactoring = good behavioral test
- Don't count line coverage — count behavior coverage
- Prioritize: stores > composables > components > utils
