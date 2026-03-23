"""Shared TypeScript phase configuration values."""

from __future__ import annotations

import re

from desloppify.engine.detectors.base import ComplexitySignal, GodRule


def _compute_ts_destructure_props(content, lines):
    long_destructures = re.findall(r"\{\s*(\w+(?:\s*,\s*\w+){8,})\s*\}", content)
    if not long_destructures:
        return None
    max_props = max(len(d.split(",")) for d in long_destructures)
    return max_props, f"destructure w/{max_props} props"


def _compute_ts_inline_types(content, lines):
    inline_types = len(
        re.findall(r"^(?:export\s+)?(?:type|interface)\s+\w+", content, re.MULTILINE)
    )
    if inline_types > 3:
        return inline_types, f"{inline_types} inline types"
    return None


TS_COMPLEXITY_SIGNALS = [
    ComplexitySignal("imports", r"^import\s", weight=1, threshold=15),
    ComplexitySignal(
        "destructured props",
        None,
        weight=1,
        threshold=8,
        compute=_compute_ts_destructure_props,
    ),
    ComplexitySignal(
        "inline types", None, weight=1, threshold=3, compute=_compute_ts_inline_types
    ),
    ComplexitySignal("TODOs", r"//\s*(?:TODO|FIXME|HACK|XXX)", weight=2, threshold=0),
    ComplexitySignal(
        "nested ternaries", r"[^?]\?[^?.:\n][^:\n]*[^?]\?[^?.]", weight=3, threshold=2
    ),
    # Vue 3 signals (replaces React useEffect/useRef)
    ComplexitySignal(
        "watch calls", r"(?:watch|watchEffect)\s*\(", weight=3, threshold=3
    ),
    ComplexitySignal(
        "composable calls", r"\buse[A-Z]\w+\s*\(", weight=1, threshold=8
    ),
    ComplexitySignal(
        "lifecycle hooks",
        r"\b(?:onMounted|onUnmounted|onBeforeMount|onBeforeUnmount|onUpdated)\s*\(",
        weight=2,
        threshold=4,
    ),
    ComplexitySignal(
        "refs", r"\b(?:ref|shallowRef|toRef)\s*[<(]", weight=1, threshold=8
    ),
]

TS_GOD_RULES = [
    # Vue 3 god-component rules (replaces React hook metrics)
    GodRule(
        "watch_count", "watch/watchEffect calls",
        lambda c: c.metrics.get("watch_count", 0), 5,
    ),
    GodRule(
        "composable_count", "composable (useXyz) calls",
        lambda c: c.metrics.get("composable_count", 0), 10,
    ),
    GodRule(
        "ref_count", "ref declarations",
        lambda c: c.metrics.get("ref_count", 0), 10,
    ),
    GodRule(
        "lifecycle_count", "lifecycle hooks",
        lambda c: c.metrics.get("lifecycle_count", 0), 4,
    ),
    GodRule(
        "prop_count", "defineProps fields",
        lambda c: c.metrics.get("prop_count", 0), 14,
    ),
]

TS_SKIP_NAMES = {
    "index.ts",
    "index.tsx",
    "types.ts",
    "types.tsx",
    "constants.ts",
    "constants.tsx",
    "utils.ts",
    "utils.tsx",
    "helpers.ts",
    "helpers.tsx",
    "settings.ts",
    "settings.tsx",
    "main.ts",
    "main.tsx",
    "App.tsx",
    "vite-env.d.ts",
}

TS_SKIP_DIRS = {"src/shared/components/ui"}


__all__ = [
    "TS_COMPLEXITY_SIGNALS",
    "TS_GOD_RULES",
    "TS_SKIP_DIRS",
    "TS_SKIP_NAMES",
]
