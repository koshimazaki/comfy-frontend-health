# comfy-frontend-health

Fork of [desloppify](https://github.com/peteromallet/desloppify) tuned for ComfyUI frontend projects. Adds Vue 3 + TypeScript + Tailwind 4 detectors, Reka UI/shadcn-vue conventions, layered architecture enforcement, and bundles the full ComfyUI Claude Code agent/skill ecosystem.

## What it adds over upstream desloppify

| Layer | Upstream (generic TS/React) | This fork (Vue/ComfyUI) |
|-------|---------------------------|------------------------|
| **Detectors** | React hooks, context nesting, state sync | Vue composition API, Tailwind tokens, PrimeVue→Reka, layer violations, i18n gaps |
| **Review guidance** | useEffect, useState, Context patterns | script setup, defineModel, cn(), semantic tokens, AGENTS.md rules |
| **Boundaries** | generic shared→tools | base→platform→workbench→renderer |
| **Migrations** | class→functional, axios→fetch | Options→Composition, PrimeVue→Reka, withDefaults→destructuring, lodash→es-toolkit |
| **Scoping** | full repo only | + `--pr`, `--diff`, `--staged`, `--files` (via /comfy-deslop) |
| **Agent bundle** | none | 8 skills, 7 commands, 1 agent, AGENTS.md, guidance docs |

## Install

```bash
git clone https://github.com/user/comfy-frontend-health.git
cd comfy-frontend-health
./install.sh /path/to/your/comfyui-frontend
```

This:
1. Installs the desloppify fork (with Vue detectors)
2. Copies Claude Code agents/skills/commands into your project's `.claude/`
3. Installs `/comfy-deslop` as a global Claude Code command

## Usage

### Full repo scan
```bash
desloppify scan          # mechanical scan (14 detectors + Vue detectors)
desloppify status        # dashboard with all scores
/comfy-deslop            # full scan + subjective review with ComfyUI-aware agents
```

### Targeted scans (via /comfy-deslop)
```bash
/comfy-deslop src/stores/         # scan a folder
/comfy-deslop MyComponent.vue     # deep single-file review
/comfy-deslop HEAD~3              # scan files changed in last 3 commits
/comfy-deslop --staged            # pre-commit quality check
/comfy-deslop --pr 456            # review all files in a PR
/comfy-deslop --branch feature-x  # scan changes vs main
```

### Cleanup workflow
```bash
desloppify next          # highest-priority item to fix
# fix it
# resolve it
desloppify next          # repeat until queue empty
desloppify scan          # rescan to verify progress
```

## What's included

### Vue detectors (`desloppify-fork/desloppify/languages/typescript/detectors/vue/`)

| Detector | What it catches |
|----------|----------------|
| `composition_api.py` | Options API, missing script setup, withDefaults, runtime props, defineSlots |
| `styling.py` | :class="[]" arrays, dark: variant, !important, arbitrary %, style blocks |
| `components.py` | PrimeVue imports, as any, bare any, mixed import type, direct fetch, barrel files |
| `layer_violations.py` | base→platform→workbench→renderer import direction violations |

### Review guidance (`review_comfy.py`)

Vue/ComfyUI-specific rubrics for all 20 subjective review dimensions, sourced from AGENTS.md and project skills. Covers: vue composition, typescript strict, tailwind styling, architecture, testing, i18n, design system, naming.

### Claude Code bundle (`claude/`)

Copied from the ComfyUI frontend repo — these are the actual production agents/skills:

**Agents:**
- `code-reviewer` — Vue 3 + TS + Tailwind code reviewer with AGENTS.md knowledge

**Skills:**
- `tdd` — Test-driven development with Vitest + Vue Test Utils
- `design-system` — Color palette, tokens, component inventory, layout patterns
- `shadcn-vue-reka` — Reka UI primitives + shadcn-vue CVA patterns
- `layer-audit` — Architecture boundary violation checker
- `writing-playwright-tests` — E2E test authoring for Playwright
- `writing-storybook-stories` — Storybook story authoring
- `product-design-guideline` — UX heuristics and design principles

**Commands:**
- `comfy-deslop` — The main scan command with flexible targeting
- `comprehensive-pr-review` — Full PR review with all conventions
- `pre-pr` — Local quality gate before pushing (mechanical + behavioral + review)
- `behavioral-health` — Behavioral regression risk audit (TDD-philosophy)
- `test-coverage-gaps` — Find components/stores missing meaningful tests
- `add-missing-i18n` — Find and add missing vue-i18n translations
- `verify-visually` — Visual verification of UI changes

**Reference docs:**
- `AGENTS.md` — Full project conventions (source of truth)
- `typescript.md`, `vue-components.md`, `playwright.md`, `vitest.md`, `storybook.md`, `product-design.md`

## Architecture

```
comfy-frontend-health/
  desloppify-fork/              # Forked desloppify with Vue detectors
    desloppify/
      languages/typescript/
        detectors/vue/          # NEW: Vue 3 / ComfyUI detectors
          composition_api.py
          styling.py
          components.py
          layer_violations.py
        review_comfy.py         # NEW: Vue/ComfyUI review guidance
        review.py               # Original (React) — kept for reference
  claude/                       # Agent/skill bundle (copied to target .claude/)
    agents/
      code-reviewer.md
    skills/
      tdd/
      design-system/
      shadcn-vue-reka/
      layer-audit/
      writing-playwright-tests/
      writing-storybook-stories/
      product-design-guideline/
    commands/
      comfy-deslop.md
      comprehensive-pr-review.md
      add-missing-i18n.md
      verify-visually.md
    AGENTS.md                   # Project conventions reference
    *.md                        # Guidance docs (typescript, vue, etc.)
  install.sh                    # One-command setup
  README.md
```

## How it relates to other tools

| Tool | What it does | Relationship |
|------|-------------|-------------|
| **desloppify** | Generic codebase health engine | We fork it, add Vue detectors |
| **comfy-conventions** | Org-wide dev conventions (git, Linear, PRDs) | Complements — we focus on code quality |
| **ESLint/oxlint** | Line-level linting | We complement — we catch architectural/design issues linters miss |
| **pnpm typecheck** | TypeScript errors | We integrate as a quality gate |
| **pnpm knip** | Dead code detection | We integrate as a quality gate |

## Contributing

PRs welcome. The Vue detectors are straightforward Python regex scanners — easy to add new patterns. The review guidance is plain text that gets injected into AI agent prompts.
