---
description: Pre-PR quality gate — run locally before pushing. Catches issues early so CI doesn't have to.
---

# /pre-pr — Local Quality Gate

Run all quality checks before opening a PR. Stops on first failure.

**Flags:**
- `--quick` — Skip code-reviewer agent (Phases 1-2 only)
- `--full` — Include build + bundle size delta (Phase 4)
- No flag — Phases 1-3 (default)

## Execution

### Phase 1: Mechanical Checks (~30s)

Run these in parallel. All must pass before proceeding.

```bash
# Run all 4 in parallel
pnpm format:check &
pnpm lint &
pnpm typecheck &
pnpm knip --cache &
wait
```

If any fail, stop and report which check failed with the first few lines of output.
Do NOT proceed to Phase 2 if Phase 1 fails.

### Phase 2: Convention Scan (~10s)

Run targeted grep checks for patterns that ESLint/oxlint don't catch:

```bash
# Check changed files only (faster)
CHANGED=$(git diff --name-only HEAD~1 -- '*.vue' '*.ts' | grep -v node_modules | grep -v '.test.' | grep -v '.spec.')
```

For each changed file, check for:
1. `:class="["` — should use `cn()` from `@/utils/tailwindUtil`
2. `as any` — fix the underlying type issue
3. `!important` or `!bg-` / `!text-` prefix — find conflicting classes instead
4. `<style` blocks in `.vue` files (exception: `:deep()`)
5. `z.any()` — use `z.unknown()` then narrow
6. `@ts-expect-error` / `@ts-ignore` — fix the underlying type issue
7. `waitForTimeout` in `.spec.ts` files — use locator actions
8. `withDefaults(` in `.vue` files — use props destructuring

Report findings grouped by file with line numbers. These are warnings, not blockers — but flag them clearly.

### Phase 3: Targeted Tests (~60s)

Run unit tests for changed files only:

```bash
# Find test files that correspond to changed source files
CHANGED_SRC=$(git diff --name-only HEAD~1 -- 'src/**/*.ts' 'src/**/*.vue')
TEST_FILES=""
for f in $CHANGED_SRC; do
  test_file="${f%.ts}.test.ts"
  test_file2="${f%.vue}.test.ts"
  if [ -f "$test_file" ]; then TEST_FILES="$TEST_FILES $test_file"; fi
  if [ -f "$test_file2" ]; then TEST_FILES="$TEST_FILES $test_file2"; fi
done

if [ -n "$TEST_FILES" ]; then
  pnpm test:unit -- $TEST_FILES
fi
```

Also run layer audit if any files in `src/base/`, `src/platform/`, `src/workbench/`, or `src/renderer/` changed:

```bash
LAYER_CHANGED=$(echo "$CHANGED_SRC" | grep -E 'src/(base|platform|workbench|renderer)/')
if [ -n "$LAYER_CHANGED" ]; then
  pnpm lint 2>&1 | grep 'import-x/no-restricted-paths' -B1 | head -50
fi
```

Check i18n if any `.vue` template files changed:

```bash
VUE_CHANGED=$(git diff --name-only HEAD~1 -- '*.vue')
if [ -n "$VUE_CHANGED" ]; then
  pnpm exec tsx scripts/check-unused-i18n-keys.ts 2>&1 | tail -10
fi
```

### Phase 3b: Code Review (skip with `--quick`)

Invoke the code-reviewer agent on the diff:

```
Run the code-reviewer agent against `git diff main...HEAD`
Focus on: AGENTS.md violations, type safety, styling rules, layer architecture, test quality
```

Report findings inline. This is the judgment-based review that catches what grep can't.

### Phase 4: Impact Assessment (only with `--full`)

```bash
pnpm build
# If size scripts exist:
pnpm size:collect 2>/dev/null
pnpm size:report 2>/dev/null
```

Report bundle size delta if available.

## Output Format

```
/pre-pr Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Phase 1: Mechanical
  format     ✓
  lint       ✓
  typecheck  ✓
  knip       ✓

Phase 2: Convention Scan (3 files checked)
  ⚠ src/components/Bad.vue:12 — :class="[]" array syntax
  ⚠ src/utils/helper.ts:5 — as any usage
  ✓ No blockers

Phase 3: Tests
  ✓ 12 tests passed (2 files)
  ✓ Layer audit clean
  ✓ i18n keys valid

Phase 3b: Code Review
  ⚠ 1 warning: ref+watch could be computed (src/composables/useFoo.ts:23)
  ✓ No critical issues

Result: READY TO PUSH (2 warnings)
```

If any phase fails critically:
```
Result: NOT READY — fix Phase 1 failures first
```
