from __future__ import annotations

import numpy as np

from imu_calib.runtime.get_bias_from_temperature import get_bias_from_temperature


def get_accel_bias_from_temperature(
    temp: np.ndarray | None,
    ba_const: np.ndarray,
    temp_model: dict | None = None,
) -> tuple[np.ndarray, dict]:
    """Evaluate ba(T) with constant-bias fallback."""

    return get_bias_from_temperature(temp, ba_const, temp_model, target_name="ba")
