from __future__ import annotations

import numpy as np

from imu_calib.utils.math_utils import as_matrix_n3


def estimate_gyro_bias(static_gyro: np.ndarray, t: np.ndarray | None = None, temp: np.ndarray | None = None) -> tuple[np.ndarray, dict]:
    """Estimate gyroscope static bias from a stationary segment."""
    gyro = as_matrix_n3(static_gyro, "static_gyro")
    bg = gyro.mean(axis=0)
    residual = gyro - bg[None, :]

    info = {
        "num_samples": int(gyro.shape[0]),
        "mean": bg,
        "std": residual.std(axis=0, ddof=0),
        "var": residual.var(axis=0, ddof=0),
        "rms": np.sqrt(np.mean(gyro**2, axis=0)),
        "residual_rms": np.sqrt(np.mean(residual**2, axis=0)),
        "max_abs_residual": np.max(np.abs(residual), axis=0),
        "time_span": None if t is None else np.array([np.asarray(t)[0], np.asarray(t)[-1]], dtype=float),
        "temp_range": None if temp is None else np.array([np.min(temp), np.max(temp)], dtype=float),
    }
    return bg, info
