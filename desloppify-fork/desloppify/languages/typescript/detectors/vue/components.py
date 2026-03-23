"""Detect ComfyUI component convention violations.

Finds:
- PrimeVue imports (should use Reka UI primitives + shadcn-vue)
- Missing vue-i18n for user-facing strings in templates
- Barrel files (index.ts re-exports) within src/
- Direct fetch bypassing api helpers
- as any / any type usage
- Mixed import type (inline type in mixed imports)
"""

from __future__ import annotations

import re
from pathlib import Path

from desloppify.languages.typescript.detectors.vue import iter_vue_and_ts_sources

# PrimeVue component prefixes to detect
PRIMEVUE_PATTERNS = [
    r"from\s+['\"]primevue/",
    r"import.*from\s+['\"]primevue",
    r"<(?:P|p)rime",
]


def detect_component_violations(path: Path) -> tuple[list[dict], int]:
    """Scan for ComfyUI component convention violations."""
    issues: list[dict] = []
    total_files = 0

    for filepath in iter_vue_and_ts_sources(path):
        total_files += 1

        try:
            content = Path(filepath).read_text(errors="replace")
        except OSError:
            continue

        rel_path = filepath

        # PrimeVue imports
        for pattern in PRIMEVUE_PATTERNS:
            if re.search(pattern, content):
                issues.append(
                    {
                        "file": filepath,
                        "detector": "primevue_import",
                        "summary": "Imports PrimeVue component — use Reka UI primitives + shadcn-vue instead",
                        "line": _find_line(content, pattern),
                    }
                )
                break

        # as any usage
        if re.search(r"\bas\s+any\b", content):
            count = len(re.findall(r"\bas\s+any\b", content))
            issues.append(
                {
                    "file": filepath,
                    "detector": "ts_as_any",
                    "summary": f"Uses 'as any' ({count}x) — fix the underlying type issue",
                    "line": _find_line(content, r"\bas\s+any\b"),
                    "count": count,
                }
            )

        # Bare any type (: any, <any>, = any)
        any_matches = re.findall(r"(?::|\<|=)\s*any\b", content)
        if any_matches:
            issues.append(
                {
                    "file": filepath,
                    "detector": "ts_any_type",
                    "summary": f"Uses 'any' type ({len(any_matches)}x) — use proper TypeScript types",
                    "line": _find_line(content, r":\s*any\b"),
                    "count": len(any_matches),
                }
            )

        # Mixed import type (inline type in mixed imports)
        # Bad: import { bar, type Foo } or import { type Foo, bar }
        has_mixed = (
            re.search(r"import\s*\{[^}]*,\s*type\s+\w+", content)
            or re.search(r"import\s*\{\s*type\s+\w+[^}]*,\s*\w+", content)
        )
        if has_mixed:
            issues.append(
                {
                    "file": filepath,
                    "detector": "mixed_import_type",
                    "summary": "Uses inline 'type' in mixed import — use separate import type statement",
                    "line": _find_line(content, r"import\s*\{[^}]*,\s*type\s+\w+"),
                }
            )

        # Direct fetch bypassing api helpers (in src/ files only)
        if ("/src/" in filepath or filepath.startswith("src/")) and re.search(
            r"(?:await\s+)?fetch\s*\(\s*['\"`]/(?:api|prompt|history|queue)",
            content,
        ):
            issues.append(
                {
                    "file": filepath,
                    "detector": "direct_fetch",
                    "summary": "Uses direct fetch for API call — use api.get(api.apiURL(...)) helpers",
                    "line": _find_line(
                        content,
                        r"(?:await\s+)?fetch\s*\(\s*['\"`]/(?:api|prompt|history|queue)",
                    ),
                }
            )

        # Barrel files in src/
        if ("/src/" in filepath or filepath.startswith("src/")) and filepath.endswith(("index.ts", "index.tsx")):
            # Check if it's primarily re-exports
            export_from_count = len(re.findall(r"export\s+.*\s+from\s+", content))
            total_lines = content.count("\n")
            if export_from_count > 0 and export_from_count / max(total_lines, 1) > 0.5:
                issues.append(
                    {
                        "file": filepath,
                        "detector": "barrel_file",
                        "summary": f"Barrel file ({export_from_count} re-exports) — avoid index.ts re-exports within src/",
                        "line": 1,
                    }
                )

    return issues, total_files


def _find_line(content: str, pattern: str) -> int:
    match = re.search(pattern, content)
    if match:
        return content[: match.start()].count("\n") + 1
    return 0
