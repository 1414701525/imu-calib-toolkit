from __future__ import annotations

import numpy as np

from .analyze_allan_common import analyze_allan_common


def analyze_gyro_allan(t: np.ndarray, gyro: np.ndarray, **kwargs) -> dict:
    """Compute a basic Allan deviation estimate for gyroscope data."""
    return analyze_allan_common(t, gyro, "gyro", **kwargs)
