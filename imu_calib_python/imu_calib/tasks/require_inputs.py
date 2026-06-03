from __future__ import annotations

from dataclasses import is_dataclass


def require_inputs(obj, required_paths: list[str] | tuple[str, ...] | str) -> list[str]:
    """Return required nested paths that are absent or empty."""
    if isinstance(required_paths, str):
        required_paths = [required_paths]
    missing: list[str] = []
    for path in required_paths:
        if not _has_nested_value(obj, path):
            missing.append(path)
    return missing


def _has_nested_value(obj, path: str) -> bool:
    current = obj
    for part in path.split("."):
        if current is None:
            return False
        if isinstance(current, dict):
            if part not in current:
                return False
            current = current[part]
            continue
        if is_dataclass(current):
            if not hasattr(current, part):
                return False
            current = getattr(current, part)
            continue
        if hasattr(current, part):
            current = getattr(current, part)
            continue
        return False

    if current is None:
        return False
    try:
        return len(current) > 0  # noqa: PLR2004
    except Exception:
        return True
