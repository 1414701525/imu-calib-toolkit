from __future__ import annotations

import numpy as np

from imu_calib.models.data_structures import GyroRun
from imu_calib.utils.exceptions import ImuCalibError
from imu_calib.utils.math_utils import as_vector3, check_matrix_well_conditioned, trapz_integral, validate_time_vector


def fit_gyro_C_from_angle_increment(gyro_runs: list[GyroRun], bg: np.ndarray) -> tuple[np.ndarray, dict]:
    """Fit gyroscope calibration matrix from steady-state angle increments."""
    if not gyro_runs:
        raise ImuCalibError("gyro_runs must not be empty.")

    bg = as_vector3(bg, "bg")
    num_runs = len(gyro_runs)
    A = np.zeros((3 * num_runs, 9), dtype=float)
    y = np.zeros(3 * num_runs, dtype=float)
    run_info = []

    for i, run in enumerate(gyro_runs):
        _validate_run(run, i)
        idx_ss = np.asarray(run.idx_ss, dtype=bool).reshape(-1)
        if np.count_nonzero(idx_ss) < 2:
            raise ImuCalibError(f"Run {i} steady-state segment must contain at least 2 samples.")
        t_ss = run.t[idx_ss]
        gyro_ss = run.gyro[idx_ss, :]
        dtheta_m = trapz_integral(t_ss, gyro_ss - bg[None, :])
        theta_ref = as_vector3(run.theta_ref, f"gyro_runs[{i}].theta_ref")
        rows = slice(3 * i, 3 * (i + 1))
        A[rows, :] = np.kron(theta_ref.reshape(1, 3), np.eye(3))
        y[rows] = dtheta_m
        run_info.append(
            {
                "axis": run.axis,
                "dir": run.dir,
                "num_ss_samples": int(np.count_nonzero(idx_ss)),
                "dtheta_m": dtheta_m,
                "theta_ref": theta_ref,
            }
        )

    if np.linalg.matrix_rank(A) < 9:
        raise ImuCalibError("The gyro least-squares system is rank deficient. Add runs around all axes.")

    x, *_ = np.linalg.lstsq(A, y, rcond=None)
    Cg = x.reshape(3, 3)
    cg_rcond = check_matrix_well_conditioned(Cg, "Cg")
    residual_vec = y - A @ x

    for info in run_info:
        dtheta_pred = Cg @ info["theta_ref"]
        residual = info["dtheta_m"] - dtheta_pred
        info["dtheta_pred"] = dtheta_pred
        info["residual"] = residual
        info["residual_norm"] = float(np.linalg.norm(residual))

    return Cg, {
        "num_runs": num_runs,
        "A_rank": int(np.linalg.matrix_rank(A)),
        "A_condition": float(np.linalg.cond(A)),
        "Cg_rcond": cg_rcond,
        "residual_vector": residual_vec,
        "residual_rms": float(np.sqrt(np.mean(residual_vec**2))),
        "max_abs_residual": float(np.max(np.abs(residual_vec))),
        "runs": run_info,
    }


def _validate_run(run: GyroRun, idx: int) -> None:
    validate_time_vector(run.t, f"gyro_runs[{idx}].t")
    gyro = np.asarray(run.gyro, dtype=float)
    if gyro.ndim != 2 or gyro.shape[1] != 3 or gyro.shape[0] != run.t.size:
        raise ImuCalibError(f"gyro_runs[{idx}].gyro must have shape (N, 3) matching time length.")
    idx_ss = np.asarray(run.idx_ss).reshape(-1)
    if idx_ss.size != run.t.size:
        raise ImuCalibError(f"gyro_runs[{idx}].idx_ss length must match time length.")
    if run.axis not in {"x", "y", "z"}:
        raise ImuCalibError(f'gyro_runs[{idx}].axis must be one of "x", "y", "z".')
    if int(run.dir) not in (-1, 1):
        raise ImuCalibError(f"gyro_runs[{idx}].dir must be +1 or -1.")
    as_vector3(run.theta_ref, f"gyro_runs[{idx}].theta_ref")
