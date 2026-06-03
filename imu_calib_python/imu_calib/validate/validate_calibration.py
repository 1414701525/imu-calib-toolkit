from __future__ import annotations

import numpy as np

from imu_calib.models.data_structures import ImuDataset
from imu_calib.runtime.apply_imu_calibration import apply_imu_calibration
from imu_calib.runtime.default_calib_options import default_calib_options
from imu_calib.runtime.result_summary import get_allan_status, get_temperature_model_status
from imu_calib.utils.math_utils import check_matrix_well_conditioned, trapz_integral
from imu_calib.utils.detect_steady_segments import detect_steady_segments


def validate_calibration(data: ImuDataset, calib: dict, options: dict | None = None, analysis: dict | None = None) -> dict:
    """Validate calibration outputs on the available dataset."""
    options = default_calib_options() if options is None else options
    analysis = {} if analysis is None else analysis
    ca_rcond = check_matrix_well_conditioned(np.asarray(calib["Ca"], dtype=float), "Ca")
    cg_rcond = check_matrix_well_conditioned(np.asarray(calib["Cg"], dtype=float), "Cg")

    raw_static = {"gyro": data.static.gyro, "acc": data.static.acc, "temp": data.static.temp}
    corrected_static = apply_imu_calibration(raw_static, calib, options=options)

    acc_norm_raw = np.linalg.norm(data.static.acc, axis=1)
    acc_norm_corr = np.linalg.norm(corrected_static["acc"], axis=1)
    gravity_value = calib.get("gravity_magnitude")
    if gravity_value is None:
        gravity_value = options["acc_calibration"]["gravity_magnitude"]
    g0_est = float(gravity_value)

    pose_checks = []
    for pose in data.acc_poses:
        acc_mean = np.asarray(pose.acc_mean, dtype=float).reshape(3)
        corrected = calib["Ca"] @ (acc_mean - np.asarray(calib["ba"], dtype=float).reshape(3))
        raw_norm = float(np.linalg.norm(acc_mean))
        corrected_norm = float(np.linalg.norm(corrected))
        legacy_residual = None
        legacy_residual_norm = np.nan
        if getattr(pose, "a_ref", None) is not None:
            a_ref = np.asarray(pose.a_ref, dtype=float).reshape(3)
            legacy_residual = acc_mean - (np.linalg.solve(calib["Ca"], a_ref) + calib["ba"])
            legacy_residual_norm = float(np.linalg.norm(legacy_residual))
        pose_checks.append(
            {
                "pose_name": pose.pose_name,
                "raw_mean": acc_mean,
                "corrected_mean": corrected,
                "raw_norm": raw_norm,
                "corrected_norm": corrected_norm,
                "norm_error_before": float(raw_norm - g0_est),
                "norm_error_after": float(corrected_norm - g0_est),
                "legacy_reference_residual": legacy_residual,
                "legacy_reference_residual_norm": legacy_residual_norm,
            }
        )

    gyro_checks = []
    acc_placeholder = np.tile(np.asarray(calib["ba"], dtype=float).reshape(1, 3), (1, 1))
    for run in data.gyro_runs:
        idx_ss, used_manual = _get_idx_ss(run, options)
        raw_run = {"gyro": run.gyro, "acc": np.tile(acc_placeholder, (run.gyro.shape[0], 1))}
        corrected_run = apply_imu_calibration(raw_run, calib, options=options)
        dtheta_raw = trapz_integral(run.t[idx_ss], run.gyro[idx_ss, :])
        dtheta_corrected = trapz_integral(run.t[idx_ss], corrected_run["gyro"][idx_ss, :])
        dtheta_pred = np.asarray(run.theta_ref, dtype=float)
        error_before = dtheta_raw - dtheta_pred
        error_after = dtheta_corrected - dtheta_pred
        gyro_checks.append(
            {
                "axis": run.axis,
                "dir": run.dir,
                "dtheta_raw": dtheta_raw,
                "dtheta_corrected": dtheta_corrected,
                "dtheta_pred": dtheta_pred,
                "error_before": error_before,
                "error_after": error_after,
                "residual_norm_before": float(np.linalg.norm(error_before)),
                "residual_norm_after": float(np.linalg.norm(error_after)),
                "used_manual_idx_ss": used_manual,
            }
        )

    if data.gsens_runs:
        before_rms, after_rms, message = _validate_gsens_residuals(data, calib, options)
    else:
        before_rms, after_rms, message = np.nan, np.nan, "No gsens_runs available for residual comparison."

    gyro_before = np.array([item["residual_norm_before"] for item in gyro_checks], dtype=float)
    gyro_after = np.array([item["residual_norm_after"] for item in gyro_checks], dtype=float)
    pose_norm_before = np.abs(np.array([item["norm_error_before"] for item in pose_checks], dtype=float))
    pose_norm_after = np.abs(np.array([item["norm_error_after"] for item in pose_checks], dtype=float))

    return {
        "static": {
            "gyro_raw_mean": data.static.gyro.mean(axis=0),
            "gyro_debiased": corrected_static["bias_removed_gyro"],
            "gyro_mean_after_bias": corrected_static["bias_removed_gyro"].mean(axis=0),
            "gyro_std_after_bias": corrected_static["bias_removed_gyro"].std(axis=0, ddof=0),
            "gyro_rms_after_bias": np.sqrt(np.mean(corrected_static["bias_removed_gyro"] ** 2, axis=0)),
            "acc_raw": data.static.acc,
            "acc_corrected": corrected_static["acc"],
            "acc_norm_raw": acc_norm_raw,
            "acc_norm": acc_norm_corr,
            "acc_norm_mean_before": float(np.mean(acc_norm_raw)),
            "acc_norm_mean_after": float(np.mean(acc_norm_corr)),
            "acc_norm_std_before": float(np.std(acc_norm_raw, ddof=0)),
            "acc_norm_std_after": float(np.std(acc_norm_corr, ddof=0)),
            "acc_norm_error_mean": float(np.mean(acc_norm_corr - g0_est)),
            "gravity_magnitude": g0_est,
        },
        "acc_poses": pose_checks,
        "gyro_runs": gyro_checks,
        "gsens": {
            "residual_rms_before": before_rms,
            "residual_rms_after": after_rms,
            "message": message,
        },
        "analysis": analysis,
        "summary": {
            "num_acc_poses": len(data.acc_poses),
            "num_gyro_runs": len(data.gyro_runs),
            "Ca_rcond": ca_rcond,
            "Cg_rcond": cg_rcond,
            "static_gyro_mean_after_bias": corrected_static["bias_removed_gyro"].mean(axis=0),
            "static_gyro_rms_after_bias": np.sqrt(np.mean(corrected_static["bias_removed_gyro"] ** 2, axis=0)),
            "static_acc_norm_mean_before": float(np.mean(acc_norm_raw)),
            "static_acc_norm_mean_after": float(np.mean(acc_norm_corr)),
            "static_acc_norm_std_before": float(np.std(acc_norm_raw, ddof=0)),
            "static_acc_norm_std_after": float(np.std(acc_norm_corr, ddof=0)),
            "static_acc_norm_error_mean": float(np.mean(acc_norm_corr - g0_est)),
            "acc_pose_norm_error_mean_before": float(np.mean(pose_norm_before)),
            "acc_pose_norm_error_std_before": float(np.std(pose_norm_before, ddof=0)),
            "acc_pose_norm_error_max_before": float(np.max(pose_norm_before)),
            "acc_pose_norm_error_mean_after": float(np.mean(pose_norm_after)),
            "acc_pose_norm_error_std_after": float(np.std(pose_norm_after, ddof=0)),
            "acc_pose_norm_error_max_after": float(np.max(pose_norm_after)),
            "gyro_dtheta_residual_rms_before": float(np.sqrt(np.mean(gyro_before**2))),
            "gyro_dtheta_residual_rms_after": float(np.sqrt(np.mean(gyro_after**2))),
            "gyro_dtheta_residual_max_after": float(np.max(gyro_after)),
            "gsens_residual_rms_before": before_rms,
            "gsens_residual_rms_after": after_rms,
            "temperature_model_status": get_temperature_model_status(calib.get("temp")),
            "allan_status": get_allan_status(analysis),
        },
    }


def _validate_gsens_residuals(data: ImuDataset, calib: dict, options: dict) -> tuple[float, float, str]:
    before = []
    after = []
    for run in data.gsens_runs:
        omega_ref = np.zeros_like(run.gyro) if run.omega_ref is None else run.omega_ref
        residual_before = (run.gyro - calib["bg"][None, :]) - (calib["Cg"] @ omega_ref.T).T
        before.append(residual_before)
        if options["gsens"]["enabled"] and calib.get("Gg") is not None:
            residual_after = residual_before - (calib["Gg"] @ run.acc_ref.T).T
        else:
            residual_after = residual_before
        after.append(residual_after)
    before_all = np.vstack(before)
    after_all = np.vstack(after)
    return (
        float(np.sqrt(np.mean(before_all**2))),
        float(np.sqrt(np.mean(after_all**2))),
        "Compared gsens residual RMS before and after Gg compensation.",
    )


def _get_idx_ss(run, options: dict) -> tuple[np.ndarray, bool]:
    use_manual_first = options["segmentation"]["use_manual_idx_ss_first"]
    reestimate = options["segmentation"]["reestimate_idx_ss"]
    if run.idx_ss is not None and np.asarray(run.idx_ss).size and use_manual_first and not reestimate:
        return np.asarray(run.idx_ss, dtype=bool), True

    detected = detect_steady_segments(
        run.t,
        run.gyro,
        steady_window_sec=options["segmentation"]["steady_window_sec"],
        gyro_norm_threshold=options["segmentation"]["gyro_norm_threshold"],
        gyro_std_threshold=options["segmentation"]["gyro_std_threshold"],
        min_segment_sec=options["segmentation"]["min_segment_sec"],
    )
    idx_ss = detected["mask"]
    if np.count_nonzero(idx_ss) < 2 and run.idx_ss is not None and np.asarray(run.idx_ss).size:
        return np.asarray(run.idx_ss, dtype=bool), True
    return idx_ss, False
