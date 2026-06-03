from __future__ import annotations

import numpy as np

from .exceptions import ImuCalibError


def as_vector3(x: np.ndarray, name: str) -> np.ndarray:
    arr = np.asarray(x, dtype=float).reshape(-1)
    if arr.size != 3 or not np.all(np.isfinite(arr)):
        raise ImuCalibError(f"{name} must be a finite 3-vector.")
    return arr


def as_matrix_n3(x: np.ndarray, name: str) -> np.ndarray:
    arr = np.asarray(x, dtype=float)
    if arr.ndim != 2 or arr.shape[1] != 3 or arr.shape[0] == 0 or not np.all(np.isfinite(arr)):
        raise ImuCalibError(f"{name} must be a finite array with shape (N, 3).")
    return arr


def as_column(x: np.ndarray, name: str) -> np.ndarray:
    arr = np.asarray(x, dtype=float).reshape(-1)
    if arr.size == 0 or not np.all(np.isfinite(arr)):
        raise ImuCalibError(f"{name} must be a finite non-empty vector.")
    return arr


def validate_time_vector(t: np.ndarray, name: str) -> np.ndarray:
    vec = as_column(t, name)
    if vec.size < 2:
        raise ImuCalibError(f"{name} must contain at least two samples.")
    if np.any(np.diff(vec) <= 0):
        raise ImuCalibError(f"{name} must be strictly increasing.")
    return vec


def check_matrix_well_conditioned(M: np.ndarray, name: str, threshold: float = 1e-12) -> float:
    arr = np.asarray(M, dtype=float)
    if arr.shape != (3, 3) or not np.all(np.isfinite(arr)):
        raise ImuCalibError(f"{name} must be a finite 3x3 matrix.")
    rcond = 1.0 / np.linalg.cond(arr)
    if not np.isfinite(rcond) or rcond < threshold:
        raise ImuCalibError(f"{name} is numerically singular or nearly singular (rcond={rcond:.3e}).")
    return float(rcond)


def trapz_integral(t: np.ndarray, y: np.ndarray) -> np.ndarray:
    if hasattr(np, "trapezoid"):
        return np.trapezoid(y, t, axis=0)
    return np.trapz(y, t, axis=0)
