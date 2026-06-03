from __future__ import annotations

from dataclasses import is_dataclass

from imu_calib.calib.analyze_acc_allan import analyze_acc_allan
from imu_calib.calib.analyze_gyro_allan import analyze_gyro_allan
from imu_calib.tasks.make_task_result import make_task_result
from imu_calib.tasks.require_inputs import require_inputs


def run_allan_analysis(input_data, **kwargs) -> dict:
    static = _normalize_static_input(input_data)
    missing = require_inputs(static, ["t"])
    if missing:
        return make_task_result(
            False,
            "static.t is required for Allan analysis.",
            None,
            missing_inputs=["static.t"],
            meta={"task_name": "run_allan_analysis"},
        )

    has_gyro = hasattr(static, "gyro") and static.gyro is not None and len(static.gyro) > 0
    has_acc = hasattr(static, "acc") and static.acc is not None and len(static.acc) > 0
    if not has_gyro and not has_acc:
        return make_task_result(
            False,
            "At least one of static.gyro or static.acc is required for Allan analysis.",
            None,
            missing_inputs=["static.gyro or static.acc"],
            meta={"task_name": "run_allan_analysis"},
        )

    result = {"gyro_allan": None, "acc_allan": None}
    warnings: list[str] = []
    if has_gyro:
        result["gyro_allan"] = analyze_gyro_allan(static.t, static.gyro, **kwargs)
    else:
        warnings.append("static.gyro not provided; gyro Allan analysis skipped.")
    if has_acc:
        result["acc_allan"] = analyze_acc_allan(static.t, static.acc, **kwargs)
    else:
        warnings.append("static.acc not provided; accelerometer Allan analysis skipped.")

    return make_task_result(
        True,
        "Allan analysis completed.",
        result,
        warnings=warnings,
        meta={"task_name": "run_allan_analysis"},
    )


def _normalize_static_input(input_data):
    if is_dataclass(input_data) and hasattr(input_data, "static"):
        return input_data.static
    if isinstance(input_data, dict) and "static" in input_data:
        return input_data["static"]
    return input_data
