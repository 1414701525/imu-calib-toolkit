from __future__ import annotations

import numpy as np

from .analyze_allan_common import analyze_allan_common


def analyze_acc_allan(t: np.ndarray, acc: np.ndarray, **kwargs) -> dict:
    """Compute a basic Allan deviation estimate for accelerometer data."""
    return analyze_allan_common(t, acc, "acc", **kwargs)
