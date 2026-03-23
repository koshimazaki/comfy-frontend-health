"""Vue 3 / ComfyUI conventions phase runner."""

from __future__ import annotations

from pathlib import Path

from desloppify.base.output.terminal import log
from desloppify.engine._state.filtering import make_issue
from desloppify.engine.policy.zones import adjust_potential
from desloppify.languages._framework.base.types import LangRuntimeContract
from desloppify.languages.typescript.detectors.vue.composition_api import (
    detect_composition_api,
)
from desloppify.languages.typescript.detectors.vue.components import (
    detect_component_violations,
)
from desloppify.languages.typescript.detectors.vue.layer_violations import (
    detect_layer_violations,
)
from desloppify.languages.typescript.detectors.vue.styling import (
    detect_styling_violations,
)
from desloppify.languages.typescript.detectors.vue.conventions import (
    detect_conventions,
)
from desloppify.languages.typescript.detectors.vue.reka_patterns import (
    detect_reka_patterns,
)
from desloppify.state_io import Issue


# Detector name -> (tier, confidence) mapping
_DETECTOR_CONFIG: dict[str, tuple[int, str]] = {
    # Composition API violations — explicit AGENTS.md rules
    "vue_options_api": (3, "high"),
    "vue_with_defaults": (2, "high"),
    "vue_runtime_props": (2, "high"),
    "vue_define_slots": (2, "medium"),
    "vue_missing_define_model": (2, "medium"),
    # Styling violations — explicit "NEVER" rules
    "tailwind_class_array": (2, "high"),
    "tailwind_dark_variant": (2, "high"),
    "tailwind_important": (2, "high"),
    "tailwind_arbitrary_pct": (2, "medium"),
    "vue_style_block": (3, "medium"),
    # Component violations — explicit AGENTS.md rules
    "primevue_import": (3, "high"),
    "ts_as_any": (2, "high"),
    "ts_any_type": (2, "high"),
    "mixed_import_type": (2, "medium"),
    "direct_fetch": (3, "medium"),
    "barrel_file": (3, "medium"),
    # Layer violations — architectural rule
    "layer_violation": (2, "high"),
    # Convention violations
    "ts_suppress_error": (3, "high"),
    "zod_any": (2, "high"),
    "playwright_wait_timeout": (2, "high"),
    "vue_script_no_setup": (3, "high"),
    "composable_naming": (2, "medium"),
    "store_naming": (2, "medium"),
    "function_expression": (3, "low"),
    # Reka UI patterns
    "reka_missing_as_child": (3, "medium"),
    "reka_use_primitive": (3, "low"),
    "reka_missing_forward_props": (3, "medium"),
    "reka_primevue_dual_import": (3, "high"),
    "cva_inline_in_component": (3, "medium"),
    "missing_story": (3, "low"),
    "reka_manual_state_toggle": (3, "medium"),
    # Styling — design system
    "tailwind_raw_color": (2, "high"),
    "hardcoded_color_value": (2, "high"),
}


def phase_vue(
    path: Path, lang: LangRuntimeContract
) -> tuple[list[Issue], dict[str, int]]:
    """Run all Vue 3 / ComfyUI convention detectors."""
    results: list[Issue] = []
    total_vue_files = 0

    # ── Composition API ────────────────────────────────────────────────
    composition_entries, vue_files = detect_composition_api(path)
    total_vue_files = max(total_vue_files, vue_files)
    for entry in composition_entries:
        detector = entry["detector"]
        tier, confidence = _DETECTOR_CONFIG.get(detector, (3, "medium"))
        results.append(
            make_issue(
                "vue",
                entry["file"],
                f"{detector}::{entry.get('line', 0)}",
                tier=tier,
                confidence=confidence,
                summary=entry["summary"],
                detail={"line": entry.get("line", 0)},
            )
        )
    if composition_entries:
        log(f"         vue: {len(composition_entries)} composition API violations")

    # ── Styling ────────────────────────────────────────────────────────
    styling_entries, styling_files = detect_styling_violations(path)
    total_vue_files = max(total_vue_files, styling_files)
    for entry in styling_entries:
        detector = entry["detector"]
        tier, confidence = _DETECTOR_CONFIG.get(detector, (3, "medium"))
        results.append(
            make_issue(
                "vue",
                entry["file"],
                f"{detector}::{entry.get('line', 0)}",
                tier=tier,
                confidence=confidence,
                summary=entry["summary"],
                detail={"line": entry.get("line", 0)},
            )
        )
    if styling_entries:
        log(f"         vue: {len(styling_entries)} styling violations")

    # ── Components ─────────────────────────────────────────────────────
    component_entries, comp_files = detect_component_violations(path)
    total_vue_files = max(total_vue_files, comp_files)
    for entry in component_entries:
        detector = entry["detector"]
        tier, confidence = _DETECTOR_CONFIG.get(detector, (3, "medium"))
        detail: dict = {"line": entry.get("line", 0)}
        if "count" in entry:
            detail["count"] = entry["count"]
        results.append(
            make_issue(
                "vue",
                entry["file"],
                f"{detector}::{entry.get('line', 0)}",
                tier=tier,
                confidence=confidence,
                summary=entry["summary"],
                detail=detail,
            )
        )
    if component_entries:
        log(f"         vue: {len(component_entries)} component violations")

    # ── Layer violations ───────────────────────────────────────────────
    layer_entries, layer_files = detect_layer_violations(path)
    total_vue_files = max(total_vue_files, layer_files)
    for entry in layer_entries:
        detector = entry["detector"]
        tier, confidence = _DETECTOR_CONFIG.get(detector, (3, "medium"))
        results.append(
            make_issue(
                "vue",
                entry["file"],
                f"{detector}::{entry.get('line', 0)}",
                tier=tier,
                confidence=confidence,
                summary=entry["summary"],
                detail=entry.get("detail", {"line": entry.get("line", 0)}),
            )
        )
    if layer_entries:
        log(f"         vue: {len(layer_entries)} layer violations")

    # ── Conventions ────────────────────────────────────────────────────
    convention_entries, conv_files = detect_conventions(path)
    total_vue_files = max(total_vue_files, conv_files)
    for entry in convention_entries:
        detector = entry["detector"]
        tier, confidence = _DETECTOR_CONFIG.get(detector, (3, "medium"))
        detail_conv: dict = {"line": entry.get("line", 0)}
        if "count" in entry:
            detail_conv["count"] = entry["count"]
        results.append(
            make_issue(
                "vue",
                entry["file"],
                f"{detector}::{entry.get('line', 0)}",
                tier=tier,
                confidence=confidence,
                summary=entry["summary"],
                detail=detail_conv,
            )
        )
    if convention_entries:
        log(f"         vue: {len(convention_entries)} convention violations")

    # ── Reka UI patterns ──────────────────────────────────────────────
    reka_entries, reka_files = detect_reka_patterns(path)
    total_vue_files = max(total_vue_files, reka_files)
    for entry in reka_entries:
        detector = entry["detector"]
        tier, confidence = _DETECTOR_CONFIG.get(detector, (3, "medium"))
        results.append(
            make_issue(
                "vue",
                entry["file"],
                f"{detector}::{entry.get('line', 0)}",
                tier=tier,
                confidence=confidence,
                summary=entry["summary"],
                detail={"line": entry.get("line", 0)},
            )
        )
    if reka_entries:
        log(f"         vue: {len(reka_entries)} Reka UI pattern issues")

    return results, {
        "vue": adjust_potential(lang.zone_map, total_vue_files),
    }


__all__ = ["phase_vue"]
