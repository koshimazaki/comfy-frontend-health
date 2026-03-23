"""TSX component extraction and passthrough detection helpers."""

from __future__ import annotations

import logging
import re
from pathlib import Path

from desloppify.base.discovery.source import find_tsx_files
from desloppify.base.discovery.paths import get_project_root
from desloppify.engine.detectors.base import ClassInfo
from desloppify.engine.detectors.passthrough import (
    classify_params,
    classify_passthrough_tier,
)

logger = logging.getLogger(__name__)

_COMPONENT_PATTERNS = [
    re.compile(
        r"(?:export\s+)?(?:const|let)\s+(\w+)"
        r"(?:\s*:\s*React\.FC\w*<[^>]*>)?"
        r"\s*=\s*\(\s*\{([^}]*)\}",
        re.DOTALL,
    ),
    re.compile(
        r"(?:export\s+)?function\s+(\w+)\s*\(\s*\{([^}]*)\}",
        re.DOTALL,
    ),
]


def extract_ts_components(path: Path) -> list[ClassInfo]:
    """Extract Vue 3 component composition metrics from .vue and .ts files."""
    from desloppify.base.discovery.source import find_source_files

    results = []
    for filepath in find_source_files(path, [".vue", ".ts", ".tsx"]):
        try:
            p = (
                Path(filepath)
                if Path(filepath).is_absolute()
                else get_project_root() / filepath
            )
            content = p.read_text(errors="replace")
            lines = content.splitlines()
            loc = len(lines)
            if loc < 50:
                continue

            watch_count = len(
                re.findall(r"\bwatch(?:(?:Sync|Post)?Effect)?\s*\(", content)
            )
            ref_count = len(
                re.findall(r"\b(?:ref|shallowRef|toRef)\s*[<(]", content)
            )
            lifecycle_count = len(
                re.findall(
                    r"\b(?:onMounted|onUnmounted|onBeforeMount|onBeforeUnmount"
                    r"|onUpdated|onBeforeUpdate|onActivated|onDeactivated"
                    r"|onErrorCaptured)\s*\(",
                    content,
                )
            )
            composable_count = len(
                re.findall(r"\buse[A-Z]\w+\s*\(", content)
            )

            # Count defineProps fields (approximate via destructuring or type params)
            prop_match = re.search(
                r"defineProps\s*<\s*\{([^}]*)\}", content, re.DOTALL
            )
            prop_count = 0
            if prop_match:
                prop_count = len(
                    [p for p in prop_match.group(1).split("\n") if ":" in p]
                )

            total = watch_count + ref_count + lifecycle_count + composable_count
            if total < 3:
                continue

            results.append(
                ClassInfo(
                    name=Path(filepath).stem,
                    file=filepath,
                    line=1,
                    loc=loc,
                    metrics={
                        "watch_count": watch_count,
                        "composable_count": composable_count,
                        "ref_count": ref_count,
                        "lifecycle_count": lifecycle_count,
                        "prop_count": prop_count,
                    },
                )
            )
        except (OSError, UnicodeDecodeError) as exc:
            logger.debug(
                "Skipping unreadable file %s in component extraction: %s",
                filepath,
                exc,
            )
            continue
    return results


def extract_props(destructured: str) -> list[str]:
    """Extract prop names from a destructuring pattern."""
    props = []
    cleaned = re.sub(
        r":\s*(?:React\.\w+(?:<[^>]*>)?|\w+(?:<[^>]*>)?(?:\[\])?)", "", destructured
    )
    for token in cleaned.split(","):
        token = token.strip()
        if not token:
            continue
        if token.startswith("..."):
            props.append(token[3:].strip())
            continue
        if ":" in token:
            _, alias = token.split(":", 1)
            alias = alias.split("=")[0].strip()
            if alias and alias.isidentifier():
                props.append(alias)
            continue
        name = token.split("=")[0].strip()
        if name and name.isidentifier():
            props.append(name)
    return props


def tsx_passthrough_pattern(name: str) -> str:
    """Match JSX same-name attribute: propName={propName}."""
    escaped = re.escape(name)
    return rf"\b{escaped}\s*=\s*\{{\s*{escaped}\s*\}}"


def detect_passthrough_components(path: Path) -> list[dict]:
    """Detect React components where most props are same-name forwarded to children."""
    entries = []
    for filepath in find_tsx_files(path):
        try:
            p = (
                Path(filepath)
                if Path(filepath).is_absolute()
                else get_project_root() / filepath
            )
            content = p.read_text()
        except (OSError, UnicodeDecodeError) as exc:
            logger.debug(
                "Skipping unreadable TSX file %s in passthrough detection: %s",
                filepath,
                exc,
            )
            continue

        for pattern in _COMPONENT_PATTERNS:
            for match in pattern.finditer(content):
                name = match.group(1)
                destructured = match.group(2)
                props = extract_props(destructured)
                if len(props) < 4:
                    continue

                body = content[match.end() :]
                passthrough, direct = classify_params(
                    props, body, tsx_passthrough_pattern
                )
                if len(passthrough) < 4:
                    continue

                ratio = len(passthrough) / len(props)
                classification = classify_passthrough_tier(len(passthrough), ratio)
                if classification is None:
                    continue
                tier, confidence = classification

                line = content[: match.start()].count("\n") + 1
                entries.append(
                    {
                        "file": filepath,
                        "component": name,
                        "total_props": len(props),
                        "passthrough": len(passthrough),
                        "direct": len(direct),
                        "ratio": round(ratio, 2),
                        "line": line,
                        "tier": tier,
                        "confidence": confidence,
                        "passthrough_props": sorted(passthrough),
                        "direct_props": sorted(direct),
                    }
                )

    return sorted(entries, key=lambda entry: (-entry["passthrough"], -entry["ratio"]))


__all__ = [
    "detect_passthrough_components",
    "extract_props",
    "extract_ts_components",
    "tsx_passthrough_pattern",
]
