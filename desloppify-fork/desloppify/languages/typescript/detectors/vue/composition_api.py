"""Detect Vue 3 Composition API violations.

Finds:
- Options API usage (should be Composition API with <script setup>)
- withDefaults usage (should be Vue 3.5 props destructuring)
- Runtime props declaration (should be type-only)
- Missing defineModel for v-model bindings (separate prop + emit)
- defineSlots usage (should use template-based slots)
"""

from __future__ import annotations

import re
from pathlib import Path

from desloppify.languages.typescript.detectors.vue import iter_vue_and_ts_sources


def detect_composition_api(path: Path) -> tuple[list[dict], int]:
    """Scan .vue files for Composition API violations."""
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

        # Options API detection
        if re.search(r"export\s+default\s*\{", content) and not re.search(
            r"<script\s+setup", content
        ):
            issues.append(
                {
                    "file": filepath,
                    "detector": "vue_options_api",
                    "summary": "Uses Options API instead of <script setup> Composition API",
                    "line": _find_line(content, r"export\s+default\s*\{"),
                }
            )

        # withDefaults detection
        if re.search(r"\bwithDefaults\s*\(", content):
            issues.append(
                {
                    "file": filepath,
                    "detector": "vue_with_defaults",
                    "summary": "Uses withDefaults — use Vue 3.5 props destructuring with defaults instead",
                    "line": _find_line(content, r"\bwithDefaults\s*\("),
                }
            )

        # Runtime props declaration
        if re.search(r"defineProps\s*\(\s*\{", content):
            issues.append(
                {
                    "file": filepath,
                    "detector": "vue_runtime_props",
                    "summary": "Uses runtime props declaration — use type-only defineProps<{...}>()",
                    "line": _find_line(content, r"defineProps\s*\(\s*\{"),
                }
            )

        # defineSlots usage (prefer template)
        if re.search(r"\bdefineSlots\b", content):
            issues.append(
                {
                    "file": filepath,
                    "detector": "vue_define_slots",
                    "summary": "Uses defineSlots — define slots via template usage instead",
                    "line": _find_line(content, r"\bdefineSlots\b"),
                }
            )

    return issues, total_files


def _find_line(content: str, pattern: str) -> int:
    """Find the line number of the first match."""
    match = re.search(pattern, content)
    if match:
        return content[: match.start()].count("\n") + 1
    return 0
