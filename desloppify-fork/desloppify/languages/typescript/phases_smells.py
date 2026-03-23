"""TypeScript smells phase runner."""

from __future__ import annotations

from pathlib import Path

from desloppify.base.output.terminal import log
from desloppify.engine._state.filtering import make_issue
from desloppify.engine.policy.zones import adjust_potential
from desloppify.languages._framework.base.smell_contracts import (
    normalize_smell_entries,
)
from desloppify.languages._framework.base.types import LangRuntimeContract
from desloppify.languages._framework.issue_factories import make_smell_issues
import desloppify.languages.typescript.detectors.smells as smells_detector_mod
from desloppify.state_io import Issue


def phase_smells(path: Path, lang: LangRuntimeContract) -> tuple[list[Issue], dict[str, int]]:
    smell_entries, total_smell_files = smells_detector_mod.detect_smells(path)
    normalized_smells = normalize_smell_entries(smell_entries)
    results = make_smell_issues(
        [entry.to_mapping() for entry in normalized_smells],
        log,
    )

    return results, {
        "smells": adjust_potential(lang.zone_map, total_smell_files),
    }


__all__ = ["phase_smells"]
