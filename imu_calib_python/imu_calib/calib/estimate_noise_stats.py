from __future__ import annotations

import numpy as np

from imu_calib.utils.math_utils import as_matrix_n3


def estimate_noise_stats(static_gyro: np.ndarray, static_acc: np.ndarray) -> dict:
    """Estimate basic static noise statistics from de-meaned residuals."""
    gyro = as_matrix_n3(static_gyro, "static_gyro")
    acc = as_matrix_n3(static_acc, "static_acc")
    if gyro.shape[0] != acc.shape[0]:
        raise ValueError("static_gyro and static_acc must contain the same number of samples.")

    gyro_mean = gyro.mean(axis=0)
    acc_mean = acc.mean(axis=0)
    gyro_residual = gyro - gyro_mean[None, :]
    acc_residual = acc - acc_mean[None, :]

    return {
        "gyro_mean": gyro_mean,
        "acc_mean": acc_mean,
        "gyro_std": gyro_residual.std(axis=0, ddof=0),
        "gyro_var": gyro_residual.var(axis=0, ddof=0),
        "acc_std": acc_residual.std(axis=0, ddof=0),
        "acc_var": acc_residual.var(axis=0, ddof=0),
        "num_samples": int(gyro.shape[0]),
        "gyro_residual": gyro_residual,
        "acc_residual": acc_residual,
        "extensions": {
            "allan": None,
            "psd": None,
            "notes": "Placeholder for future Allan variance / PSD estimation.",
        },
    }
