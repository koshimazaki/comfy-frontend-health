"""ComfyUI Vue 3 frontend review heuristics — replaces React-oriented defaults.

Drop-in replacement for review.py REVIEW_GUIDANCE and HOLISTIC_REVIEW_DIMENSIONS
when scanning a ComfyUI frontend project.
"""

from __future__ import annotations

import re

# ── Dimensions ──────────────────────────────────────────────────────────
# Same 20 upstream dimensions, but rubric text is injected from our skills.
# The dimension list itself stays compatible with desloppify's scoring engine.

COMFY_HOLISTIC_REVIEW_DIMENSIONS: list[str] = [
    "cross_module_architecture",
    "convention_outlier",
    "error_consistency",
    "abstraction_fitness",
    "api_surface_coherence",
    "authorization_consistency",
    "ai_generated_debt",
    "incomplete_migration",
    "package_organization",
    "high_level_elegance",
    "mid_level_elegance",
    "low_level_elegance",
    "design_coherence",
    "initialization_coupling",
    # Additional ComfyUI-specific dimensions:
    "naming_quality",
    "contract_coherence",
    "test_strategy",
    "type_safety",
    "logic_clarity",
    "dependency_health",
    # Behavioral dimensions — "would a test catch a production break?"
    "behavioral_coverage",
    "regression_safety",
    "test_confidence",
    # Simplification — "is there a smarter way?"
    "implementation_simplicity",
]

# ── Review guidance ─────────────────────────────────────────────────────
# Sourced from AGENTS.md, code-reviewer agent, and project skills.

COMFY_REVIEW_GUIDANCE = {
    "vue_composition": [
        "Check for Options API usage — all components must use <script setup lang='ts'>",
        "Flag withDefaults — use Vue 3.5 props destructuring with defaults",
        "Flag runtime props declaration — use type-only defineProps<{...}>()",
        "Check for separate prop + emit when defineModel would work for v-model",
        "Verify state minimization: prop > ref > computed > watch (use simplest)",
        "Flag defineSlots — define slots via template usage instead",
        "Check for VueUse composables instead of manual event listeners",
        "Verify composables follow useXyz.ts naming, stores follow *Store.ts",
    ],
    "typescript_strict": [
        "Flag any 'as any' usage — Critical finding, fix the underlying type",
        "Flag bare 'any' type annotations — use proper TypeScript types",
        "Check for inline 'type' in mixed imports — use separate import type",
        "Prefer function declarations over function expressions",
        "Check for es-toolkit usage (not lodash)",
        "Verify api.get(api.apiURL(...)) pattern (not direct fetch)",
        "Flag @ts-expect-error — fix the underlying type issue",
        "Check for z.any() in Zod schemas — use z.unknown() then narrow",
    ],
    "tailwind_styling": [
        "Flag :class='[]' array syntax — use cn() from @/utils/tailwindUtil",
        "Flag dark: variant usage — use semantic theme tokens from style.css",
        "Flag !important or ! prefix — find conflicting classes instead",
        "Flag arbitrary percentages when tailwind fractions exist (w-4/5 not w-[80%])",
        "Check for raw color values — use semantic tokens",
        "Flag <style> blocks in Vue SFCs (exception: :deep() for third-party DOM)",
        "Verify cn() is used inline in template, not in a computed",
    ],
    "architecture": [
        "Verify layered architecture: base -> platform -> workbench -> renderer",
        "Flag reverse imports (e.g. base importing from platform)",
        "Flag barrel files (index.ts re-exports) within src/",
        "Check PascalCase for Vue components",
        "Check for new PrimeVue imports — should use Reka UI + shadcn-vue",
    ],
    "testing": [
        "Flag change-detector tests (just asserting defaults haven't changed)",
        "Flag tests that only test mocks (assertions can't fail when code breaks)",
        "Check for 'don't mock what you don't own' violations",
        "Verify vi.hoisted() for per-test mock manipulation",
        "Check behavioral coverage over line coverage",
        "Flag waitForTimeout in Playwright tests — use locator actions",
        "Verify test files are colocated with source (*.test.ts next to *.ts)",
    ],
    "i18n": [
        "Check vue-i18n usage for all user-facing strings in templates",
        "Verify new translations go in src/locales/en/main.json",
        "Check for hardcoded pluralization (should use i18n plurals system)",
    ],
    "design_system": [
        "Check if a component in src/components/ui/ already exists for this need (see inventory)",
        "Verify CVA variants are in colocated .variants.ts files, not inline in .vue",
        "Check Reka UI triggers use as-child to avoid wrapper div bloat",
        "Verify useForwardPropsEmits on root wrappers, useForwardProps on leaves",
        "Check data-[state=...] attribute styling instead of manual v-if/v-show toggles",
        "Verify semantic color tokens (not raw hex/rgb or Tailwind color-NNN)",
        "Check spacing consistency with design system scale (gap-1/2 tight, gap-3/4 sections)",
        "Verify accessible interactive widgets (ARIA roles, keyboard nav, focus management)",
        "Check new ui/ components have colocated .stories.ts files",
        "Flag native <dialog>, <select>, <details> — use Reka UI primitives",
        "Flag components with >14 props — needs decomposition or composition pattern",
    ],
    "naming": (
        "TypeScript uses camelCase for functions/variables, PascalCase for "
        "types/components/Vue files. Composables: useXyz.ts. Stores: *Store.ts. "
        "Check for inconsistency within modules."
    ),
    "behavioral_coverage": [
        "For each changed function: if this broke in production, would any test catch it?",
        "Check tests assert on observable behavior, not implementation details",
        "Flag code paths with user-visible impact that have zero test coverage",
        "Verify error states and edge cases are tested, not just happy paths",
        "Check that API contract changes have corresponding test updates",
    ],
    "regression_safety": [
        "If a recent commit introduced a subtle bug, would the test suite catch it?",
        "Check for tests that passed before AND after a behavioral change (false green)",
        "Flag refactored code where tests were updated to match new behavior without verifying correctness",
        "Verify critical user flows have end-to-end coverage (not just unit tests)",
        "Check that bug fixes include a regression test proving the fix",
    ],
    "test_confidence": [
        "Can you trust this test suite enough to refactor fearlessly?",
        "Flag tests with assertions that cannot fail (always-true, tautological)",
        "Check for over-mocking that decouples tests from real behavior",
        "Verify tests would break if the feature stopped working entirely",
        "Flag tests that pass on wrong output (weak assertions, partial matching)",
    ],
    "implementation_simplicity": [
        "Is there a simpler way to achieve the same result with fewer moving parts?",
        "Flag ref+watch patterns that could be a single computed",
        "Flag unnecessary abstractions — would inlining be clearer?",
        "Check for over-engineered generics when a concrete type suffices",
        "Flag multi-step transformations that could be a single expression",
        "Check if existing VueUse composables or es-toolkit functions replace custom code",
        "Flag deeply nested logic — can early returns flatten it?",
        "Ask: would a new team member understand this in under 30 seconds?",
    ],
}

# ── Migration pairs (Vue-specific) ─────────────────────────────────────

COMFY_MIGRATION_PATTERN_PAIRS = [
    (
        "Options API → Composition API",
        re.compile(r"export\s+default\s*\{"),
        re.compile(r"<script\s+setup"),
    ),
    (
        "PrimeVue → Reka UI + shadcn-vue",
        re.compile(r"from\s+['\"]primevue/"),
        re.compile(r"from\s+['\"](?:reka-ui|@/components/ui)/"),
    ),
    (
        "withDefaults → props destructuring",
        re.compile(r"\bwithDefaults\s*\("),
        re.compile(r"const\s*\{[^}]*\}\s*=\s*defineProps"),
    ),
    (
        "lodash → es-toolkit",
        re.compile(r"from\s+['\"]lodash"),
        re.compile(r"from\s+['\"]es-toolkit"),
    ),
    ("var → let/const", re.compile(r"\bvar\s+\w+"), re.compile(r"\b(?:let|const)\s+\w+")),
    ("require → import", re.compile(r"\brequire\("), re.compile(r"\bimport\s+")),
]


# Note: Boundary rules are defined directly in __init__.py TypeScriptConfig
# as BoundaryRule instances, not as tuples here.
