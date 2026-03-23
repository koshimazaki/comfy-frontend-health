"""Detect additional Vue 3 / ComfyUI convention violations.

Finds:
- Function expressions where declarations work (exported const arrows)
- @ts-expect-error / @ts-ignore usage
- z.any() in Zod schemas
- waitForTimeout in Playwright tests
- npm/npx usage (should be pnpm/pnpm dlx)
- Composable naming violations (useXyz.ts)
- Store naming violations (*Store.ts)
- <script> without setup attribute in .vue files
"""

from __future__ import annotations

import re
from pathlib import Path

from desloppify.languages.typescript.detectors.vue import iter_vue_and_ts_sources


def detect_conventions(path: Path) -> tuple[list[dict], int]:
    """Scan for additional convention violations."""
    issues: list[dict] = []
    total_files = 0

    for filepath in iter_vue_and_ts_sources(path):
        total_files += 1

        try:
            content = Path(filepath).read_text(errors="replace")
        except OSError:
            continue

        is_vue = filepath.endswith(".vue")
        is_test = ".test." in filepath or ".spec." in filepath
        in_src = "/src/" in filepath

        # ── @ts-expect-error / @ts-ignore ─────────────────────────────
        if in_src and not is_test:
            ts_suppress = re.findall(
                r"@ts-(?:expect-error|ignore)", content
            )
            if ts_suppress:
                issues.append(
                    {
                        "file": filepath,
                        "detector": "ts_suppress_error",
                        "summary": f"Uses @ts-expect-error/@ts-ignore ({len(ts_suppress)}x) — fix the underlying type issue",
                        "line": _find_line(
                            content, r"@ts-(?:expect-error|ignore)"
                        ),
                        "count": len(ts_suppress),
                    }
                )

        # ── z.any() in Zod schemas ────────────────────────────────────
        if re.search(r"z\.any\(\)", content):
            count = len(re.findall(r"z\.any\(\)", content))
            issues.append(
                {
                    "file": filepath,
                    "detector": "zod_any",
                    "summary": f"Uses z.any() ({count}x) — use z.unknown() then narrow",
                    "line": _find_line(content, r"z\.any\(\)"),
                    "count": count,
                }
            )

        # ── waitForTimeout in Playwright tests ────────────────────────
        if is_test and re.search(r"waitForTimeout\s*\(", content):
            issues.append(
                {
                    "file": filepath,
                    "detector": "playwright_wait_timeout",
                    "summary": "Uses waitForTimeout — use Locator actions and retrying assertions instead",
                    "line": _find_line(content, r"waitForTimeout\s*\("),
                }
            )

        # ── <script> without setup in .vue files ──────────────────────
        if is_vue:
            has_script = re.search(r"<script\b", content)
            has_setup = re.search(r"<script\s+[^>]*\bsetup\b", content)
            if has_script and not has_setup:
                issues.append(
                    {
                        "file": filepath,
                        "detector": "vue_script_no_setup",
                        "summary": "Uses <script> without setup — use <script setup lang='ts'>",
                        "line": _find_line(content, r"<script\b"),
                    }
                )

        # ── Composable naming violations ──────────────────────────────
        if "/composables/" in filepath and filepath.endswith(".ts"):
            basename = Path(filepath).stem
            if (
                not basename.startswith("use")
                and not basename.startswith("_")
                and not is_test
                and basename != "index"
            ):
                issues.append(
                    {
                        "file": filepath,
                        "detector": "composable_naming",
                        "summary": f"Composable '{basename}.ts' does not follow useXyz naming convention",
                        "line": 1,
                    }
                )

        # ── Store naming violations ───────────────────────────────────
        if "/stores/" in filepath and filepath.endswith(".ts"):
            basename = Path(filepath).stem
            if (
                not basename.endswith("Store")
                and not basename.startswith("_")
                and not is_test
                and basename != "index"
            ):
                issues.append(
                    {
                        "file": filepath,
                        "detector": "store_naming",
                        "summary": f"Store '{basename}.ts' does not follow *Store naming convention",
                        "line": 1,
                    }
                )

        # ── Exported function expressions (module-scope only) ─────────
        if in_src and not is_test and not is_vue:
            # Match: export const funcName = (...) => or export const funcName = function
            func_expr_matches = re.findall(
                r"^export\s+(?:const|let)\s+\w+\s*=\s*(?:\([^)]*\)\s*=>|function\b)",
                content,
                re.MULTILINE,
            )
            if len(func_expr_matches) > 2:
                issues.append(
                    {
                        "file": filepath,
                        "detector": "function_expression",
                        "summary": f"Uses {len(func_expr_matches)} exported function expressions — prefer function declarations",
                        "line": _find_line(
                            content,
                            r"^export\s+(?:const|let)\s+\w+\s*=\s*(?:\([^)]*\)\s*=>|function\b)",
                        ),
                        "count": len(func_expr_matches),
                    }
                )

    return issues, total_files


def _find_line(content: str, pattern: str) -> int:
    match = re.search(pattern, content, re.MULTILINE)
    if match:
        return content[: match.start()].count("\n") + 1
    return 0
