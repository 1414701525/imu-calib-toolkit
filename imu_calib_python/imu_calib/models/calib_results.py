from __future__ import annotations

from dataclasses import dataclass, field
from typing import Any


@dataclass(slots=True)
class CalibrationResults:
    """Unified calibration result container."""

    data: Any
    options: dict[str, Any]
    model: dict[str, Any]
    calib: dict[str, Any]
    analysis: dict[str, Any] = field(default_factory=dict)
    validation: dict[str, Any] = field(default_factory=dict)
    meta: dict[str, Any] = field(default_factory=dict)
    truth: dict[str, Any] | None = None
    compat: dict[str, Any] = field(default_factory=dict)
