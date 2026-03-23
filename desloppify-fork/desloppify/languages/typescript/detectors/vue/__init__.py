"""Vue 3 / ComfyUI-specific detectors for the TypeScript language plugin."""

from __future__ import annotations

from pathlib import Path

from desloppify.base.discovery.source import find_source_files
from desloppify.languages.typescript.detectors.io import should_skip_typescript_source


def iter_vue_and_ts_sources(path: Path) -> list[str]:
    """Return .vue, .ts, and .tsx source files, excluding standard exclusions."""
    return [
        filepath
        for filepath in find_source_files(path, [".vue", ".ts", ".tsx"])
        if not should_skip_typescript_source(filepath)
    ]


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

__all__ = [
    "detect_composition_api",
    "detect_component_violations",
    "detect_conventions",
    "detect_layer_violations",
    "detect_reka_patterns",
    "detect_styling_violations",
    "iter_vue_and_ts_sources",
]
