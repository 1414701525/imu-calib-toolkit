from __future__ import annotations

import numpy as np

from imu_calib.runtime.result_summary import get_allan_status, get_temperature_model_status


def print_calibration_summary(results) -> None:
    """Print a concise, MATLAB-aligned calibration summary."""

    print("\nCalibration Summary")
    print("-------------------")
    print(f"Forward gyro model : {results.model['forward']['gyr']}")
    print(f"Inverse gyro model : {results.model['inverse']['gyr']}")
    print(f"Inverse acc model  : {results.model['inverse']['acc']}")
    print(f"Gg input term      : {results.model['gsens_term']}")

    bg = results.calib.get("bg")
    if bg is not None:
        print(f"bg [rad/s] : {_fmt_vec(bg)}")

    acc = results.calib.get("acc", {})
    if acc.get("ba") is not None:
        print(f"ba [m/s^2] : {_fmt_vec(acc['ba'])}")
    if acc.get("gravity_magnitude") is not None:
        print(f"gravity [m/s^2] : {float(acc['gravity_magnitude']):.6g}")
    if acc.get("Ca") is not None:
        print("Ca summary :")
        print(np.asarray(acc["Ca"]))
        print(f"rcond(Ca) : {_safe_rcond(acc['Ca']):.3e}")
    if acc.get("Sa") is not None:
        print("Sa summary :")
        print(np.asarray(acc["Sa"]))
    if acc.get("Ma") is not None:
        print("Ma summary :")
        print(np.asarray(acc["Ma"]))

    gyr = results.calib.get("gyr", {})
    if gyr.get("Cg") is not None:
        print("Cg summary :")
        print(np.asarray(gyr["Cg"]))
        print(f"rcond(Cg) : {_safe_rcond(gyr['Cg']):.3e}")
    if gyr.get("Kg") is not None:
        print("Kg summary :")
        print(np.asarray(gyr["Kg"]))
    if gyr.get("Mg") is not None:
        print("Mg summary :")
        print(np.asarray(gyr["Mg"]))
    if gyr.get("Gg") is not None:
        print("Gg summary :")
        print(np.asarray(gyr["Gg"]))

    summary = results.validation.get("summary", {}) if isinstance(results.validation, dict) else {}
    if summary:
        print("\nValidation summary:")
        _print_summary(summary)

    temp_block = results.calib.get("temp", {})
    if isinstance(temp_block, dict) and temp_block:
        _print_temperature_model_summary(temp_block)

    allan = results.analysis.get("allan") if isinstance(results.analysis, dict) else None
    if isinstance(allan, dict) and allan:
        print("\nAllan summary:")
        if isinstance(allan.get("gyro"), dict):
            _print_allan_block("gyro", allan["gyro"])
        if isinstance(allan.get("acc"), dict):
            _print_allan_block("acc", allan["acc"])

    print(f"\nAllan enabled      : {int(bool(results.options['pipeline'].get('enable_allan', False)))}")
    print(f"Temp model enabled : {int(bool(results.options['pipeline'].get('enable_temperature_model', False)))}")
    print(f"Auto segment       : {int(bool(results.options['pipeline'].get('enable_auto_segment', False)))}")
    if summary:
        print(f"Summary temp state : {get_temperature_model_status(temp_block)}")
        print(f"Summary Allan state: {get_allan_status(results.analysis)}")


def _print_summary(summary: dict) -> None:
    if "mode" in summary:
        print(f"  mode                            : {summary['mode']}")
    if "num_static_samples" in summary:
        print(f"  num_static_samples              : {summary['num_static_samples']}")
    if "available_blocks" in summary:
        print(f"  available_blocks                : {summary['available_blocks']}")
    if "completed_modules" in summary:
        print(f"  completed_modules               : {summary['completed_modules']}")
    if summary.get("static_gyro_mean_after_bias") is not None:
        print(f"  static_gyro_mean_after_bias     : {_fmt_vec(summary.get('static_gyro_mean_after_bias'))}")
    if summary.get("static_gyro_rms_after_bias") is not None:
        print(f"  static_gyro_rms_after_bias      : {_fmt_vec(summary.get('static_gyro_rms_after_bias'))}")
    if "static_acc_norm_mean" in summary and summary.get("static_acc_norm_mean") is not None:
        print(f"  static_acc_norm_mean            : {summary['static_acc_norm_mean']:.6g}")
    if "static_acc_norm_std" in summary and summary.get("static_acc_norm_std") is not None:
        print(f"  static_acc_norm_std             : {summary['static_acc_norm_std']:.6g}")
    if summary.get("gyro_std") is not None:
        print(f"  gyro_std [rad/s]                : {_fmt_vec(summary.get('gyro_std'))}")
    if summary.get("acc_std") is not None:
        print(f"  acc_std [m/s^2]                 : {_fmt_vec(summary.get('acc_std'))}")
    if "temperature_model_status" in summary:
        print(f"  temperature_model_status        : {summary['temperature_model_status']}")
    if "allan_status" in summary:
        print(f"  allan_status                    : {summary['allan_status']}")
    if "Ca_rcond" in summary and summary.get("Ca_rcond") is not None:
        print(f"  rcond(Ca)                       : {summary['Ca_rcond']:.3e}")
    if "Cg_rcond" in summary and summary.get("Cg_rcond") is not None:
        print(f"  rcond(Cg)                       : {summary['Cg_rcond']:.3e}")


def _print_allan_block(name: str, block: dict) -> None:
    estimate = block.get("estimate", {}) if isinstance(block.get("estimate"), dict) else {}
    print(f"  {name}:")
    print(f"    valid                        : {int(bool(block.get('valid', False)))}")
    print(f"    confidence                   : {estimate.get('confidence', block.get('confidence', 'n/a'))}")
    print(f"    num_samples                  : {block.get('num_samples', 0)}")
    tau = block.get("tau")
    if tau is not None and len(np.asarray(tau).reshape(-1)) > 0:
        tau = np.asarray(tau, dtype=float).reshape(-1)
        print(f"    tau range [s]                : {tau[0]:.6g} -> {tau[-1]:.6g}")
    if "noise_density" in estimate:
        print(f"    noise_density                : {_fmt_vec(estimate.get('noise_density'))}")
    if "bias_instability" in estimate:
        print(f"    bias_instability             : {_fmt_vec(estimate.get('bias_instability'))}")
    if "random_walk" in estimate:
        print(f"    random_walk                  : {_fmt_vec(estimate.get('random_walk'))}")
    if "message" in block:
        print(f"    message                      : {block.get('message', '')}")


def _print_temperature_model_summary(temp_block: dict) -> None:
    model_file = temp_block.get("model_file", temp_block.get("modelFile", {}))
    if not isinstance(model_file, dict):
        model_file = {}
    if model_file:
        print("\nTemperature model summary:")
        print(f"  reference_temperature   : {_fmt_scalar(model_file.get('reference_temperature'))}")
        print(f"  temperature_range       : {_fmt_range(model_file.get('temperature_range'))}")
        print(f"  extrapolation_mode      : {model_file.get('extrapolation_mode', '')}")
    for label, model in (
        ("gyro", temp_block.get("bg_model", temp_block.get("bgModel"))),
        ("acc", temp_block.get("ba_model", temp_block.get("baModel"))),
    ):
        if isinstance(model, dict) and model:
            print(f"  {label}:")
            print(f"    valid                        : {int(bool(model.get('valid', False)))}")
            print(f"    low_confidence               : {int(bool(model.get('low_confidence', False)))}")
            print(f"    method                       : {model.get('method', '')}")
            print(f"    type                         : {model.get('type', '')}")
            metrics = model.get("metrics", {}) if isinstance(model.get("metrics"), dict) else {}
            print(f"    temp_span                    : {_fmt_scalar(metrics.get('temp_span'))}")
            print(f"    num_points                   : {metrics.get('num_points', 0)}")
            print(f"    num_bins                     : {metrics.get('num_bins', 0)}")
            print(f"    rmse                         : {_fmt_scalar(metrics.get('rmse'))}")
            print(f"    max_abs_residual             : {_fmt_scalar(metrics.get('max_abs_residual'))}")
            if label == "gyro":
                print(f"    reference_bg [rad/s]         : {_fmt_vec(model.get('reference_bg'))}")
                print(f"    residual_rms [rad/s]         : {_fmt_vec(model.get('residual_rms'))}")
            else:
                print(f"    reference_ba [m/s^2]         : {_fmt_vec(model.get('reference_ba'))}")
                print(f"    residual_rms [m/s^2]         : {_fmt_vec(model.get('residual_rms'))}")
            print(f"    message                      : {model.get('message', '')}")


def _safe_rcond(matrix) -> float:
    arr = np.asarray(matrix, dtype=float)
    return float(1.0 / np.linalg.cond(arr))


def _fmt_vec(value) -> str:
    if value is None:
        return "[]"
    arr = np.asarray(value, dtype=float).reshape(-1)
    if arr.size == 0:
        return "[]"
    return "[" + ", ".join(f"{x:.6g}" for x in arr) + "]"


def _fmt_scalar(value) -> str:
    if value is None:
        return "n/a"
    try:
        scalar = float(value)
    except Exception:
        return str(value)
    if np.isnan(scalar):
        return "nan"
    return f"{scalar:.6g}"


def _fmt_range(value) -> str:
    if not isinstance(value, (list, tuple)) or len(value) != 2:
        return "[]"
    return "[" + ", ".join(_fmt_scalar(item) for item in value) + "]"
