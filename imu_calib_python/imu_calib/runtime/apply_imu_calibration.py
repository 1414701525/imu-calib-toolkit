from __future__ import annotations

import numpy as np

from imu_calib.runtime.get_accel_bias_from_temperature import get_accel_bias_from_temperature
from imu_calib.runtime.default_calib_options import default_calib_options
from imu_calib.runtime.get_gyro_bias_from_temperature import get_gyro_bias_from_temperature
from imu_calib.utils.exceptions import ImuCalibError
from imu_calib.utils.math_utils import check_matrix_well_conditioned


def apply_imu_calibration(raw_data: dict, calib_param: dict, options: dict | None = None) -> dict:
    """Apply inverse IMU calibration using the project-compatible model.

    Forward / inverse models:
    - a_corr = Ca * (a_raw - ba(T))
    - omega_m = Cg * omega_ref + bg(T) + Gg * f_term + n_g

    Runtime compensation:
    - a_corr = Ca * (a_raw - ba(T))
    - omega_ref_hat = solve(Cg, omega_m - bg(T) - Gg * f_term)
    """

    options = default_calib_options() if options is None else options
    _validate_raw(raw_data)
    _validate_calib(calib_param)

    gyro = np.asarray(raw_data["gyro"], dtype=float)
    acc = np.asarray(raw_data["acc"], dtype=float)
    bg = np.asarray(calib_param["bg"], dtype=float).reshape(3)
    ba = np.asarray(calib_param["ba"], dtype=float).reshape(3)
    Ca = np.asarray(calib_param["Ca"], dtype=float)
    Cg = np.asarray(calib_param["Cg"], dtype=float)
    Gg_raw = calib_param.get("Gg", np.zeros((3, 3)))
    has_Gg = Gg_raw is not None and np.asarray(Gg_raw).size != 0
    Gg = np.zeros((3, 3), dtype=float) if not has_Gg else np.asarray(Gg_raw, dtype=float)

    temp_vector = None
    if "temp" in raw_data and raw_data["temp"] is not None:
        temp_vector = np.asarray(raw_data["temp"], dtype=float).reshape(-1)
        if temp_vector.size != gyro.shape[0]:
            raise ImuCalibError("raw_data['temp'] length must match gyro sample count.")

    temp_models = calib_param.get("temp") if isinstance(calib_param.get("temp"), dict) else {}
    bg_model = temp_models.get("bg_model") if isinstance(temp_models, dict) else None
    ba_model = temp_models.get("ba_model") if isinstance(temp_models, dict) else None

    baT, acc_temp_info = get_accel_bias_from_temperature(temp_vector, ba, ba_model)
    if baT.shape[0] == 1 and acc.shape[0] > 1:
        baT = np.tile(baT, (acc.shape[0], 1))
    acc_bias_removed = acc - baT
    acc_calibrated = (Ca @ acc_bias_removed.T).T

    if isinstance(calib_param.get("temp"), dict):
        bg_model = calib_param["temp"].get("bg_model")
    bgT, temp_info = get_gyro_bias_from_temperature(temp_vector, bg, bg_model)
    if bgT.shape[0] == 1 and gyro.shape[0] > 1:
        bgT = np.tile(bgT, (gyro.shape[0], 1))

    gyro_bias_removed = gyro - bgT
    f_term = acc_calibrated
    g_term = np.zeros_like(gyro_bias_removed)
    gsens_info = {
        "applied": False,
        "message": "Gg compensation disabled or unavailable.",
    }
    if options["gsens"]["enabled"] and has_Gg:
        g_term = (Gg @ f_term.T).T
        gsens_info = {
            "applied": True,
            "message": "Applied Gg compensation using calibrated accelerometer as f_term.",
        }

    gyro_model_removed = gyro_bias_removed - g_term
    gyro_calibrated = np.linalg.solve(Cg, gyro_model_removed.T).T

    return {
        "raw": raw_data,
        "acc": acc_calibrated,
        "gyro": gyro_calibrated,
        "bias_removed_gyro": gyro_bias_removed,
        "gsens_removed_gyro": gyro_model_removed,
        "bgT": bgT,
        "baT": baT,
        "f_term": f_term,
        "g_term": g_term,
        "model": {
            "forward_gyro": options["model"]["forward_gyro"],
            "inverse_gyro": options["model"]["inverse_gyro"],
            "forward_acc": options["model"]["forward_acc"],
            "inverse_acc": options["model"]["inverse_acc"],
            "gsens_term": options["model"]["gsens_term"],
        },
        "info": {
            "temperature": {
                "gyro": temp_info,
                "acc": acc_temp_info,
            },
            "gsens": gsens_info,
            "notes": "Accelerometer compensation uses Ca * (a_raw - ba(T)); gyro compensation uses solve(Cg, ...).",
        },
    }


def _validate_raw(raw: dict) -> None:
    for key in ("gyro", "acc"):
        if key not in raw:
            raise ImuCalibError(f'raw_data is missing required field "{key}".')
    gyro = np.asarray(raw["gyro"], dtype=float)
    acc = np.asarray(raw["acc"], dtype=float)
    if gyro.ndim != 2 or gyro.shape[1] != 3:
        raise ImuCalibError("raw_data['gyro'] must have shape (N, 3).")
    if acc.ndim != 2 or acc.shape != gyro.shape:
        raise ImuCalibError("raw_data['acc'] must have the same shape as raw_data['gyro'].")


def _validate_calib(calib: dict) -> None:
    for key in ("bg", "Ca", "ba", "Cg"):
        if key not in calib:
            raise ImuCalibError(f'calib_param is missing required field "{key}".')
    check_matrix_well_conditioned(np.asarray(calib["Ca"], dtype=float), "Ca")
    check_matrix_well_conditioned(np.asarray(calib["Cg"], dtype=float), "Cg")
