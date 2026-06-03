from __future__ import annotations

import numpy as np

from imu_calib.runtime.default_calib_options import default_calib_options
from imu_calib.utils.exceptions import ImuCalibError
from imu_calib.utils.math_utils import as_matrix_n3, validate_time_vector


def detect_steady_segments(
    t: np.ndarray,
    gyro: np.ndarray,
    *,
    steady_window_sec: float | None = None,
    gyro_norm_threshold: float | None = None,
    gyro_std_threshold: float | None = None,
    min_segment_sec: float | None = None,
) -> dict:
    """Detect steady rotation segments from gyro data."""
    t = validate_time_vector(t, "t")
    gyro = as_matrix_n3(gyro, "gyro")
    if gyro.shape[0] != t.size:
        raise ImuCalibError("t and gyro must have matching lengths.")

    defaults = default_calib_options()["segmentation"]
    dt = float(np.median(np.diff(t)))
    steady_window_sec = defaults["steady_window_sec"] if steady_window_sec is None else float(steady_window_sec)
    gyro_norm_threshold = defaults["gyro_norm_threshold"] if gyro_norm_threshold is None else float(gyro_norm_threshold)
    gyro_std_threshold = defaults["gyro_std_threshold"] if gyro_std_threshold is None else float(gyro_std_threshold)
    min_segment_sec = defaults["min_segment_sec"] if min_segment_sec is None else float(min_segment_sec)

    win = max(3, int(round(steady_window_sec / dt)))
    gyro_norm = np.linalg.norm(gyro, axis=1)
    gyro_std = _moving_std_scalar(gyro_norm, win)
    gyro_mean = _moving_mean_scalar(gyro_norm, win)
    mask = (gyro_mean > gyro_norm_threshold) & (gyro_std <= gyro_std_threshold)
    segments = _logical_mask_to_segments(mask, max(1, int(round(min_segment_sec / dt))))
    return {
        "mask": mask,
        "segments": segments,
        "quality": {
            "window_samples": win,
            "gyro_norm_threshold": gyro_norm_threshold,
            "gyro_std_threshold": gyro_std_threshold,
            "num_segments": int(segments.shape[0]),
        },
    }


def _moving_mean_scalar(x: np.ndarray, win: int) -> np.ndarray:
    out = np.zeros_like(x, dtype=float)
    half = win // 2
    for i in range(x.size):
        i0 = max(0, i - half)
        i1 = min(x.size, i + half + 1)
        out[i] = float(np.mean(x[i0:i1]))
    return out


def _moving_std_scalar(x: np.ndarray, win: int) -> np.ndarray:
    out = np.zeros_like(x, dtype=float)
    half = win // 2
    for i in range(x.size):
        i0 = max(0, i - half)
        i1 = min(x.size, i + half + 1)
        out[i] = float(np.std(x[i0:i1], ddof=0))
    return out


def _logical_mask_to_segments(mask: np.ndarray, min_len: int) -> np.ndarray:
    d = np.diff(np.r_[False, mask.astype(bool), False].astype(int))
    starts = np.flatnonzero(d == 1)
    ends = np.flatnonzero(d == -1) - 1
    keep = (ends - starts + 1) >= min_len
    return np.column_stack([starts[keep], ends[keep]]) if np.any(keep) else np.empty((0, 2), dtype=int)
