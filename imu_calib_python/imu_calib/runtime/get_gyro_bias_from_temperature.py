from __future__ import annotations

import numpy as np

from imu_calib.runtime.get_bias_from_temperature import get_bias_from_temperature


def get_gyro_bias_from_temperature(
    temp: np.ndarray | None,
    bg_const: np.ndarray,
    temp_model: dict | None = None,
) -> tuple[np.ndarray, dict]:
    """Evaluate bg(T) with constant-bias fallback."""

    return get_bias_from_temperature(temp, bg_const, temp_model, target_name="bg")
