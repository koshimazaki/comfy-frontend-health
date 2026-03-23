---
name: design-system
description: >
  Comfy design system for designers and developers. Covers color palette, semantic
  tokens, component inventory, layout patterns, and how to apply product design
  principles to real UI work. Use when designing new features, choosing components,
  picking colors/spacing, reviewing UI consistency, or onboarding to the visual system.
  Triggers on: design system, color, token, palette, spacing, layout, typography,
  visual consistency, theme, dark mode, component inventory.
---

# Comfy Design System

For the full product design philosophy, see `docs/guidance/product-design.md`.

This skill maps those principles to concrete design decisions using the actual component library and theme tokens.

## Design Decisions Flowchart

When designing a new feature:

```
1. Does a component for this already exist?
   YES -> Use it. Check src/components/ui/ inventory below.
   NO  -> Can you compose it from existing components?
          YES -> Compose. Don't reinvent.
          NO  -> Build with Reka UI primitives + semantic tokens.

2. How much should be visible?
   -> Apply progressive disclosure (see Cognitive Load principle)
   -> Primary actions: always visible, labeled buttons
   -> Secondary actions: context menu, hover, or "Advanced" toggle
   -> Tertiary actions: settings panel or dialog

3. Does the user know what just happened?
   -> Every action needs feedback (toast, state change, loading indicator)
   -> Empty states need guidance (not blank screens)
```

## Color System

### Brand Colors

| Token | Hex | Use |
|-------|-----|-----|
| `brand-yellow` (electric-400) | `#f0ff41` | Brand accent, highlights |
| `brand-blue` (sapphire-700) | `#172dd7` | Brand accent, links |

### Palette Families

**Charcoal** (dark backgrounds): 100-800, `#55565e` to `#171718`
**Smoke** (light backgrounds): 100-800, `#f3f3f3` to `#8a8a8a`
**Ivory** (warm whites): 100-300, `#fdfbfa` to `#f0eee6`
**Ash** (neutral grays): 300-800, `#bbbbbb` to `#444444`

**Accent colors:**

| Family | Range | Key Values | Use |
|--------|-------|-----------|-----|
| Azure | 300-600 | `#78bae9` to `#0b8ce9` | Selection, focus, progress |
| Jade | 400-600 | `#47e469` to `#00cd72` | Success, positive states |
| Coral | 500-700 | `#f75951` to `#b33a3a` | Errors, destructive |
| Gold | 400-600 | `#fcbf64` to `#fd9903` | Warnings, highlights |
| Magenta | 300-700 | `#ceaac9` to `#6a246a` | Bypass, special states |
| Ocean | 300-900 | `#badde8` to `#253236` | Informational |

### Semantic Tokens (always use these, never raw colors)

**Surfaces:**
- `base-background` / `base-foreground` — main content area
- `secondary-background` / `secondary-background-hover` / `secondary-background-selected`
- `primary-background` / `primary-background-hover`
- `destructive-background` / `destructive-background-hover`

**Text:**
- `text-primary` / `text-secondary`
- `muted-foreground`

**Borders:**
- `border-default` / `border-subtle`

**Component-specific (examples):**
- `node-*` — node editor elements
- `modal-*` — dialog/modal surfaces
- `interface-menu-*` — sidebar and menu surfaces
- `interface-panel-*` — right side panel

### Dark Mode

The app uses CSS custom properties that swap between light/dark themes. **Never use `dark:` Tailwind variant.** Semantic tokens handle both modes automatically.

## Typography

- **Font:** Inter (variable weight)
- **Sizes:** Standard Tailwind scale + custom `text-xxs` (0.625rem) and `text-xxxs` (0.5625rem)
- Use Tailwind text utilities: `text-xs`, `text-sm`, `text-base`, etc.

## Component Inventory

### Interactive Controls

| Need | Component | Location |
|------|-----------|----------|
| Action trigger | **Button** (9 variants, 6 sizes) | `ui/button/` |
| Grouped actions | **ButtonGroup** | `ui/button-group/` |
| Option selection | **Select** (full: Root/Trigger/Content/Item) | `ui/select/` |
| Range value | **Slider** (horizontal/vertical) | `ui/slider/` |
| Toggle options | **ToggleGroup** (2 variants, 3 sizes) | `ui/toggle-group/` |
| Multi-value input | **TagsInput** (with edit mode) | `ui/tags-input/` |
| Search with autocomplete | **SearchInput** (4 sizes, debounce) | `ui/search-input/` |
| Text input | **Input** (native, v-model) | `ui/input/` |
| Multi-line text | **Textarea** (auto-height) | `ui/textarea/` |
| Numeric stepper | **FormattedNumberStepper** (+/- buttons) | `ui/stepper/` |
| Color selection | **ColorPicker** (HSVA, popover) | `ui/color-picker/` |
| Gradient value | **GradientSlider** | `common/gradientslider/` |

### Feedback & Overlays

| Need | Component | Location |
|------|-----------|----------|
| Hover info | **Tooltip** (configurable side, delay) | `ui/tooltip/` |
| Contextual content | **Popover** (portal, arrow) | `ui/Popover.vue` |
| Loading placeholder | **Skeleton** | `ui/skeleton/` |

### Layout & Navigation

| Need | Component | Location |
|------|-----------|----------|
| Hierarchical data | **TreeExplorerV2** (virtualized, context menu) | `common/TreeExplorerV2.vue` |
| Context actions | **DropdownMenu** (via Reka UI) | various |
| Data visualization | **ChartLine / ChartBar** | `ui/chart/` |
| Zoom/pan container | **ZoomPane** | `ui/ZoomPane.vue` |

### Variant System (CVA)

Components with multiple visual styles use CVA (Class Variance Authority):

```
Button:       9 variants (primary, secondary, destructive, textonly, ...) x 6 sizes
ToggleGroup:  2 group variants x 2 item variants x 3 sizes
SearchInput:  4 sizes with icon/padding configs
```

Variants are defined in `*.variants.ts` files next to the component.

## Layout Patterns

### Progressive Disclosure

```
Level 1: Always visible (main toolbar, primary actions)
Level 2: On interaction (context menus, hover toolbars, selected-element actions)
Level 3: On demand (dialogs, settings panels, "Advanced" toggles)
```

### Spacing

Use Tailwind spacing scale consistently:
- **Tight grouping** (related items): `gap-1` to `gap-2`
- **Section spacing**: `gap-3` to `gap-4`
- **Panel padding**: `p-3` to `p-4`
- **Page-level spacing**: `gap-6` to `gap-8`

### Common Layouts

**Sidebar + Content:**
```
flex h-full
  aside (fixed width, overflow-y-auto)
  main (flex-1, overflow handling)
```

**Stacked Panel:**
```
flex flex-col gap-3 p-3
  header (flex items-center justify-between)
  content (flex-1 overflow-y-auto)
  footer (flex gap-2)
```

**Toolbar:**
```
flex items-center gap-1 h-8 px-2
  ButtonGroup / individual Buttons
```

## Applying Design Principles

### Clarity Over Aesthetics
- Use Button with label, not icon-only (unless space-constrained)
- Pair icons with text: `<Button><Icon /> Label</Button>`
- Use Tooltip for icon-only buttons

### Cognitive Load
- Show context-specific actions only when relevant
- Use SearchInput for large lists instead of showing everything
- Group related controls in panels/sections

### Flow State
- Use Skeleton during loading, never blank areas
- Show toasts for completed actions
- Use progress indicators for long operations
- Provide undo where possible

### Consistency
- Pick from existing components before creating new ones
- Match spacing/sizing with adjacent UI areas
- Use same variant for similar action types across the app

## What NOT to Do

- Never use raw color values (`#ff0000`) — use semantic tokens
- Never use `dark:` variant — tokens handle themes
- Never use PrimeVue for new components
- Never use `!important` or `!` prefix
- Never use `:class="[]"` — use `cn()` for class merging
- Never create one-off styled divs when a component exists
- Never build a custom select/dropdown — use the Select component
- Never use `<style>` blocks in Vue SFCs — use inline Tailwind only (exception: `:deep()` for third-party DOM)
- Never use native `<dialog>`, `<select>`, `<details>` — use Reka UI primitives (DialogRoot, SelectRoot, CollapsibleRoot)
