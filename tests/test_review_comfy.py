"""Tests for ComfyUI review heuristics (review_comfy.py)."""

from __future__ import annotations

import re

from desloppify.languages.typescript.review_comfy import (
    COMFY_HOLISTIC_REVIEW_DIMENSIONS,
    COMFY_MIGRATION_PATTERN_PAIRS,
    COMFY_REVIEW_GUIDANCE,
)


def test_dimensions_count():
    assert len(COMFY_HOLISTIC_REVIEW_DIMENSIONS) == 21


def test_guidance_category_count():
    assert len(COMFY_REVIEW_GUIDANCE) == 10


def test_total_checks_across_guidance():
    total = sum(
        len(v) if isinstance(v, list) else 1
        for v in COMFY_REVIEW_GUIDANCE.values()
    )
    assert total == 64


def test_guidance_categories_are_lists_except_naming():
    for key, value in COMFY_REVIEW_GUIDANCE.items():
        if key == "naming":
            assert isinstance(value, str), f"{key} should be a string"
        else:
            assert isinstance(value, list), f"{key} should be a list"


def test_migration_pairs_compile():
    for name, old_pat, new_pat in COMFY_MIGRATION_PATTERN_PAIRS:
        assert isinstance(name, str)
        assert isinstance(old_pat, re.Pattern)
        assert isinstance(new_pat, re.Pattern)


def test_dimension_names_are_snake_case():
    snake_case = re.compile(r"^[a-z][a-z0-9]*(_[a-z0-9]+)*$")
    for dim in COMFY_HOLISTIC_REVIEW_DIMENSIONS:
        assert snake_case.match(dim), f"{dim!r} is not valid snake_case"


def test_no_duplicate_dimensions():
    assert len(COMFY_HOLISTIC_REVIEW_DIMENSIONS) == len(
        set(COMFY_HOLISTIC_REVIEW_DIMENSIONS)
    )


def test_each_guidance_check_is_nonempty():
    for key, value in COMFY_REVIEW_GUIDANCE.items():
        if isinstance(value, list):
            for i, check in enumerate(value):
                assert isinstance(check, str) and check.strip(), (
                    f"{key}[{i}] is empty or not a string"
                )
        else:
            assert isinstance(value, str) and value.strip(), (
                f"{key} is empty or not a string"
            )
