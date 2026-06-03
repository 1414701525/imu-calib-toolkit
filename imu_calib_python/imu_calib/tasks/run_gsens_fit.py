from __future__ import annotations

from dataclasses import is_dataclass

from imu_calib.calib.fit_gyro_g_sensitivity import fit_gyro_g_sensitivity
from imu_calib.tasks.make_task_result import make_task_result


def run_gsens_fit(input_data, *, bg=None, Cg=None) -> dict:
    gsens_runs = _normalize_gsens_runs(input_data)
    if not gsens_runs:
        return make_task_result(
            False,
            "gsens_runs is required for Gg fitting.",
            None,
            missing_inputs=["gsens_runs"],
            meta={"task_name": "run_gsens_fit"},
        )

    missing: list[str] = []
    if bg is None:
        missing.append("bg")
    if Cg is None:
        missing.append("Cg")
    if missing:
        return make_task_result(
            False,
            "Cg and bg are required for Gg fitting.",
            None,
            missing_inputs=missing,
            meta={"task_name": "run_gsens_fit"},
        )

    Gg, fit_info = fit_gyro_g_sensitivity(gsens_runs, bg, Cg)
    warnings = [fit_info["message"]] if isinstance(fit_info, dict) and not fit_info.get("valid", False) else []
    return make_task_result(
        True,
        "Gg fitting completed.",
        {"Gg": Gg, "fitInfo": fit_info},
        warnings=warnings,
        meta={"task_name": "run_gsens_fit"},
    )


def _normalize_gsens_runs(input_data):
    if is_dataclass(input_data) and hasattr(input_data, "gsens_runs"):
        return input_data.gsens_runs
    if isinstance(input_data, dict) and "gsens_runs" in input_data:
        return input_data["gsens_runs"]
    return input_data
