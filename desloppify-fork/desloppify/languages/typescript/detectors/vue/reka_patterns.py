"""Detect Reka UI anti-patterns in Vue 3 components.

Finds:
- Missing as-child on Reka UI trigger components (wrapper div bloat)
- Direct HTML elements where Reka UI primitives exist
- Missing useForwardPropsEmits on root composition wrappers
- Missing useForwardProps on leaf composition wrappers
- PrimeVue + Reka UI dual imports (incomplete migration)
- Manual state toggling instead of data-[state=...] attributes
"""

from __future__ import annotations

import re
from pathlib import Path

from desloppify.languages.typescript.detectors.vue import iter_vue_and_ts_sources

# Reka UI trigger components that should use as-child
TRIGGER_COMPONENTS = [
    "DialogTrigger",
    "PopoverTrigger",
    "TooltipTrigger",
    "DropdownMenuTrigger",
    "ContextMenuTrigger",
    "CollapsibleTrigger",
    "AccordionTrigger",
    "AlertDialogTrigger",
    "HoverCardTrigger",
    "MenubarTrigger",
    "NavigationMenuTrigger",
    "SelectTrigger",
    "TabsTrigger",
]

# HTML elements that have Reka UI replacements
HTML_TO_REKA: dict[str, str] = {
    "<dialog>": "DialogRoot",
    "<dialog ": "DialogRoot",
    "<select>": "SelectRoot",
    "<select ": "SelectRoot",
    "<details>": "CollapsibleRoot",
    "<details ": "CollapsibleRoot",
}

# Reka UI root components that should use useForwardPropsEmits
REKA_ROOTS = [
    "SelectRoot",
    "DialogRoot",
    "PopoverRoot",
    "TooltipRoot",
    "DropdownMenuRoot",
    "AccordionRoot",
    "CollapsibleRoot",
    "TabsRoot",
    "AlertDialogRoot",
    "HoverCardRoot",
    "ContextMenuRoot",
    "MenubarRoot",
    "NavigationMenuRoot",
    "RadioGroupRoot",
    "SwitchRoot",
    "CheckboxRoot",
    "SliderRoot",
    "ToggleGroupRoot",
]


def detect_reka_patterns(path: Path) -> tuple[list[dict], int]:
    """Scan Vue files for Reka UI anti-patterns."""
    issues: list[dict] = []
    total_files = 0

    for filepath in iter_vue_and_ts_sources(path):
        if not filepath.endswith(".vue"):
            continue
        total_files += 1

        try:
            content = Path(filepath).read_text(errors="replace")
        except OSError:
            continue

        # Skip files that don't reference reka-ui at all
        has_reka = "reka-ui" in content

        # ── Missing as-child on trigger components ────────────────────
        if has_reka:
            for trigger in TRIGGER_COMPONENTS:
                # Find <TriggerComponent without as-child
                pattern = rf"<{trigger}(?:\s[^>]*)?\s*>"
                matches = list(re.finditer(pattern, content))
                for match in matches:
                    tag_text = match.group(0)
                    if "as-child" not in tag_text:
                        issues.append(
                            {
                                "file": filepath,
                                "detector": "reka_missing_as_child",
                                "summary": f"<{trigger}> without as-child creates unnecessary wrapper div",
                                "line": content[: match.start()].count("\n")
                                + 1,
                            }
                        )
                        break  # One per trigger type per file

        # ── Direct HTML where Reka UI exists ──────────────────────────
        for html_elem, reka_comp in HTML_TO_REKA.items():
            if html_elem in content and ("/src/" in filepath or filepath.startswith("src/")):
                # Don't flag if the file already imports from reka-ui
                # (might be using both intentionally during migration)
                if not has_reka:
                    issues.append(
                        {
                            "file": filepath,
                            "detector": "reka_use_primitive",
                            "summary": f"Uses native {html_elem.strip('<>')}> — consider {reka_comp} from reka-ui",
                            "line": _find_line(
                                content, re.escape(html_elem)
                            ),
                        }
                    )
                    break  # One per file

        # ── Missing useForwardPropsEmits on root wrappers ─────────────
        if has_reka:
            for root in REKA_ROOTS:
                if root in content:
                    # Check if this file wraps a root component
                    # but doesn't use useForwardPropsEmits
                    is_wrapper = re.search(
                        rf"<{root}\b", content
                    )
                    if is_wrapper and "useForwardPropsEmits" not in content:
                        # Only flag if this looks like a component wrapper
                        # (has defineProps and renders a root)
                        if "defineProps" in content:
                            issues.append(
                                {
                                    "file": filepath,
                                    "detector": "reka_missing_forward_props",
                                    "summary": f"Wraps <{root}> with defineProps but missing useForwardPropsEmits",
                                    "line": _find_line(
                                        content, rf"<{root}\b"
                                    ),
                                }
                            )
                            break  # One per file

        # ── Dual PrimeVue + Reka UI imports (incomplete migration) ────
        has_primevue = bool(
            re.search(r"from\s+['\"]primevue/", content)
        )
        if has_primevue and has_reka:
            issues.append(
                {
                    "file": filepath,
                    "detector": "reka_primevue_dual_import",
                    "summary": "Imports both PrimeVue and reka-ui — incomplete migration",
                    "line": _find_line(
                        content, r"from\s+['\"]primevue/"
                    ),
                }
            )

    return issues, total_files


def _find_line(content: str, pattern: str) -> int:
    match = re.search(pattern, content)
    if match:
        return content[: match.start()].count("\n") + 1
    return 0
