from __future__ import annotations

from dataclasses import is_dataclass

from imu_calib.calib.estimate_noise_stats import estimate_noise_stats
from imu_calib.tasks.make_task_result import make_task_result
from imu_calib.tasks.require_inputs import require_inputs


def run_noise_stats(input_data) -> dict:
    static = _normalize_static_input(input_data)
    missing = require_inputs(static, ["gyro", "acc"])
    if missing:
        return make_task_result(
            False,
            "static.gyro and static.acc are required for noise statistics.",
            None,
            missing_inputs=["static.gyro", "static.acc"],
            meta={"task_name": "run_noise_stats"},
        )

    noise_stats = estimate_noise_stats(static.gyro, static.acc)
    return make_task_result(
        True,
        "noise statistics estimated successfully.",
        {"noiseStats": noise_stats},
        meta={"task_name": "run_noise_stats"},
    )


def _normalize_static_input(input_data):
    if is_dataclass(input_data) and hasattr(input_data, "static"):
        return input_data.static
    if isinstance(input_data, dict) and "static" in input_data:
        return input_data["static"]
    return input_data
