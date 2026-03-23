"""CLI rendering for Vue 3 / ComfyUI convention detector output."""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from desloppify.base.discovery.file_paths import rel
from desloppify.base.output.terminal import colorize, print_table
from .composition_api import detect_composition_api
from .components import detect_component_violations
from .conventions import detect_conventions
from .layer_violations import detect_layer_violations
from .reka_patterns import detect_reka_patterns
from .styling import detect_styling_violations


_DETECTORS = [
    detect_composition_api,
    detect_styling_violations,
    detect_component_violations,
    detect_layer_violations,
    detect_conventions,
    detect_reka_patterns,
]


def cmd_vue(args: argparse.Namespace) -> None:
    """Show Vue 3 / ComfyUI convention violations."""
    path = Path(args.path)
    all_issues: list[dict] = []

    for detector_fn in _DETECTORS:
        entries, _ = detector_fn(path)
        all_issues.extend(entries)

    if args.json:
        payload = {
            "count": len(all_issues),
            "entries": [
                {
                    "file": rel(e["file"]),
                    "line": e.get("line", 0),
                    "detector": e["detector"],
                    "summary": e["summary"],
                }
                for e in all_issues
            ],
        }
        sys.stdout.write(json.dumps(payload, indent=2) + "\n")
        return

    if not all_issues:
        sys.stdout.write(
            colorize("\nNo Vue convention violations found.", "green") + "\n"
        )
        return

    sys.stdout.write(
        colorize(
            f"\nVue convention violations: {len(all_issues)}\n",
            "bold",
        )
        + "\n"
    )

    rows = [
        [
            rel(e["file"]),
            str(e.get("line", 0)),
            e["detector"],
            e["summary"][:60],
        ]
        for e in all_issues[: args.top]
    ]
    print_table(["File", "Line", "Detector", "Summary"], rows, [50, 6, 25, 60])
    sys.stdout.write("\n")


__all__ = ["cmd_vue"]
