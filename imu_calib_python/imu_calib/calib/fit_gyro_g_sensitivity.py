from __future__ import annotations

import numpy as np

from imu_calib.models.data_structures import GsensRun
from imu_calib.utils.exceptions import ImuCalibError
from imu_calib.utils.math_utils import as_vector3, check_matrix_well_conditioned


def fit_gyro_g_sensitivity(gsens_runs: list[GsensRun], bg: np.ndarray, Cg: np.ndarray) -> tuple[np.ndarray, dict]:
    """Fit Gg from residuals using an explicit 9-parameter joint least-squares problem."""
    bg = as_vector3(bg, "bg")
    check_matrix_well_conditioned(Cg, "Cg")

    if not gsens_runs:
        return np.zeros((3, 3), dtype=float), {
            "message": "No gsens_runs provided. Returning zeros((3, 3)).",
            "valid": False,
            "gsens_term": "f_term",
            "gsens_definition": (
                "Gg is fit against gsens_runs.acc_ref and must be applied to the same "
                "f_term definition online."
            ),
            "num_runs": 0,
            "num_samples": 0,
            "design_rank": np.nan,
            "joint_design_rank": np.nan,
            "joint_design_condition": np.nan,
            "residual_rms": np.nan,
            "max_abs_residual": np.nan,
        }

    total_samples = 0
    for idx, run in enumerate(gsens_runs):
        _validate_run(run, idx)
        total_samples += run.gyro.shape[0]

    F = np.zeros((total_samples, 3), dtype=float)
    R = np.zeros((total_samples, 3), dtype=float)
    row_start = 0
    for run in gsens_runs:
        gyro = run.gyro
        acc_ref = run.acc_ref
        omega_ref = np.zeros_like(gyro) if run.omega_ref is None else run.omega_ref
        residual = (gyro - bg[None, :]) - (Cg @ omega_ref.T).T
        row_end = row_start + gyro.shape[0]
        F[row_start:row_end, :] = acc_ref
        R[row_start:row_end, :] = residual
        row_start = row_end

    design_rank = int(np.linalg.matrix_rank(F))
    if total_samples < 3 or design_rank < 3:
        return np.zeros((3, 3), dtype=float), {
            "message": "Insufficient gsens excitation. Returning zeros((3, 3)).",
            "valid": False,
            "gsens_term": "f_term",
            "gsens_definition": (
                "Gg is fit against gsens_runs.acc_ref and must be applied to the same "
                "f_term definition online."
            ),
            "num_runs": len(gsens_runs),
            "num_samples": total_samples,
            "design_rank": design_rank,
            "joint_design_rank": np.nan,
            "joint_design_condition": np.nan,
            "residual_rms": np.nan,
            "max_abs_residual": np.nan,
        }

    A = np.zeros((3 * total_samples, 9), dtype=float)
    y = np.zeros(3 * total_samples, dtype=float)
    for i in range(total_samples):
        rows = slice(3 * i, 3 * (i + 1))
        A[rows, :] = np.kron(F[i, :].reshape(1, 3), np.eye(3))
        y[rows] = R[i, :]

    joint_rank = int(np.linalg.matrix_rank(A))
    if joint_rank < 9:
        return np.zeros((3, 3), dtype=float), {
            "message": "Insufficient excitation for joint 9-parameter Gg fit. Returning zeros((3, 3)).",
            "valid": False,
            "gsens_term": "f_term",
            "gsens_definition": (
                "Gg is fit against gsens_runs.acc_ref and must be applied to the same "
                "f_term definition online."
            ),
            "num_runs": len(gsens_runs),
            "num_samples": total_samples,
            "design_rank": design_rank,
            "joint_design_rank": joint_rank,
            "joint_design_condition": np.inf,
            "residual_rms": np.nan,
            "max_abs_residual": np.nan,
        }

    x, *_ = np.linalg.lstsq(A, y, rcond=None)
    Gg = x.reshape(3, 3)
    fit_residual = y - A @ x
    return Gg, {
        "message": "Gg fitted using joint 9-parameter least squares.",
        "valid": True,
        "gsens_term": "f_term",
        "gsens_definition": (
            "Gg is fit against gsens_runs.acc_ref and must be applied to the same "
            "f_term definition online."
        ),
        "num_runs": len(gsens_runs),
        "num_samples": total_samples,
        "design_rank": design_rank,
        "joint_design_rank": joint_rank,
        "joint_design_condition": float(np.linalg.cond(A)),
        "residual_rms": float(np.sqrt(np.mean(fit_residual**2))),
        "max_abs_residual": float(np.max(np.abs(fit_residual))),
    }


def _validate_run(run: GsensRun, idx: int) -> None:
    if run.gyro.ndim != 2 or run.gyro.shape[1] != 3:
        raise ImuCalibError(f"gsens_runs[{idx}].gyro must have shape (N, 3).")
    if run.acc_ref.ndim != 2 or run.acc_ref.shape != run.gyro.shape:
        raise ImuCalibError(f"gsens_runs[{idx}].acc_ref must have the same shape as gyro.")
    if run.t.ndim != 1 or run.t.size != run.gyro.shape[0]:
        raise ImuCalibError(f"gsens_runs[{idx}].t length must match gyro samples.")
    if run.omega_ref is not None and run.omega_ref.shape != run.gyro.shape:
        raise ImuCalibError(f"gsens_runs[{idx}].omega_ref must have the same shape as gyro.")
