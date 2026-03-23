---
description: Pre-PR quality gate — run locally before pushing. Fast by default, deep on demand.
---

# /pre-pr — Local Quality Gate

**Flags:**
- *(default)* — Stage 1 + 2 (~90s)
- `--review` — Add code-reviewer agent (Stage 3)
- `--full` — Add build + bundle size (Stage 4)
- `--quick` — Stage 1 only (~30s)

## Stage 1: Deterministic Checks

Run in parallel. All must pass before proceeding.

```bash
pnpm format:check &
pnpm lint &
pnpm typecheck &
pnpm knip --cache &
wait
```

Then grep changed files for convention violations ESLint doesn't catch:

```bash
CHANGED=$(git diff --name-only HEAD~1 -- '*.vue' '*.ts' | grep -v node_modules | grep -v '.test.' | grep -v '.spec.')
```

For each changed file, check for:
1. `:class="["` → use `cn()`
2. `as any` → fix the type
3. `!important` or `!bg-` / `!text-` → fix conflicting classes
4. `<style` in `.vue` (exception: `:deep()`)
5. `z.any()` → use `z.unknown()`
6. `@ts-expect-error` / `@ts-ignore` → fix the type
7. `waitForTimeout` in `.spec.ts` → use locator actions
8. `withDefaults(` → use props destructuring
9. `bg-red-` / `text-gray-` etc → use semantic tokens
10. `from 'primevue/` → use Reka UI
11. `<dialog` / `<select>` / `<details>` in `.vue` → Reka UI primitives
12. `cva({` inside `.vue` → extract to `.variants.ts`

Stop here if Stage 1 fails. Convention issues are warnings, not blockers.

## Stage 2: Diff-Scoped Validation

Run tests for changed files:

```bash
CHANGED_SRC=$(git diff --name-only HEAD~1 -- 'src/**/*.ts' 'src/**/*.vue')
TEST_FILES=""
for f in $CHANGED_SRC; do
  test_file="${f%.ts}.test.ts"
  test_file2="${f%.vue}.test.ts"
  [ -f "$test_file" ] && TEST_FILES="$TEST_FILES $test_file"
  [ -f "$test_file2" ] && TEST_FILES="$TEST_FILES $test_file2"
done
[ -n "$TEST_FILES" ] && pnpm test:unit -- $TEST_FILES
```

Conditional checks (only when relevant files changed):

```bash
# Layer audit — only if layered directories changed
echo "$CHANGED_SRC" | grep -qE 'src/(base|platform|workbench|renderer)/' && \
  pnpm lint 2>&1 | grep 'import-x/no-restricted-paths' -B1 | head -50

# i18n — only if .vue files changed
git diff --name-only HEAD~1 -- '*.vue' | grep -q . && \
  pnpm exec tsx scripts/check-unused-i18n-keys.ts 2>&1 | tail -10
```

Flag changed source files that have **no corresponding test** (warning, not blocker):

```bash
for f in $CHANGED_SRC; do
  test_file="${f%.ts}.test.ts"
  test_file2="${f%.vue}.test.ts"
  [ ! -f "$test_file" ] && [ ! -f "$test_file2" ] && echo "⚠ No test: $f"
done
```

Completeness warnings (non-blocking):

```bash
# New composables with no unit test
echo "$CHANGED_SRC" | grep -E 'use[A-Z].*\.ts$' | while read f; do
  test_file="${f%.ts}.test.ts"
  [ ! -f "$test_file" ] && echo "⚠ No unit test for composable: $f"
done

# New components/routes with no E2E spec
echo "$CHANGED_SRC" | grep -E '\.vue$' | while read f; do
  base=$(basename "$f" .vue)
  find browser_tests -name "*${base}*spec.ts" 2>/dev/null | grep -q . || echo "⚠ No E2E spec: $f"
done

# E2E tests not using ComfyPage fixtures
echo "$CHANGED_SRC" | grep -E '\.spec\.ts$' | while read f; do
  grep -q 'ComfyPage' "$f" || echo "⚠ Spec missing ComfyPage fixture: $f"
done
```

## Stage 2b: Branch Health Delta

Classify all changed files vs main:

```bash
# New files — all issues are yours
NEW_FILES=$(git diff --name-only --diff-filter=A main -- 'src/**/*.ts' 'src/**/*.vue')

# Modified files — check what existed on main
MOD_FILES=$(git diff --name-only --diff-filter=M main -- 'src/**/*.ts' 'src/**/*.vue')
```

For each modified file with issues, verify against main:
```bash
# Does this issue exist on main? If yes → pre-existing, not blocking
git show main:<file> | grep -n '<pattern>'
```

Report:
```
Branch Health Delta
  New files: N (issues: X)
  Modified files: M (branch-introduced: Y, pre-existing: Z)
  Tests added: +A
  Net: BETTER/NEUTRAL/WORSE than main
```

## Stage 3: Code Review (only with `--review`)

```
Run the code-reviewer agent against `git diff main...HEAD`
Focus on: bugs, AGENTS.md violations, type safety, design system, test quality, simplification
Agent MUST classify findings as INTRODUCED vs PRE-EXISTING (see code-reviewer agent spec)
```

## Stage 4: Build Impact (only with `--full`)

```bash
pnpm build
pnpm size:collect 2>/dev/null
pnpm size:report 2>/dev/null
```

## Output

```
/pre-pr Results
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Stage 1: Checks
  format     ✓
  lint       ✓
  typecheck  ✓
  knip       ✓
  convention ⚠ 2 warnings (src/Bad.vue:12 :class=[], src/x.ts:5 as any)

Stage 2: Validation
  tests      ✓ 12 passed (2 files)
  layer      ✓ clean
  i18n       ✓ valid
  untested   ⚠ src/composables/useFoo.ts (no test file)

Branch Health Delta
  New files: 4 (issues: 3)
  Modified: 8 (branch-introduced: 2, pre-existing: 12)
  Tests: +2 added, 1 composable still untested
  Net: BETTER (added tests, reduced debt in 2 files)

Result: READY TO PUSH (5 branch-introduced warnings, 12 pre-existing noted)
```
