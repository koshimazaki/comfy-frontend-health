---
globs:
  - '**/*.test.ts'
---

# Vitest Unit Test Conventions

See `docs/testing/*.md` for detailed patterns.

## Test Quality

- Do not write change detector tests (tests that just assert defaults)
- Do not write tests dependent on non-behavioral features (styles, classes)
- Do not write tests that just test mocks - ensure real code is exercised
- Be parsimonious; avoid redundant tests

## Mocking

- Use Vitest's mocking utilities (`vi.mock`, `vi.spyOn`)
- Keep module mocks contained - no global mutable state
- Use `vi.hoisted()` for per-test mock manipulation
- Don't mock what you don't own

## Component Testing

- Use Vue Test Utils for component tests
- Follow advice about making components easy to test
- Wait for reactivity with `await nextTick()` after state changes

## Coverage Expectations

- Every new composable (`useXyz.ts`) needs a colocated `.test.ts`
- Every new store (`*Store.ts`) needs behavioral tests for public actions/getters
- Components with async data fetching need tests for loading, error, and empty states

## Running Tests

```bash
pnpm test:unit                    # Run all unit tests
pnpm test:unit -- path/to/file    # Run specific test
pnpm test:unit -- --watch         # Watch mode
```
