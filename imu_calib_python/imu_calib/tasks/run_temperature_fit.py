from __future__ import annotations

from dataclasses import is_dataclass

from imu_calib.calib.fit_temperature_bias_model import (
    fit_accel_temperature_bias_model,
    fit_gyro_temperature_bias_model,
    fit_temperature_bias_models,
)
from imu_calib.runtime.default_calib_options import default_calib_options
from imu_calib.tasks.make_task_result import make_task_result


def run_temperature_fit(
    input_data,
    *,
    target: str | None = None,
    Ca=None,
    ba=None,
    options: dict | None = None,
    **kwargs,
) -> dict:
    """Run temperature fitting for gyro-only, accel-only, or both."""

    options = default_calib_options() if options is None else options
    temp_opts = options["temperature"]
    target = str(temp_opts["target"] if target is None else target).lower()
    static = _normalize_static_input(input_data)

    fit_gyro = target in {"bg", "gyro", "both"}
    fit_acc = target in {"ba", "acc", "accel", "acceleration", "both"}

    missing: list[str] = []
    if static is None or getattr(static, "temp", None) is None or len(static.temp) == 0:
        missing.append("static.temp")
    if fit_gyro and (static is None or getattr(static, "gyro", None) is None or len(static.gyro) == 0):
        missing.append("static.gyro")
    if fit_acc:
        if static is None or getattr(static, "acc", None) is None or len(static.acc) == 0:
            missing.append("static.acc")
        if Ca is None:
            missing.append("Ca")

    if missing:
        return make_task_result(
            False,
            "Temperature fitting inputs are incomplete for the requested target.",
            None,
            missing_inputs=sorted(set(missing)),
            meta={"task_name": "run_temperature_fit", "target": target},
        )

    common_kwargs = {
        "method": kwargs.get("method", temp_opts["method"]),
        "reference_temperature_mode": kwargs.get("reference_temperature_mode", temp_opts["reference_temperature_mode"]),
        "extrapolation_mode": kwargs.get("extrapolation_mode", temp_opts["extrapolation_mode"]),
        "min_temp_span": kwargs.get("min_temp_span", temp_opts["min_temp_span"]),
        "min_samples": kwargs.get("min_samples", temp_opts["min_samples"]),
        "bin_width_degC": kwargs.get("bin_width_degC", temp_opts["bin_width_degC"]),
        "min_bin_samples": kwargs.get("min_bin_samples", temp_opts["min_bin_samples"]),
        "min_valid_bins": kwargs.get("min_valid_bins", temp_opts["min_valid_bins"]),
    }

    if fit_gyro and fit_acc:
        combined = fit_temperature_bias_models(
            static_gyro=static.gyro,
            static_acc=static.acc,
            temp=static.temp,
            static_data=static,
            Ca=Ca,
            ba0=ba,
            gravity_magnitude=kwargs.get("gravity_magnitude", options["acc_calibration"]["gravity_magnitude"]),
            acc_min_bin_pose_count=kwargs.get("acc_min_bin_pose_count", temp_opts["acc_min_bin_pose_count"]),
            acc_min_pose_rank=kwargs.get("acc_min_pose_rank", temp_opts["acc_min_pose_rank"]),
            options=options,
            fit_gyro=True,
            fit_acc=True,
            **common_kwargs,
        )
        bg_model = combined["gyro"]
        ba_model = combined["acc"]
        model_file = combined
    elif fit_gyro:
        bg_model = fit_gyro_temperature_bias_model(static.gyro, static.temp, options=options, **common_kwargs)
        ba_model = {}
        model_file = {
            "reference_temperature": bg_model.get("reference_temperature"),
            "temperature_range": bg_model.get("temperature_range"),
            "extrapolation_mode": bg_model.get("extrapolation_mode", common_kwargs["extrapolation_mode"]),
            "gyro": bg_model,
            "acc": {},
            "message": bg_model.get("message", ""),
        }
    else:
        ba_model = fit_accel_temperature_bias_model(
            static_acc=static.acc,
            temp=static.temp,
            static_data=static,
            Ca=Ca,
            ba0=ba,
            gravity_magnitude=kwargs.get("gravity_magnitude", options["acc_calibration"]["gravity_magnitude"]),
            options=options,
            min_bin_pose_count=kwargs.get("acc_min_bin_pose_count", temp_opts["acc_min_bin_pose_count"]),
            min_pose_rank=kwargs.get("acc_min_pose_rank", temp_opts["acc_min_pose_rank"]),
            **common_kwargs,
        )
        bg_model = {}
        model_file = {
            "reference_temperature": ba_model.get("reference_temperature"),
            "temperature_range": ba_model.get("temperature_range"),
            "extrapolation_mode": ba_model.get("extrapolation_mode", common_kwargs["extrapolation_mode"]),
            "gyro": {},
            "acc": ba_model,
            "message": ba_model.get("message", ""),
        }

    warnings: list[str] = []
    if isinstance(bg_model, dict) and bg_model.get("low_confidence", False):
        warnings.append(bg_model.get("message", "Gyro temperature model is low confidence."))
    if isinstance(ba_model, dict) and ba_model.get("low_confidence", False):
        warnings.append(ba_model.get("message", "Accel temperature model is low confidence."))

    metrics = {
        "target": target,
        "reference_temperature": model_file.get("reference_temperature"),
        "temperature_range": model_file.get("temperature_range"),
        "gyro_valid": bool(isinstance(bg_model, dict) and bg_model.get("valid", False)),
        "acc_valid": bool(isinstance(ba_model, dict) and ba_model.get("valid", False)),
    }
    message = _build_message(bg_model, ba_model, target)
    return make_task_result(
        True,
        message,
        {
            "bgModel": bg_model,
            "baModel": ba_model,
            "temperatureModel": model_file,
            "metrics": metrics,
        },
        warnings=warnings,
        meta={"task_name": "run_temperature_fit", "target": target},
    )


def _normalize_static_input(input_data):
    if is_dataclass(input_data) and hasattr(input_data, "static"):
        return input_data.static
    if isinstance(input_data, dict) and "static" in input_data:
        return input_data["static"]
    return input_data


def _build_message(bg_model: dict, ba_model: dict, target: str) -> str:
    parts = []
    if target in {"bg", "gyro", "both"} and isinstance(bg_model, dict):
        parts.append(f"gyro={_model_status(bg_model)}")
    if target in {"ba", "acc", "accel", "acceleration", "both"} and isinstance(ba_model, dict):
        parts.append(f"acc={_model_status(ba_model)}")
    return "temperature bias fit completed (" + ", ".join(parts) + ")."


def _model_status(model: dict) -> str:
    if not model:
        return "not_run"
    if model.get("valid", False):
        return "valid"
    if model.get("low_confidence", False):
        return "low_confidence"
    return "invalid"
