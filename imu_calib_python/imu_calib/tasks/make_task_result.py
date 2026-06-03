from __future__ import annotations

from typing import Any


def make_task_result(
    success: bool,
    message: str,
    result: Any,
    *,
    warnings: list[str] | None = None,
    missing_inputs: list[str] | None = None,
    meta: dict[str, Any] | None = None,
) -> dict[str, Any]:
    """Create a unified task result aligned with the latest MATLAB task layer."""

    return {
        "success": bool(success),
        "valid": bool(success),
        "message": str(message),
        "warnings": [str(x) for x in (warnings or [])],
        "missing_inputs": [str(x) for x in (missing_inputs or [])],
        "result": result,
        "meta": {} if meta is None else meta,
    }
