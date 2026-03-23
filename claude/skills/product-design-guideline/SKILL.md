---
name: product-design-guideline
description: >
  Comfy product design principles and UX heuristics. Use when making UI/UX
  decisions, reviewing designs, implementing new features with user-facing UI,
  or when asked about design patterns, layout choices, or interaction design.
  Triggers on: design review, UX decision, UI pattern, user flow, component design.
---

# Comfy Product Design Principles

## Guiding Principle

Spend most of your time on **UX**, not pixel-perfect beautiful UI.

## Who This Is For

**Designers**: Understand design values, make autonomous decisions, know what "good enough" means at each stage.

**Developers**: Gain enough design literacy to unblock on simple UI tasks, know when to ask for input vs wing it.

**Everyone**: Embrace first principles, move fast without breaking user trust.

## Design Principles

### Follow Established Heuristics

We follow [Nielsen's 10 Usability Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/):

1. Visibility of system status
2. Match between system and real world
3. User control and freedom
4. Consistency and standards
5. Error prevention
6. Recognition rather than recall
7. Flexibility and efficiency of use
8. Aesthetic and minimalist design
9. Help users recognize, diagnose, and recover from errors
10. Help and documentation

### Clarity Over Aesthetics

Ship a plain but understandable feature over a beautiful interface that confuses users.

- Buttons should always look like buttons
- Use clear icon + label combos (don't rely on icons alone)
- Don't reinvent interactions (dropdowns, modals, tabs) unless necessary

### Momentum Over Polish

- No need for pixel-perfect implementation of the design
- Design debt is logged and paid off later, not upfront

### Balancing Cognitive Load and Affordance

**Problem**: Many hidden options users can't find, but too many to surface all at once.

**Solution**: Surface the right options at the right time.

**In practice**:

- Favor labeled buttons and visible options over cryptic icons or hidden menus
- Use tooltips, helper text, and hover states to guide without clutter
- Apply **progressive disclosure**: start simple, reveal more when needed
- Use **step-by-step flows** (wizards) for linear tasks with clear intent
- Use **context-specific actions** to reduce clutter:
  - Show actions for selected elements only
  - Float toolbars near the object in focus
  - Right-click/context menus for secondary actions
- Design for intent, not inventory

**Examples**:

- "Create New Project" requires 3 actions -> use a wizard with 3 consecutive steps
- Node-specific actions appear only when a node is selected
- "Advanced Settings" hidden until toggled

### Consistency

Aim for a UI that feels **learnable**:

- Use existing patterns first
- Reuse components and layouts from other parts of the app
- Avoid novelty unless it solves a real UX problem
- If something feels unique, it should still feel familiar

### Aim for the "Flow State"

Users should feel like they're moving fast and making progress. Eliminate friction, dead ends, and ambiguity.

The goal is a loop of **action -> feedback -> reward** that keeps the user engaged.

**To support flow**:

- Keep interactions fast and responsive (no lag, no flicker)
- Give clear visual feedback for every action (saved, loading, error)
- Avoid unclear or empty UI states (use loading skeletons, helpful messages)
- Let users undo destructive actions or preview results when possible
- Avoid blank states by offering smart defaults or example content
- Error messages should guide users, not frustrate them

**Flow killers**:

- Hitting a wall with no hint what to do next
- Submitting a form and seeing nothing happen

**Flow boosters**:

- Tooltip hints on hover
- Progress indicators in long-running tasks
- Shortcuts for power users
- Success messages after completed actions

## Applying These Principles

When reviewing or implementing UI:

1. **Does the user know what to do next?** (Clarity)
2. **Can we ship this without full polish?** (Momentum)
3. **Are we showing too much or too little?** (Cognitive load)
4. **Does this match existing patterns?** (Consistency)
5. **Will this keep the user in flow?** (Flow state)

## ComfyUI-Specific Context

This project serves **creative professionals** building AI workflows. Key considerations:

- Users range from beginners to power users -- support both with progressive disclosure
- Node-based interfaces are inherently complex -- reduce cognitive load wherever possible
- Real-time feedback on workflow execution is critical for flow state
- Consistency across node types, panels, and dialogs builds learnability
- App mode (linear view) should feel simpler than graph mode, not just different
