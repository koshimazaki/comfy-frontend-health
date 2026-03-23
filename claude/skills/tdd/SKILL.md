---
name: tdd
description: >
  Test-driven development for ComfyUI frontend with Vitest + Vue Test Utils.
  Use when building features or fixing bugs using TDD, red-green-refactor,
  or when asked to write a failing test first. References project testing
  patterns in docs/testing/.
---

# Test-Driven Development for ComfyUI Frontend

## Core Principle

Write ONE failing test, then minimal code to pass it, then refactor. Repeat.

Tests verify **behavior through public interfaces**, not implementation details.

## Anti-Pattern: Horizontal Slices

**Never write all tests first then all code.** That's "horizontal slicing" and produces tests that verify imagined behavior.

```
WRONG (horizontal):
  RED:   test1, test2, test3, test4, test5
  GREEN: impl1, impl2, impl3, impl4, impl5

RIGHT (vertical):
  RED->GREEN: test1->impl1
  RED->GREEN: test2->impl2
  RED->GREEN: test3->impl3
```

## Workflow

### 1. Plan the Behavior

- Confirm with user what interface changes are needed
- Confirm which behaviors to test (you can't test everything)
- List behaviors, not implementation steps
- Get user approval on the plan

### 2. Red-Green Loop

```
RED:   Write ONE test for ONE behavior -> test fails
GREEN: Write minimal code to pass -> test passes
REFACTOR: Clean up -> tests still pass
REPEAT
```

### 3. Run Tests

```bash
# Single test file (fastest feedback)
pnpm test:unit -- src/path/to/file.test.ts

# All unit tests
pnpm test:unit

# E2E tests
pnpm test:browser:local
```

### 4. Refactor (only when GREEN)

- Extract duplication
- Simplify interfaces
- Run tests after each refactor step
- Never refactor while RED

## Test Types

| Type | Tool | File Pattern | Use For |
|------|------|-------------|---------|
| Unit | Vitest + happy-dom | `**/*.test.ts` | Pure functions, composables, store logic |
| Component | Vitest + Vue Test Utils | `**/*.test.ts` | Vue component behavior, props, emits |
| E2E | Playwright | `browser_tests/**/*.spec.ts` | Full user flows in real browser |

## Project Testing Patterns

Detailed patterns with examples are in `docs/testing/`:

- **`vitest-patterns.md`** — Pinia setup, mock patterns, fake timers, assertion style
- **`component-testing.md`** — Vue Test Utils mount, events, async, reactivity
- **`store-testing.md`** — Pinia store state, actions, getters, watchers
- **`unit-testing.md`** — Composables, LiteGraph, workflow JSON, mocking

### Pinia Store Test Setup

```typescript
import { createTestingPinia } from '@pinia/testing'
import { setActivePinia } from 'pinia'
import { beforeEach, describe, expect, it, vi } from 'vitest'

describe('MyStore', () => {
  beforeEach(() => {
    setActivePinia(createTestingPinia({ stubActions: false }))
    vi.resetAllMocks()
  })
})
```

### Component Test Setup

```typescript
import { mount } from '@vue/test-utils'

const mountComponent = (props = {}) =>
  mount(MyComponent, {
    props: { ...defaultProps, ...props }
  })
```

### Module Mocking

```typescript
vi.mock('@/scripts/api', () => ({
  api: {
    addEventListener: vi.fn(),
    fetchData: vi.fn()
  }
}))

// Per-test configuration
it('handles success', () => {
  vi.mocked(api.fetchData).mockResolvedValue({ data: 'test' })
  // ...
})
```

### Composable Mocking (singleton pattern)

```typescript
vi.mock('@/composables/useMyComposable', () => {
  const doSomething = vi.fn()
  const isLoading = ref(false)
  return {
    useMyComposable: () => ({ doSomething, isLoading })
  }
})
```

## Rules From AGENTS.md

- Do NOT write change detector tests
- Do NOT write tests that just test the mocks
- Do NOT mock what you don't own
- Do NOT use global mutable state in test files
- Use `vi.hoisted()` for per-test mock manipulation
- Use behavioral coverage, not line coverage
- Keep module mocks contained
- Prefer `.toHaveLength()` over `.length.toBe()`
- Use `.toMatchObject()` for partial matching

## Example: TDD for Search Ranking

Christian's recommended approach for the search ranking feature:

```
1. RED:  Write test expecting core node ranks above API node at same fuse score
2. Verify test FAILS (proves it tests real behavior)
3. Commit failing test
4. GREEN: Implement the fix (add sourcePriority to ComfyNodeDefImpl)
5. Verify test PASSES
6. Commit fix
```

```typescript
describe('search ranking', () => {
  it('ranks core nodes above API nodes at same match quality', () => {
    const coreNode = new ComfyNodeDefImpl({
      name: 'KSampler',
      python_module: 'nodes',  // core module
      // ...
    })
    const apiNode = new ComfyNodeDefImpl({
      name: 'APIKSampler',
      python_module: 'comfy_api_nodes',  // partner module
      // ...
    })

    const coreScores = coreNode.postProcessSearchScores([1.0])
    const apiScores = apiNode.postProcessSearchScores([1.0])

    // Core node should rank higher (lower tuple = higher rank)
    expect(coreScores[1]).toBeLessThan(apiScores[1])
  })
})
```

## Checklist Per Cycle

```
[ ] Test describes behavior, not implementation
[ ] Test uses public interface only
[ ] Test would survive internal refactor
[ ] Code is minimal for this test
[ ] No speculative features added
[ ] pnpm test:unit passes
```
