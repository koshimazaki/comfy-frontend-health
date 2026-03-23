---
description: >
  Find components, composables, and stores missing tests. Cross-references
  coverage data with changed files to identify gaps before PR. Runs behavioral
  analysis — not just line coverage.
  Triggers on: test gaps, missing tests, coverage gaps, untested code.
---

# /test-coverage-gaps — Find Untested Code

Discover code that lacks meaningful behavioral tests. Focuses on what matters:
user-facing behavior, edge cases, and regression risk — not line counts.

## Arguments

| Input | Mode |
|-------|------|
| *(empty)* | Scan all src/ for coverage gaps |
| `--changed` | Only check files changed vs main |
| `--pr 123` | Only check files in a PR |
| `src/stores/` | Scan specific directory |

## Phase 1: Identify Testable Files

```bash
# All .ts and .vue source files (excluding tests, stories, types, configs)
find src/ -name '*.ts' -o -name '*.vue' | \
  grep -v '.test.' | grep -v '.spec.' | grep -v '.stories.' | \
  grep -v '/types' | grep -v '.d.ts' | grep -v 'vite-env' | \
  sort > /tmp/all-source.txt

# All test files
find src/ -name '*.test.ts' | sort > /tmp/all-tests.txt

# For --changed mode:
# git diff --name-only main -- '*.ts' '*.vue' | grep -v '.test.' > /tmp/changed-source.txt
```

## Phase 2: Find Files Without Corresponding Tests

For each source file, check if a test file exists:
- `src/stores/settingStore.ts` → look for `settingStore.test.ts` anywhere in src/
- `src/composables/useFoo.ts` → look for `useFoo.test.ts`
- `src/components/Foo.vue` → look for `Foo.test.ts`

Report files with **no test at all** grouped by category:

```
## Missing Tests

### Stores (high priority — business logic)
- src/stores/settingStore.ts — NO TEST
- src/stores/workflowStore.ts — has test ✓

### Composables (high priority — shared logic)
- src/composables/useFoo.ts — NO TEST

### Components (medium priority — behavior tests)
- src/components/MyComponent.vue — NO TEST
```

## Phase 3: Behavioral Coverage Analysis

For files that DO have tests, check test quality:

1. **Read the test file** — look for:
   - Change-detector tests (just asserting defaults) → flag
   - Mock-only tests (assertions only on mocks) → flag
   - Missing edge cases (only happy path tested) → warn
   - Missing error handling tests → warn

2. **Cross-reference with source** — look for:
   - Public functions/methods without any test
   - Conditional branches without tests
   - Error paths without tests
   - Event handlers without tests

## Phase 4: Coverage Data (if available)

```bash
# Run with coverage (if not already run)
pnpm test:unit -- --coverage --reporter=json 2>/dev/null

# Parse coverage JSON for uncovered files
cat coverage/coverage-final.json | jq 'to_entries[] | select(.value.s | to_entries | map(select(.value == 0)) | length > 0) | .key'
```

## Phase 5: Report

```
/test-coverage-gaps Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Files scanned: N source files
Tests found: M test files

## No Tests At All (priority: write these first)
  Stores:      3 missing
  Composables: 2 missing
  Components:  8 missing
  Utils:       1 missing

## Weak Tests (priority: strengthen)
  src/stores/foo.test.ts — only tests defaults (change-detector)
  src/components/Bar.test.ts — 3 mocks, 0 real assertions

## Suggested Test Plan
  1. src/stores/settingStore.ts — HIGH (business logic, many consumers)
  2. src/composables/useFoo.ts — HIGH (shared across 5 components)
  3. src/components/MyComponent.vue — MEDIUM (user-facing, 3 props)

## Behavioral Gaps in Existing Tests
  src/stores/workflowStore.test.ts:
    - Missing: error handling for invalid workflow JSON
    - Missing: edge case for empty workflow
```

## Rules

- Focus on **behavioral** gaps, not line coverage percentages
- Prioritize by risk: stores > composables > components > utils
- Don't suggest tests for type files, constants, or barrel files
- Flag change-detector and mock-only tests as "weak"
- Suggest concrete test scenarios, not just "add tests"
