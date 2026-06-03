from __future__ import annotations

import numpy as np
from scipy.optimize import least_squares

from imu_calib.models.data_structures import AccPose
from imu_calib.runtime.default_calib_options import default_calib_options
from imu_calib.utils.exceptions import ImuCalibError
from imu_calib.utils.math_utils import as_vector3, check_matrix_well_conditioned


def fit_acc_multi_pose(
    acc_poses: list[AccPose],
    *,
    gravity_magnitude: float | None = None,
    options: dict | None = None,
) -> tuple[np.ndarray, np.ndarray, dict]:
    """Fit accelerometer compensation matrix and bias from static pose means.

    New calibration model:
        a_corr_i = C * (a_raw_i - b)

    Static multi-pose constraint:
        ||a_corr_i|| = g

    To avoid the rotational ambiguity of a fully free 3x3 matrix under norm-only
    constraints, the default parameterization uses:
        C = S * M
    where:
        S = diag(sx, sy, sz), sx/sy/sz > 0
        M = [[1, mxy, mxz],
             [0, 1,  myz],
             [0, 0,  1  ]]

    Legacy reference vectors a_ref are no longer required. If they are present,
    they are only used as an initialization aid for migration compatibility.
    """

    if not acc_poses:
        raise ImuCalibError("acc_poses must not be empty.")

    options = default_calib_options() if options is None else options
    acc_opts = options["acc_calibration"]
    g = float(acc_opts["gravity_magnitude"] if gravity_magnitude is None else gravity_magnitude)
    if g <= 0.0:
        raise ImuCalibError("gravity_magnitude must be positive.")

    raw_means = np.vstack([as_vector3(pose.acc_mean, f"acc_poses[{i}].acc_mean") for i, pose in enumerate(acc_poses)])
    num_poses = raw_means.shape[0]
    parameterization, warnings = _resolve_parameterization(num_poses, acc_opts)

    x0, init_info = _build_initial_guess(acc_poses, raw_means, g, parameterization, acc_opts)
    bounds = _build_bounds(parameterization)
    result = least_squares(
        _norm_constraint_residuals,
        x0=x0,
        bounds=bounds,
        method=acc_opts["optimizer_method"],
        loss=acc_opts["optimizer_loss"],
        max_nfev=int(acc_opts["max_nfev"]),
        ftol=float(acc_opts["ftol"]),
        xtol=float(acc_opts["xtol"]),
        gtol=float(acc_opts["gtol"]),
        args=(raw_means, g, parameterization),
    )

    ba, Ca, Sa, Ma = _unpack_parameters(result.x, parameterization)
    ca_rcond = check_matrix_well_conditioned(Ca, "Ca")

    corrected = (Ca @ (raw_means - ba[None, :]).T).T
    raw_norms = np.linalg.norm(raw_means, axis=1)
    corrected_norms = np.linalg.norm(corrected, axis=1)
    norm_error_before = raw_norms - g
    norm_error_after = corrected_norms - g

    pose_metrics = []
    for pose, raw_vec, corr_vec, err_before, err_after in zip(
        acc_poses, raw_means, corrected, norm_error_before, norm_error_after
    ):
        pose_metrics.append(
            {
                "pose_name": pose.pose_name,
                "raw_mean": raw_vec,
                "corrected_mean": corr_vec,
                "raw_norm": float(np.linalg.norm(raw_vec)),
                "corrected_norm": float(np.linalg.norm(corr_vec)),
                "norm_error_before": float(err_before),
                "norm_error_after": float(err_after),
                "legacy_reference_available": pose.a_ref is not None,
            }
        )

    info = {
        "method": "static_multi_pose_gravity_constraint",
        "parameterization": parameterization,
        "num_poses": int(num_poses),
        "gravity_magnitude": g,
        "optimizer_success": bool(result.success),
        "optimizer_status": int(result.status),
        "optimizer_message": result.message,
        "num_function_evals": int(result.nfev),
        "final_cost": float(result.cost),
        "optimality": float(result.optimality),
        "Ca_rcond": ca_rcond,
        "Sa": Sa,
        "Ma": Ma,
        "residual_vector": result.fun,
        "residual_rms": float(np.sqrt(np.mean(result.fun**2))) if result.fun.size else 0.0,
        "max_abs_residual": float(np.max(np.abs(result.fun))) if result.fun.size else 0.0,
        "raw_norm_mean": float(np.mean(raw_norms)),
        "raw_norm_std": float(np.std(raw_norms, ddof=0)),
        "corrected_norm_mean": float(np.mean(corrected_norms)),
        "corrected_norm_std": float(np.std(corrected_norms, ddof=0)),
        "norm_error_mean_before": float(np.mean(np.abs(norm_error_before))),
        "norm_error_std_before": float(np.std(np.abs(norm_error_before), ddof=0)),
        "norm_error_max_before": float(np.max(np.abs(norm_error_before))),
        "norm_error_mean_after": float(np.mean(np.abs(norm_error_after))),
        "norm_error_std_after": float(np.std(np.abs(norm_error_after), ddof=0)),
        "norm_error_max_after": float(np.max(np.abs(norm_error_after))),
        "poseMetrics": pose_metrics,
        "initialization": init_info,
        "warnings": warnings,
    }
    return Ca, ba, info


def _resolve_parameterization(num_poses: int, acc_opts: dict) -> tuple[str, list[str]]:
    requested = str(acc_opts["parameterization"])
    min_full = int(acc_opts["min_pose_count_full"])
    min_diag = int(acc_opts["min_pose_count_diag_only"])
    warnings: list[str] = []

    if requested == "diag_only":
        if num_poses < min_diag:
            raise ImuCalibError(
                f"At least {min_diag} static pose means are required for diag_only accelerometer calibration."
            )
        return "diag_only", warnings

    if requested != "scale_misalignment":
        raise ImuCalibError(f'Unsupported accelerometer parameterization "{requested}".')

    if num_poses >= min_full:
        return "scale_misalignment", warnings

    if bool(acc_opts.get("fallback_to_diag_only", True)) and num_poses >= min_diag:
        warnings.append(
            "Not enough pose means for full scale+misalignment fit; automatically fell back to diag_only."
        )
        return "diag_only", warnings

    raise ImuCalibError(
        f"At least {min_full} static pose means are required for scale_misalignment accelerometer calibration."
    )


def _build_initial_guess(
    acc_poses: list[AccPose],
    raw_means: np.ndarray,
    gravity_magnitude: float,
    parameterization: str,
    acc_opts: dict,
) -> tuple[np.ndarray, dict]:
    init_info = {
        "source": "range_based",
        "legacy_reference_init_used": False,
        "legacy_reference_available": False,
    }

    b0 = 0.5 * (np.max(raw_means, axis=0) + np.min(raw_means, axis=0))
    half_range = 0.5 * (np.max(raw_means, axis=0) - np.min(raw_means, axis=0))
    half_range = np.maximum(half_range, 1.0e-3)
    s0 = gravity_magnitude / half_range
    m0 = np.zeros(3, dtype=float)

    legacy_refs = [pose.a_ref for pose in acc_poses]
    if bool(acc_opts.get("use_legacy_reference_init", True)) and all(ref is not None for ref in legacy_refs):
        legacy = _legacy_reference_initial_guess(acc_poses)
        if legacy is not None:
            b0, s0, m0 = legacy
            init_info["source"] = "legacy_reference_linear_init"
            init_info["legacy_reference_init_used"] = True
            init_info["legacy_reference_available"] = True
    elif any(ref is not None for ref in legacy_refs):
        init_info["legacy_reference_available"] = True

    log_s0 = np.log(np.maximum(s0, 1.0e-6))
    if parameterization == "diag_only":
        x0 = np.r_[b0, log_s0]
    else:
        x0 = np.r_[b0, log_s0, m0]
    return x0, init_info


def _legacy_reference_initial_guess(acc_poses: list[AccPose]) -> tuple[np.ndarray, np.ndarray, np.ndarray] | None:
    try:
        num_poses = len(acc_poses)
        A = np.zeros((3 * num_poses, 12), dtype=float)
        y = np.zeros(3 * num_poses, dtype=float)
        for i, pose in enumerate(acc_poses):
            acc_mean = as_vector3(pose.acc_mean, f"acc_poses[{i}].acc_mean")
            a_ref = as_vector3(pose.a_ref, f"acc_poses[{i}].a_ref")
            rows = slice(3 * i, 3 * (i + 1))
            A[rows, :] = np.hstack([np.kron(a_ref.reshape(1, 3), np.eye(3)), np.eye(3)])
            y[rows] = acc_mean
        if np.linalg.matrix_rank(A) < 12:
            return None
        x, *_ = np.linalg.lstsq(A, y, rcond=None)
        Ca_forward = x[:9].reshape(3, 3)
        ba = x[9:12]
        if not np.all(np.isfinite(Ca_forward)) or not np.all(np.isfinite(ba)):
            return None
        C_init = np.linalg.solve(Ca_forward, np.eye(3))
        diag = np.diag(C_init)
        diag = np.where(np.abs(diag) < 1.0e-6, np.sign(diag) * 1.0e-6 + (diag == 0) * 1.0e-6, diag)
        s0 = np.abs(diag)
        m0 = np.array(
            [
                C_init[0, 1] / s0[0],
                C_init[0, 2] / s0[0],
                C_init[1, 2] / s0[1],
            ],
            dtype=float,
        )
        return ba, s0, m0
    except Exception:  # noqa: BLE001 - initialization should fail softly
        return None


def _build_bounds(parameterization: str) -> tuple[np.ndarray, np.ndarray]:
    if parameterization == "diag_only":
        lower = np.array([-np.inf, -np.inf, -np.inf, -6.0, -6.0, -6.0], dtype=float)
        upper = np.array([np.inf, np.inf, np.inf, 6.0, 6.0, 6.0], dtype=float)
        return lower, upper

    lower = np.array([-np.inf, -np.inf, -np.inf, -6.0, -6.0, -6.0, -0.5, -0.5, -0.5], dtype=float)
    upper = np.array([np.inf, np.inf, np.inf, 6.0, 6.0, 6.0, 0.5, 0.5, 0.5], dtype=float)
    return lower, upper


def _norm_constraint_residuals(theta: np.ndarray, raw_means: np.ndarray, gravity_magnitude: float, parameterization: str) -> np.ndarray:
    b, C, _, _ = _unpack_parameters(theta, parameterization)
    corrected = (C @ (raw_means - b[None, :]).T).T
    return np.linalg.norm(corrected, axis=1) - gravity_magnitude


def _unpack_parameters(theta: np.ndarray, parameterization: str) -> tuple[np.ndarray, np.ndarray, np.ndarray, np.ndarray]:
    theta = np.asarray(theta, dtype=float).reshape(-1)
    ba = theta[:3]
    scales = np.exp(theta[3:6])
    Sa = np.diag(scales)
    Ma = np.eye(3, dtype=float)
    if parameterization == "scale_misalignment":
        Ma[0, 1] = theta[6]
        Ma[0, 2] = theta[7]
        Ma[1, 2] = theta[8]
    elif parameterization != "diag_only":
        raise ImuCalibError(f'Unsupported accelerometer parameterization "{parameterization}".')
    Ca = Sa @ Ma
    return ba, Ca, Sa, Ma
