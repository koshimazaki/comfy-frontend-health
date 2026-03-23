---
name: shadcn-vue-reka
description: >
  shadcn-vue + Reka UI component patterns for ComfyUI frontend.
  Use when creating, modifying, or composing UI components, working with
  Reka UI primitives, adding shadcn-vue components, styling with CVA variants,
  or building accessible interactive widgets. Triggers on: component, ui,
  reka, shadcn, select, slider, toggle, popover, tooltip, dialog, button variant.
---

# shadcn-vue + Reka UI Component System

## Project Setup

- **UI library:** shadcn-vue (new-york style)
- **Primitives:** Reka UI (formerly Radix Vue)
- **Styling:** Tailwind 4 with CSS variables, CVA for variants
- **Config:** `components.json` at project root
- **Package manager:** `pnpm` (use `pnpm dlx shadcn-vue@latest`, never `npx`)
- **Icons:** lucide-vue-next

## Adding Components

```bash
pnpm dlx shadcn-vue@latest add <component>
```

Components are added as source code to `src/components/ui/`. They are owned by us and can be modified freely.

## Existing Components

### Reka UI-backed (`src/components/ui/`)

| Component | Reka UI Primitives | Variants |
|-----------|-------------------|----------|
| **Button** | `Primitive` | 9 variants, 6 sizes (CVA) |
| **ButtonGroup** | `Primitive`, `useForwardProps` | - |
| **Select** | `SelectRoot/Trigger/Content/Item/Value` | sizes: lg, md |
| **Slider** | `SliderRoot/Track/Range/Thumb` | orientation |
| **ToggleGroup** | `ToggleGroupRoot/Item` | 2 variants, 3 sizes (CVA) |
| **TagsInput** | `TagsInputRoot/Input/Item/ItemText/ItemDelete` | edit mode |
| **SearchInput** | `ComboboxRoot/Anchor/Input` | 4 sizes (CVA) |
| **Tooltip** | `TooltipProvider/Root/Trigger/Content/Portal/Arrow` | side |
| **Popover** | `PopoverRoot/Trigger/Content/Portal/Arrow` | - |
| **ColorPicker** | `PopoverRoot` + custom HSVA | - |
| **TreeExplorerV2** | `TreeRoot/TreeItem`, `ContextMenu*` | virtualized |
| **GradientSlider** | `SliderRoot/Track/Thumb` | gradient bg |

### Native (`src/components/ui/`)

| Component | Purpose |
|-----------|---------|
| **Input** | Text input with v-model, focus/select expose |
| **Textarea** | Auto-height textarea |
| **Skeleton** | Loading placeholder |
| **FormattedNumberStepper** | +/- number input |

## Architecture Patterns

### 1. Root + Subcomponent Composition

Split components into composable parts. Each part is its own SFC:

```
select/
  Select.vue           # Root wrapper (useForwardPropsEmits)
  SelectTrigger.vue     # Trigger button
  SelectContent.vue     # Dropdown (with Portal)
  SelectItem.vue        # Individual option
  SelectValue.vue       # Display selected value
```

### 2. CVA Variants

Define type-safe variants in a separate `.variants.ts` file:

```typescript
// button/button.variants.ts
import { cva, type VariantProps } from 'cva'

export const buttonVariants = cva({
  base: 'inline-flex items-center justify-center rounded ...',
  variants: {
    variant: {
      primary: 'bg-primary-background text-primary-foreground ...',
      secondary: 'bg-secondary-background text-secondary-foreground ...',
      destructive: 'bg-destructive-background ...',
    },
    size: {
      sm: 'h-7 px-2 text-xs',
      md: 'h-8 px-3 text-sm',
      lg: 'h-9 px-4',
    }
  },
  defaultVariants: { variant: 'secondary', size: 'md' }
})

export type ButtonVariants = VariantProps<typeof buttonVariants>
```

Use in component:

```vue
<script setup lang="ts">
import { buttonVariants, type ButtonVariants } from './button.variants'
import { cn } from '@/utils/tailwindUtil'

const { variant = 'secondary', size = 'md' } = defineProps<{
  variant?: ButtonVariants['variant']
  size?: ButtonVariants['size']
}>()
</script>

<template>
  <Primitive :class="cn(buttonVariants({ variant, size }), $attrs.class)">
    <slot />
  </Primitive>
</template>
```

### 3. Reka UI Props Forwarding

**Root components** — use `useForwardPropsEmits`:

```vue
<script setup lang="ts">
import { SelectRoot, useForwardPropsEmits } from 'reka-ui'

const props = defineProps<SelectRootProps>()
const emits = defineEmits<SelectRootEmits>()
const forwarded = useForwardPropsEmits(props, emits)
</script>

<template>
  <SelectRoot v-bind="forwarded">
    <slot />
  </SelectRoot>
</template>
```

**Leaf components** — use `useForwardProps`:

```vue
<script setup lang="ts">
import { SelectItem, useForwardProps } from 'reka-ui'

const props = defineProps<SelectItemProps>()
const forwardedProps = useForwardProps(props)
</script>

<template>
  <SelectItem v-bind="forwardedProps">
    <slot />
  </SelectItem>
</template>
```

### 4. Context Injection

Pass variant context from parent to children:

```typescript
// Parent (ToggleGroup.vue)
import { provide, toRef } from 'vue'
const toggleGroupVariantKey = Symbol() as InjectionKey<Ref<string>>
provide(toggleGroupVariantKey, toRef(() => variant))

// Child (ToggleGroupItem.vue)
import { inject, ref } from 'vue'
const contextVariant = inject(toggleGroupVariantKey, ref('default'))
```

### 5. asChild Pattern

Render Reka UI primitives as their child element (no wrapper div):

```vue
<PopoverTrigger as-child>
  <Button variant="secondary">Open</Button>
</PopoverTrigger>
```

### 6. Data Attribute Styling

Style Reka UI states via Tailwind data attributes:

```
data-[state=checked]:bg-primary-background
data-[state=open]:rotate-180
data-[disabled]:opacity-50
data-[highlighted]:bg-secondary-background-hover
data-[side=top]:slide-in-from-bottom
data-[placeholder]:text-muted-foreground
```

## Class Merging

Always use `cn()` from `@/utils/tailwindUtil`:

```vue
<div :class="cn('base-class', condition && 'conditional-class')" />
```

Never use `:class="[]"` array syntax. Use `cn()` inline in templates when feasible.

## Semantic Colors

Use project theme tokens, never raw Tailwind colors:

```
bg-base-background          (not bg-white / bg-gray-900)
text-base-foreground         (not text-black)
bg-primary-background        (not bg-blue-500)
bg-secondary-background      (not bg-gray-100)
bg-destructive-background    (not bg-red-500)
border-default               (not border-gray-200)
text-muted-foreground        (not text-gray-500)
```

Never use the `dark:` Tailwind variant. Semantic tokens handle both themes.

## Creating a New Component

1. Check if shadcn-vue has it: `pnpm dlx shadcn-vue@latest add <name>`
2. If not, create in `src/components/ui/<name>/`
3. Use Reka UI primitives for accessibility (keyboard nav, ARIA, focus management)
4. Define variants in `<name>.variants.ts` if needed
5. Use `cn()` for class merging
6. Use semantic color tokens
7. Add a Storybook story in `<name>/<Name>.stories.ts`
8. Forward props/emits with Reka UI composables

## File Structure Convention

```
src/components/ui/<component>/
  <Component>.vue              # Main component
  <Component>Sub.vue           # Subcomponents (if compositional)
  <component>.variants.ts      # CVA variants (if needed)
  <Component>.stories.ts       # Storybook story
  <component>Context.ts        # Injection keys (if needed)
```

## Rules

- **Never use PrimeVue** for new components (AGENTS.md)
- **Never use `!important`** or `!` prefix for Tailwind classes
- **Never use `npx`** — use `pnpm dlx` or `pnpx`
- **Never use `dark:` variant** — use semantic theme tokens
- **Never use `:class="[]"`** — use `cn()` from `@/utils/tailwindUtil`
- Use `as-child` on Reka UI triggers to avoid wrapper divs
- Use `useForwardPropsEmits` for root wrappers, `useForwardProps` for leaves
- Prefer `defineModel` over separate prop + emit for v-model bindings
- Use Vue 3.5 props destructuring with defaults
- Flag components with >14 props — likely needs decomposition or composition pattern
- Never use native `<dialog>`, `<select>`, `<details>` — use Reka UI primitives
- Never import both PrimeVue and reka-ui in the same component (incomplete migration)

## References

- [shadcn-vue docs](https://www.shadcn-vue.com/)
- [Reka UI docs](https://reka-ui.com/)
- [CVA docs](https://cva.style/)
- [Tailwind 4](https://tailwindcss.com/docs/styling-with-utility-classes)
