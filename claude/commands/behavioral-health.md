---
description: >
  Test health audit — finds untested code AND weak tests in one pass.
  Answers: "If this code broke, would any test catch it?"
  Triggers on: behavioral health, test gaps, missing tests, test quality, regression risk.
---

# /behavioral-health — Test Health Audit

One command for test coverage AND quality. Two modes:

| Input | Mode |
|-------|------|
| *(empty)* | Audit files changed vs main |
| `--full` | Full repo inventory |
| `src/stores/` | Audit specific directory |
| `--pr 123` | Audit PR files |

## Step 1: Find Target Files

```bash
# Changed mode (default):
TARGETS=$(git diff --name-only main -- 'src/**/*.ts' 'src/**/*.vue' | \
  grep -v '.test.' | grep -v '.stories.' | grep -v '.d.ts')

# Full mode: all src/ files
# Directory mode: files in specified path
```

## Step 2: For Each File — Score 1-5

For each target, find the corresponding test file and rate:

```
1 = Protected    — behavioral tests for public interfaces, edge cases covered
2 = Covered      — key behaviors tested, minor gaps
3 = Partial      — happy path only, no error/edge cases
4 = Weak         — tests exist but only assert mocks or defaults
5 = Unprotected  — no tests at all
```

**How to score:**
- Read the source file → extract exported functions, props, emits, actions, getters
- Read the test file (if any) → check what's actually asserted
- A test that **survives complete refactoring** = behavioral (good)
- A test that **only checks mock.toHaveBeenCalled()** = implementation-coupled (weak)

Priority: stores > composables > components > utils

## Step 3: Report

```
/behavioral-health Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Files: N analyzed

🔴 Unprotected (5)
  src/stores/settingStore.ts — 0 tests, 4 public actions
  src/composables/useFoo.ts — no test file

🟡 Weak (4)
  src/components/Bar.vue — test asserts mocks only, not behavior

🟢 Protected (1-2)
  src/stores/workflowStore.ts — 12 behavioral tests

Suggested next tests (TDD approach):
  1. src/stores/settingStore.ts
     RED:  it('persists setting change to localStorage')
     RED:  it('falls back to defaults on corrupt data')
  2. src/composables/useFoo.ts
     RED:  it('returns updated value when input changes')
```

## Rules

- Behavior = what the public interface does given inputs
- `mock.toHaveBeenCalled()` alone is NOT behavioral
- `expect(result).toBe(expected)` given input IS behavioral
- Don't count line coverage — count behavior coverage
- For `--full` mode, group by category with counts
