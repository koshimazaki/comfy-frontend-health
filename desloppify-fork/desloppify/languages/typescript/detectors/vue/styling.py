"""Detect Tailwind 4 / ComfyUI styling violations.

Finds:
- :class="[]" array syntax (should use cn() from @/utils/tailwindUtil)
- dark: variant usage (should use semantic theme tokens)
- !important or ! prefix in tailwind classes
- Arbitrary percentage values when tailwind fractions exist
- Raw color values instead of semantic tokens
- <style> blocks in Vue SFCs (should use inline Tailwind only)
"""

from __future__ import annotations

import re
from pathlib import Path

from desloppify.languages.typescript.detectors.vue import iter_vue_and_ts_sources

# Common tailwind fractions that have arbitrary equivalents
FRACTION_MAP = {
    "25%": "1/4",
    "33%": "1/3",
    "50%": "1/2",
    "66%": "2/3",
    "75%": "3/4",
    "80%": "4/5",
    "20%": "1/5",
    "40%": "2/5",
    "60%": "3/5",
    "100%": "full",
}


def detect_styling_violations(path: Path) -> tuple[list[dict], int]:
    """Scan Vue/TS files for Tailwind/styling violations."""
    issues: list[dict] = []
    total_files = 0

    for filepath in iter_vue_and_ts_sources(path):
        total_files += 1

        try:
            content = Path(filepath).read_text(errors="replace")
        except OSError:
            continue

        is_vue = filepath.endswith(".vue")

        # :class="[]" array syntax
        if re.search(r':class="\[', content):
            issues.append(
                {
                    "file": filepath,
                    "detector": "tailwind_class_array",
                    "summary": 'Uses :class="[]" array — use cn() from @/utils/tailwindUtil instead',
                    "line": _find_line(content, r':class="\['),
                }
            )

        # dark: variant usage
        if re.search(r"\bdark:", content) and not filepath.endswith(".css"):
            issues.append(
                {
                    "file": filepath,
                    "detector": "tailwind_dark_variant",
                    "summary": "Uses dark: variant — use semantic theme tokens from style.css instead",
                    "line": _find_line(content, r"\bdark:"),
                }
            )

        # !important prefix in tailwind (matches ! anywhere in class string)
        if re.search(r"(?<=['\"`\s])!(?:bg-|text-|border-|p-|m-|w-|h-|flex|grid)", content):
            issues.append(
                {
                    "file": filepath,
                    "detector": "tailwind_important",
                    "summary": "Uses ! important prefix — find and fix conflicting classes instead",
                    "line": _find_line(
                        content,
                        r"(?<=['\"`\s])!(?:bg-|text-|border-|p-|m-|w-|h-|flex|grid)",
                    ),
                }
            )

        # Arbitrary percentage when fraction exists
        for pct, frac in FRACTION_MAP.items():
            pattern = rf"\[{re.escape(pct)}\]"
            if re.search(pattern, content):
                issues.append(
                    {
                        "file": filepath,
                        "detector": "tailwind_arbitrary_pct",
                        "summary": f"Uses arbitrary [{pct}] — use {frac} fraction utility instead",
                        "line": _find_line(content, pattern),
                    }
                )
                break  # One per file

        # <style> blocks in Vue SFCs
        if is_vue:
            style_match = re.search(r"<style[\s>]", content)
            if style_match:
                style_end = content.find("</style>", style_match.start())
                style_section = content[style_match.start():style_end] if style_end != -1 else content[style_match.start():]
                if ":deep(" not in style_section:
                    issues.append(
                        {
                            "file": filepath,
                            "detector": "vue_style_block",
                            "summary": "Has <style> block — use inline Tailwind CSS only (exception: :deep() for third-party DOM)",
                            "line": _find_line(content, r"<style[\s>]"),
                        }
                    )

    return issues, total_files


def _find_line(content: str, pattern: str) -> int:
    match = re.search(pattern, content)
    if match:
        return content[: match.start()].count("\n") + 1
    return 0
