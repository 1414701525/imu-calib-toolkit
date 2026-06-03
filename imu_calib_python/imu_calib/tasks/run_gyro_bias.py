from __future__ import annotations

from dataclasses import is_dataclass

from imu_calib.calib.estimate_gyro_bias import estimate_gyro_bias
from imu_calib.tasks.make_task_result import make_task_result
from imu_calib.tasks.require_inputs import require_inputs


def run_gyro_bias(input_data) -> dict:
    static = _normalize_static_input(input_data)
    missing = require_inputs(static, ["gyro"])
    if missing:
        return make_task_result(
            False,
            "static.gyro is required for gyro bias estimation.",
            None,
            missing_inputs=["static.gyro"],
            meta={"task_name": "run_gyro_bias"},
        )

    bg, info = estimate_gyro_bias(static.gyro, t=getattr(static, "t", None), temp=getattr(static, "temp", None))
    return make_task_result(
        True,
        "gyro bias estimated successfully.",
        {"bg": bg, "stats": info},
        meta={"task_name": "run_gyro_bias"},
    )


def _normalize_static_input(input_data):
    if is_dataclass(input_data) and hasattr(input_data, "static"):
        return input_data.static
    if isinstance(input_data, dict) and "static" in input_data:
        return input_data["static"]
    return input_data
