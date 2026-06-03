from __future__ import annotations

from dataclasses import is_dataclass

from imu_calib.calib.fit_gyro_C_from_angle_increment import fit_gyro_C_from_angle_increment
from imu_calib.calib.split_km import split_km
from imu_calib.tasks.make_task_result import make_task_result
from imu_calib.tasks.run_gyro_bias import run_gyro_bias


def run_gyro_calibration(input_data, *, bg=None) -> dict:
    gyro_runs = _normalize_gyro_runs(input_data)
    if not gyro_runs:
        return make_task_result(
            False,
            "gyro_runs is required for gyro Cg calibration.",
            None,
            missing_inputs=["gyro_runs"],
            meta={"task_name": "run_gyro_calibration"},
        )

    warnings: list[str] = []
    bg_used = bg
    if bg_used is None:
        static = _extract_static(input_data)
        bias_task = run_gyro_bias(static) if static is not None else None
        if bias_task is None or not bias_task["success"]:
            return make_task_result(
                False,
                "bg is required for gyro Cg calibration.",
                None,
                warnings=["Provide bg directly or include static.gyro for fallback estimation."],
                missing_inputs=["bg"],
                meta={"task_name": "run_gyro_calibration"},
            )
        bg_used = bias_task["result"]["bg"]
        warnings.append("bg was not provided; estimated from static.gyro.")

    Cg, fit_info = fit_gyro_C_from_angle_increment(gyro_runs, bg_used)
    Kg, Mg = split_km(Cg)
    return make_task_result(
        True,
        "gyro Cg calibration completed successfully.",
        {"bg_used": bg_used, "Cg": Cg, "Kg": Kg, "Mg": Mg, "fitInfo": fit_info},
        warnings=warnings,
        meta={"task_name": "run_gyro_calibration"},
    )


def _normalize_gyro_runs(input_data):
    if is_dataclass(input_data) and hasattr(input_data, "gyro_runs"):
        return input_data.gyro_runs
    if isinstance(input_data, dict) and "gyro_runs" in input_data:
        return input_data["gyro_runs"]
    return input_data


def _extract_static(input_data):
    if is_dataclass(input_data) and hasattr(input_data, "static"):
        return input_data.static
    if isinstance(input_data, dict) and "static" in input_data:
        return input_data["static"]
    return None
