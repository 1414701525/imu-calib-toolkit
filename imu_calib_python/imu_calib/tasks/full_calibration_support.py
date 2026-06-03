from __future__ import annotations

import numpy as np

from imu_calib.runtime.result_summary import get_allan_status, get_temperature_model_status


def nested_or_default(obj: dict, path: list[str], default):
    current = obj
    for part in path:
        if not isinstance(current, dict) or part not in current:
            return default
        current = current[part]
    return current


def build_partial_validation(data, components: dict, analysis: dict, temp_info: dict) -> dict:
    result = {
        "message": (
            "Partial dataset detected. Only modules with satisfied minimum inputs were run. "
            "See task results and warnings for unavailable modules."
        ),
        "static": {},
        "analysis": analysis,
    }

    static = data.static if getattr(data, "static", None) is not None else None
    bg = components.get("bg")
    noise_stats = components.get("noise_stats", {})

    if static is not None and static.gyro.size:
        result["static"]["gyro_raw_mean"] = static.gyro.mean(axis=0)
        if bg is not None:
            gyro_debiased = static.gyro - np.asarray(bg, dtype=float)[None, :]
            result["static"]["gyro_mean_after_bias"] = gyro_debiased.mean(axis=0)
            result["static"]["gyro_rms_after_bias"] = np.sqrt(np.mean(gyro_debiased**2, axis=0))
            result["static"]["gyro_debiased"] = gyro_debiased
        else:
            result["static"]["gyro_mean_after_bias"] = None
            result["static"]["gyro_rms_after_bias"] = None
    else:
        result["static"]["gyro_raw_mean"] = None
        result["static"]["gyro_mean_after_bias"] = None
        result["static"]["gyro_rms_after_bias"] = None

    if static is not None and static.acc.size:
        result["static"]["acc_norm_raw"] = np.linalg.norm(static.acc, axis=1)
    else:
        result["static"]["acc_norm_raw"] = None

    summary = {
        "mode": "partial",
        "num_static_samples": 0 if static is None else int(static.gyro.shape[0]),
        "static_gyro_mean_after_bias": result["static"]["gyro_mean_after_bias"],
        "static_gyro_rms_after_bias": result["static"]["gyro_rms_after_bias"],
        "static_acc_norm_mean": None,
        "static_acc_norm_std": None,
        "gyro_std": noise_stats.get("gyro_std"),
        "acc_std": noise_stats.get("acc_std"),
        "available_blocks": getattr(data, "meta", {}).get("available_blocks", []),
        "completed_modules": get_completed_modules(components, analysis, temp_info),
        "temperature_model_status": get_temperature_model_status(temp_info),
        "allan_status": get_allan_status(analysis),
    }
    if result["static"]["acc_norm_raw"] is not None:
        summary["static_acc_norm_mean"] = float(np.mean(result["static"]["acc_norm_raw"]))
        summary["static_acc_norm_std"] = float(np.std(result["static"]["acc_norm_raw"], ddof=0))

    result["summary"] = summary
    return result


def get_completed_modules(components: dict, analysis: dict, temp_info: dict) -> list[str]:
    modules: list[str] = []
    if components.get("bg") is not None:
        modules.append("gyro_bias")
    if components.get("noise_stats"):
        modules.append("noise_stats")
    if components.get("Ca") is not None:
        modules.append("acc_calibration")
    if components.get("Cg") is not None:
        modules.append("gyro_calibration")
    if components.get("Gg") is not None:
        modules.append("gsens_fit")
    if get_allan_status(analysis) == "available":
        modules.append("allan_analysis")
    if get_temperature_model_status(temp_info) in {"bg_model=valid", "ba_model=valid"}:
        modules.append("temperature_fit")
    elif get_temperature_model_status(temp_info) not in {"", "not_available"}:
        modules.append("temperature_fit")
    return modules
