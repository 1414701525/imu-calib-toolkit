from __future__ import annotations

import numpy as np

from imu_calib.runtime.default_calib_options import default_calib_options
from imu_calib.utils.exceptions import ImuCalibError
from imu_calib.utils.math_utils import as_matrix_n3, validate_time_vector


def analyze_allan_common(
    t: np.ndarray,
    x: np.ndarray,
    sensor_type: str,
    *,
    min_samples: int | None = None,
    num_tau: int | None = None,
    tau_mode: str | None = None,
    validity_message_if_short: str | None = None,
) -> dict:
    """Shared Allan deviation implementation for 3-axis signals."""
    t = validate_time_vector(t, "t")
    x = as_matrix_n3(x, "x")
    if x.shape[0] != t.size:
        raise ImuCalibError("t and x must have matching lengths.")

    defaults = default_calib_options()["allan"]
    min_samples = defaults["min_samples"] if min_samples is None else int(min_samples)
    num_tau = defaults["num_tau"] if num_tau is None else int(num_tau)
    tau_mode = defaults["tau_mode"] if tau_mode is None else str(tau_mode)
    validity_message_if_short = (
        defaults["validity_message_if_short"]
        if validity_message_if_short is None
        else str(validity_message_if_short)
    )

    N = x.shape[0]
    dt = float(np.median(np.diff(t)))
    allan = {
        "valid": False,
        "sensor_type": sensor_type,
        "message": "",
        "tau": np.array([], dtype=float),
        "adev": np.empty((0, 3), dtype=float),
        "num_samples": int(N),
    }

    if N < min_samples:
        allan["message"] = validity_message_if_short
        return allan

    max_m = max(2, N // 10)
    if max_m < 2:
        allan["message"] = "Insufficient data length for Allan deviation."
        return allan

    if tau_mode.lower() == "logspace":
        m_list = np.unique(np.maximum(1, np.round(np.logspace(0, np.log10(max_m), num_tau)).astype(int)))
    else:
        m_list = np.arange(1, max_m + 1, dtype=int)

    tau = m_list.astype(float) * dt
    adev = np.full((m_list.size, 3), np.nan, dtype=float)
    for k, m in enumerate(m_list):
        cluster_count = N // m
        if cluster_count < 2:
            continue
        trimmed = x[: cluster_count * m, :]
        clustered = trimmed.reshape(cluster_count, m, 3).mean(axis=1)
        diff_cluster = np.diff(clustered, axis=0)
        adev[k, :] = np.sqrt(0.5 * np.mean(diff_cluster**2, axis=0))

    valid_rows = np.all(np.isfinite(adev), axis=1)
    tau = tau[valid_rows]
    adev = adev[valid_rows, :]
    if tau.size == 0:
        allan["message"] = "Allan deviation could not be estimated from the provided data."
        return allan

    allan["valid"] = True
    allan["message"] = "Allan deviation estimated using non-overlapping cluster averages."
    allan["tau"] = tau
    allan["adev"] = adev
    allan["estimate"] = _estimate_allan_params(tau, adev, sensor_type)
    return allan


def _estimate_allan_params(tau: np.ndarray, adev: np.ndarray, sensor_type: str) -> dict:
    return {
        "noise_density": adev[0, :].copy(),
        "bias_instability": np.min(adev, axis=0),
        "random_walk": adev[-1, :] / np.sqrt(tau[-1]),
        "confidence": "low_to_medium",
        "notes": (
            f"Stage-2 {sensor_type} Allan estimates are coarse summaries intended "
            "for engineering inspection, not high-accuracy metrology."
        ),
    }
