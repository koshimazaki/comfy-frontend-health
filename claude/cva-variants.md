---
globs:
  - '**/*.variants.ts'
---

# CVA Variant File Conventions

Applies to all `*.variants.ts` files — the CVA (Class Variance Authority) variant definitions for shadcn-vue components.

## Structure

```typescript
import { cva, type VariantProps } from 'cva'

export const componentVariants = cva({
  base: 'inline-flex items-center ...',
  variants: {
    variant: {
      primary: 'bg-primary-background text-primary-foreground',
      secondary: 'bg-secondary-background text-secondary-foreground',
      destructive: 'bg-destructive-background text-destructive-foreground',
    },
    size: {
      sm: 'h-7 px-2 text-xs',
      md: 'h-8 px-3 text-sm',
      lg: 'h-9 px-4',
    }
  },
  defaultVariants: { variant: 'secondary', size: 'md' }
})

export type ComponentVariants = VariantProps<typeof componentVariants>
```

## Rules

- Use **semantic tokens** in variant values — never raw Tailwind colors (`bg-blue-500`)
- Never use `dark:` variant — tokens handle theming
- Never use `!important` or `!` prefix
- Export `VariantProps<typeof ...>` type for use in the component's defineProps
- File must be colocated with its component: `component/component.variants.ts`
- Use `cn()` from `@/utils/tailwindUtil` when applying variants in the component template

## Review Checklist

When reviewing variant files, verify:
- All color values use semantic tokens (not `bg-red-500`, use `bg-destructive-background`)
- Variant names are descriptive and consistent with existing components
- Default variants are specified
- No hardcoded px/rem values when Tailwind scale exists
- Spacing follows design system scale (gap-1 to gap-2 tight, gap-3 to gap-4 sections)
