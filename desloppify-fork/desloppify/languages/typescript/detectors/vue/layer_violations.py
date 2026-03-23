"""Detect ComfyUI layered architecture violations.

Architecture layers (imports must flow downward only):
  base -> platform -> workbench -> renderer

A file in 'base' must NOT import from 'platform', 'workbench', or 'renderer'.
A file in 'platform' must NOT import from 'workbench' or 'renderer'.
A file in 'workbench' must NOT import from 'renderer'.
"""

from __future__ import annotations

import re
from pathlib import Path

from desloppify.languages.typescript.detectors.vue import iter_vue_and_ts_sources

# Layer hierarchy — lower index = deeper layer
LAYERS = ["base", "platform", "workbench", "renderer"]
LAYER_INDEX = {layer: i for i, layer in enumerate(LAYERS)}


def detect_layer_violations(path: Path) -> tuple[list[dict], int]:
    """Scan for imports that violate the layered architecture."""
    issues: list[dict] = []
    total_files = 0

    for filepath in iter_vue_and_ts_sources(path):
        total_files += 1

        source_layer = _get_layer(filepath)
        if source_layer is None:
            continue

        try:
            content = Path(filepath).read_text(errors="replace")
        except OSError:
            continue

        # Find all import statements
        for match in re.finditer(
            r"import\s+(?:type\s+)?(?:\{[^}]*\}|[^;]*)\s+from\s+['\"]([^'\"]+)['\"]",
            content,
        ):
            import_path = match.group(1)
            target_layer = _get_layer_from_import(import_path)

            if target_layer is None:
                continue

            source_idx = LAYER_INDEX[source_layer]
            target_idx = LAYER_INDEX[target_layer]

            # Violation: importing from a higher layer
            if target_idx > source_idx:
                issues.append(
                    {
                        "file": filepath,
                        "detector": "layer_violation",
                        "summary": f"Layer violation: {source_layer} imports from {target_layer} ({import_path})",
                        "line": content[: match.start()].count("\n") + 1,
                        "detail": {
                            "source_layer": source_layer,
                            "target_layer": target_layer,
                            "import_path": import_path,
                        },
                        "severity": "critical",
                        "agents_md_ref": "Architecture > Never violate layer imports",
                    }
                )

    return issues, total_files


def _get_layer(filepath: str) -> str | None:
    """Determine which architectural layer a file belongs to."""
    for layer in LAYERS:
        if f"/{layer}/" in filepath or f"\\{layer}\\" in filepath:
            return layer
    return None


def _get_layer_from_import(import_path: str) -> str | None:
    """Determine which layer an import path references."""
    # Handle @/ alias imports
    normalized = import_path.replace("@/", "src/")
    for layer in LAYERS:
        if f"/{layer}/" in normalized or normalized.startswith(f"{layer}/"):
            return layer
    return None
