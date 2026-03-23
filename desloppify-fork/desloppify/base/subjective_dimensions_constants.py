"""Subjective-dimension constants and name helpers.

Data is sourced from subjective_dimension_catalog — this module provides
helper functions and legacy aliases for backward compatibility.
"""

from __future__ import annotations

from desloppify.base.subjective_dimension_catalog import (
    DISPLAY_NAMES,
    RESET_ON_SCAN_DIMENSIONS,
    WEIGHT_BY_DIMENSION,
)

# Legacy aliases — callers that import LEGACY_* still work.
LEGACY_DISPLAY_NAMES: dict[str, str] = DISPLAY_NAMES
LEGACY_SUBJECTIVE_WEIGHTS_BY_DISPLAY = None  # removed: use WEIGHT_BY_DIMENSION
LEGACY_RESET_ON_SCAN_DIMENSIONS = RESET_ON_SCAN_DIMENSIONS
LEGACY_WEIGHT_BY_DIMENSION: dict[str, float] = WEIGHT_BY_DIMENSION


def normalize_dimension_name(name: str) -> str:
    return "_".join(str(name).strip().lower().replace("-", "_").split())


def title_display_name(dimension_key: str) -> str:
    return dimension_key.replace("_", " ").title()


def normalize_lang_name(lang_name: str | None) -> str | None:
    if not isinstance(lang_name, str):
        return None
    cleaned = lang_name.strip().lower()
    return cleaned or None


__all__ = [
    "DISPLAY_NAMES",
    "LEGACY_DISPLAY_NAMES",
    "LEGACY_RESET_ON_SCAN_DIMENSIONS",
    "LEGACY_WEIGHT_BY_DIMENSION",
    "normalize_dimension_name",
    "normalize_lang_name",
    "title_display_name",
]
