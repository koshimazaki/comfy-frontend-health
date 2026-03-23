---
description: >
  ComfyUI-tuned codebase health scan with flexible targeting. Supports full repo,
  specific files/folders, or git commit scope. Runs desloppify + ComfyUI conventions
  (Vue 3, TypeScript, Tailwind 4, Reka UI, layered architecture), parallel review
  agents that know AGENTS.md, and project-aware quality gates.
  Use for: health score, tech debt audit, cleanup planning, PR review, focused scan.
  Triggers on: comfy-deslop, comfy health, comfy scan, comfy debt.
---

# ComfyUI Deslop — Project-Tuned Health Scanner

You are running a ComfyUI-specific health scanner. It wraps desloppify with
project-aware agents, ComfyUI conventions, and flexible targeting.

## Argument Parsing

The user may provide arguments after `/comfy-deslop`. Parse them as:

| Input | Mode | What to do |
|-------|------|-----------|
| *(empty)* | full | Full repo scan with desloppify |
| `src/components/` | folder | Focused scan on that directory |
| `src/stores/settingStore.ts` | file | Single-file deep review |
| `HEAD` or `HEAD~3` | commit | Scan only files changed in that commit range |
| `--commit abc123` | commit | Scan files changed in specific commit |
| `--branch feature-x` | branch | Scan files changed vs main branch |
| `--staged` | staged | Scan only staged files (pre-commit check) |
| `--pr 123` | pr | Scan files changed in a GitHub PR |

## Mode: Full Repo Scan

Standard desloppify flow — see "Full Scan Workflow" section below.

## Mode: Focused Scan (file/folder/commit/branch/staged/pr)

Desloppify itself only scans full repos. For focused scans, you act as the
scanner using desloppify's issue database + ComfyUI conventions.

### Step 1: Resolve target files

```bash
# For folder:
find <folder> -name '*.ts' -o -name '*.vue' | head -50

# For commit:
git diff --name-only <commit>~1 <commit> -- '*.ts' '*.vue'

# For commit range (HEAD~3):
git diff --name-only HEAD~3 HEAD -- '*.ts' '*.vue'

# For branch vs main:
git diff --name-only main...<branch> -- '*.ts' '*.vue'

# For staged:
git diff --cached --name-only -- '*.ts' '*.vue'

# For PR:
gh pr diff <number> --name-only
```

### Step 2: Check existing desloppify issues for those files

```bash
# Show known issues for each target file/directory
desloppify show <file-or-dir> --no-budget
```

### Step 3: Run targeted quality checks in parallel

Launch these checks scoped to target files (use Agent tool for parallelism):

1. **TypeScript check** — `pnpm vue-tsc --noEmit` (project-wide, but note errors in target files)
2. **Lint** — `pnpm eslint <files>` for target files
3. **Layer audit** — check if target files violate `base -> platform -> workbench -> renderer`
4. **Knip** — check if target files have unused exports

### Step 4: Deep code review with ComfyUI conventions

For each target file, launch a `code-reviewer` agent that:
- Reads the file in full
- Applies all ComfyUI Convention Rules (see below)
- Scores severity (Critical / Warning / Info)
- Returns structured findings

For small scopes (1-5 files), do this inline. For larger scopes (5+ files),
use parallel agents — one per file or logical group.

### Step 5: Report

Present a focused report:

```
## Scan: <target description>
Files scanned: N

### Critical (must fix)
- file:line — issue description

### Warnings
- file:line — issue description

### Existing desloppify issues in scope
- ID: summary (status)

### Quality gate results
- TypeScript: pass/fail (N errors in scope)
- ESLint: pass/fail (N warnings in scope)
- Layer audit: pass/fail
- Knip: pass/fail
```

## Full Scan Workflow

### Phase 0: Pre-flight

```bash
# Exclude non-production paths
desloppify exclude "dist/**"
desloppify exclude "public/**"
desloppify exclude "*.config.*"

# Verify zones
desloppify zone show | head -30
```

### Phase 1: Mechanical Scan

```bash
desloppify scan --path .
desloppify status
desloppify next
```

### Phase 2: Subjective Review (when needed)

```bash
desloppify review --prepare
desloppify review --run-batches --dry-run
```

Launch all batch agents in parallel. Each reads its prompt file, the blind
packet, and writes JSON to the results directory. After all complete:

```bash
desloppify review --import-run <run-dir> --scan-after-import
```

### Phase 3: Execute

```bash
desloppify next    # get next item, fix it, resolve it, repeat
```

### Phase 4: Report

Score table, top issues, remaining blockers, next session focus.

## ComfyUI Convention Rules

Every review (full or focused) applies these rules:

### Architecture
- Layered: `base -> platform -> workbench -> renderer` (no reverse imports)
- No barrel files (`index.ts` re-exports) within `src/`
- Composables: `useXyz.ts`, Stores: `*Store.ts`, Components: `PascalCase.vue`

### TypeScript
- Never `any` or `as any` — Critical finding
- Separate `import type` statements (not inline `type` in mixed imports)
- Function declarations over function expressions
- `es-toolkit` not lodash
- `api.get(api.apiURL(...))` not direct fetch
- No `@ts-expect-error` — fix the underlying type

### Vue 3
- `<script setup lang="ts">` only, Composition API
- Vue 3.5 props destructuring with defaults (no `withDefaults`)
- `defineModel` over separate prop + emit for v-model
- State minimization: prop > ref > computed > watch
- VueUse composables over manual event handling
- `vue-i18n` for all user-facing strings

### Styling
- Tailwind 4 with semantic tokens — never raw colors
- Never `dark:` variant — use semantic theme tokens
- `cn()` from `@/utils/tailwindUtil` — never `:class="[]"` array
- Never `!important` or `!` prefix
- Tailwind fractions over arbitrary percentages (`w-4/5` not `w-[80%]`)

### Testing
- No change-detector tests (asserting defaults)
- No tests that just test mocks
- Don't mock what you don't own
- `vi.hoisted()` for per-test mock manipulation
- Behavioral coverage, not line coverage

### Components & Design System
- No new PrimeVue — use Reka UI primitives + shadcn-vue
- Check `src/components/ui/` inventory before building new
- CVA variants in colocated `*.variants.ts`, not inline in `.vue`
- `as-child` on Reka UI trigger components (no wrapper divs)
- `useForwardPropsEmits` on root wrappers, `useForwardProps` on leaves
- `data-[state=...]` selectors for Reka UI states (not manual v-if/v-show)
- Semantic tokens only — no raw Tailwind colors or hex values
- Accessible interactive widgets (ARIA, keyboard nav, focus management)
- New `ui/` components need colocated `.stories.ts`
- Native `<dialog>`, `<select>`, `<details>` → use Reka UI primitives
- Flag >14 props — decompose via composition pattern

## Quality Gates

Always run after fixes:

```bash
pnpm typecheck && pnpm lint && pnpm knip
```

For architecture changes, also run `/layer-audit`.

## Quick Reference

| Command | Scope | What it does |
|---------|-------|-------------|
| `/comfy-deslop` | full repo | Full desloppify scan + subjective review |
| `/comfy-deslop src/stores/` | folder | Focused scan of stores directory |
| `/comfy-deslop HEAD~3` | commits | Scan files changed in last 3 commits |
| `/comfy-deslop --staged` | staged | Pre-commit quality check |
| `/comfy-deslop --pr 456` | PR | Review all files changed in PR #456 |
| `/comfy-deslop MyComponent.vue` | file | Deep single-file review |
| `desloppify show <path>` | any | Show existing issues for path |
| `desloppify status` | full | Dashboard with all scores |
| `desloppify next` | full | Next priority item from plan |
