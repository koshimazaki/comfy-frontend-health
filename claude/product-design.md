# Product Design Principles

## Goals

**For Designers:** Understand design values, make autonomous decisions, know what "good enough" means at each stage, align with Comfy's style and intent.

**For Developers:** Gain design literacy to unblock on simple UI tasks, know when to ask vs when to proceed, collaborate without dependency.

**For Everyone:** Embrace first principles over pixel-pushing, move fast without breaking user trust.

## Principles

> Guiding rule: Spend most time on UX, not pixel-perfect beautiful UI.

### Follow Proven Heuristics

We follow Nielsen's [10 Usability Heuristics](https://www.nngroup.com/articles/ten-usability-heuristics/).

### Clarity Over Aesthetics

Ship plain but understandable over beautiful but confusing.

- Buttons should always look like buttons
- Use clear icon + label combos (don't rely on icons alone)
- Don't reinvent standard interactions (dropdowns, modals, tabs) unless necessary

### Momentum Over Polish

Ship fast and often:

- No need for pixel-perfect implementation of designs
- Design debt is logged and paid off later, not upfront

### Balancing Cognitive Load and Affordance

Problem: Many hidden options users can't find, but too many to surface all at once.

Solution: Surface the **right options at the right time**.

- Favor **labeled buttons and visible options** over cryptic icons or hidden menus
- Use **tooltips**, helper text, and hover states to guide without clutter
- Apply **progressive disclosure**: start simple, reveal more when needed
- Use **step-by-step flows** (wizards) for linear tasks with clear intent (e.g. onboarding)
- Use **context-specific actions** to reduce clutter:
  - Show actions for selected elements
  - Float toolbars near the object in focus
  - Right-click/context menus for secondary actions
- Design for intent, not inventory

### Consistency

Aim for a UI that feels **learnable**:

- Use existing patterns first
- Reuse components and layouts from other parts of the app
- Avoid novelty unless it solves a real UX problem

If something feels unique, it should still feel familiar.

### Aim for the "Flow State"

Users should feel like they're moving fast and making progress. Eliminate friction, dead ends, and ambiguity.

> The goal is a loop of "action -> feedback -> reward" that keeps the user engaged.

**To support flow:**

- Keep interactions fast and responsive (no lag, no flicker)
- Give **clear visual feedback** for every action (saved, loading, error)
- Avoid unclear or empty UI states (use loading skeletons, helpful messages)
- Let users undo destructive actions or preview results when possible
- Avoid blank states by offering smart defaults or example content
- Error messages should guide users, not frustrate them

**Flow killers:** Hitting a wall with no hint what to do next. Submitting a form and seeing nothing happen.

**Flow boosters:** Tooltip hints on hover. Progress indicators in long-running tasks. Shortcuts for power users.
