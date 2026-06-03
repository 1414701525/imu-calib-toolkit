from __future__ import annotations

from pathlib import Path

from imu_calib.io.load_csv_data import load_csv_data
from imu_calib.runtime.build_calib_results import build_calib_results
from imu_calib.runtime.default_calib_options import default_calib_options
from imu_calib.tasks.full_calibration_support import build_partial_validation, nested_or_default
from imu_calib.tasks.make_task_result import make_task_result
from imu_calib.tasks.run_acc_calibration import run_acc_calibration
from imu_calib.tasks.run_allan_analysis import run_allan_analysis
from imu_calib.tasks.run_gsens_fit import run_gsens_fit
from imu_calib.tasks.run_gyro_bias import run_gyro_bias
from imu_calib.tasks.run_gyro_calibration import run_gyro_calibration
from imu_calib.tasks.run_noise_stats import run_noise_stats
from imu_calib.tasks.run_temperature_fit import run_temperature_fit
from imu_calib.validate.validate_calibration import validate_calibration


def run_full_calibration(input_data, *, options: dict | None = None):
    """Run as many calibration/analysis modules as possible from the provided inputs."""

    options = default_calib_options() if options is None else options
    if isinstance(input_data, (str, Path)):
        data = load_csv_data(input_data)
        input_mode = "csv_or_manifest"
    else:
        data = input_data
        input_mode = "struct_input"

    warnings: list[str] = []
    tasks: dict = {}

    tasks["gyro_bias"] = run_gyro_bias(data)
    if not tasks["gyro_bias"]["success"]:
        warnings.append(tasks["gyro_bias"]["message"])

    tasks["noise_stats"] = run_noise_stats(data)
    if not tasks["noise_stats"]["success"]:
        warnings.append(tasks["noise_stats"]["message"])

    tasks["acc"] = run_acc_calibration(data, options=options)
    if not tasks["acc"]["success"]:
        warnings.append(tasks["acc"]["message"])

    bg_for_gyro = nested_or_default(tasks, ["gyro_bias", "result", "bg"], None)
    tasks["gyro"] = run_gyro_calibration(data, bg=bg_for_gyro)
    if not tasks["gyro"]["success"]:
        warnings.append(tasks["gyro"]["message"])

    if tasks["gyro"]["success"]:
        tasks["gsens"] = run_gsens_fit(
            data,
            bg=nested_or_default(tasks, ["gyro", "result", "bg_used"], bg_for_gyro),
            Cg=nested_or_default(tasks, ["gyro", "result", "Cg"], None),
        )
    else:
        tasks["gsens"] = make_task_result(
            False,
            "Gg fit skipped because gyro Cg calibration is unavailable.",
            None,
            missing_inputs=["Cg"],
            meta={"task_name": "run_gsens_fit"},
        )
    if not tasks["gsens"]["success"]:
        warnings.append(tasks["gsens"]["message"])

    tasks["allan"] = run_allan_analysis(
        data,
        min_samples=options["allan"]["min_samples"],
        num_tau=options["allan"]["num_tau"],
        tau_mode=options["allan"]["tau_mode"],
        validity_message_if_short=options["allan"]["validity_message_if_short"],
    )
    if not tasks["allan"]["success"]:
        warnings.append(tasks["allan"]["message"])

    tasks["temperature"] = run_temperature_fit(
        data,
        target=options["temperature"]["target"],
        Ca=nested_or_default(tasks, ["acc", "result", "Ca"], None),
        ba=nested_or_default(tasks, ["acc", "result", "ba"], None),
        method=options["temperature"]["method"],
        reference_temperature_mode=options["temperature"]["reference_temperature_mode"],
        extrapolation_mode=options["temperature"]["extrapolation_mode"],
        min_temp_span=options["temperature"]["min_temp_span"],
        min_samples=options["temperature"]["min_samples"],
        bin_width_degC=options["temperature"]["bin_width_degC"],
        min_bin_samples=options["temperature"]["min_bin_samples"],
        min_valid_bins=options["temperature"]["min_valid_bins"],
        acc_min_bin_pose_count=options["temperature"]["acc_min_bin_pose_count"],
        acc_min_pose_rank=options["temperature"]["acc_min_pose_rank"],
        gravity_magnitude=options["acc_calibration"]["gravity_magnitude"],
        options=options,
    )
    if not tasks["temperature"]["success"]:
        warnings.append(tasks["temperature"]["message"])

    components = {
        "bg": nested_or_default(tasks, ["gyro_bias", "result", "bg"], None),
        "bias_info": nested_or_default(tasks, ["gyro_bias", "result", "stats"], {}),
        "noise_stats": nested_or_default(tasks, ["noise_stats", "result", "noiseStats"], {}),
        "Ca": nested_or_default(tasks, ["acc", "result", "Ca"], None),
        "ba": nested_or_default(tasks, ["acc", "result", "ba"], None),
        "Sa": nested_or_default(tasks, ["acc", "result", "Sa"], None),
        "Ma": nested_or_default(tasks, ["acc", "result", "Ma"], None),
        "gravity_magnitude": nested_or_default(tasks, ["acc", "result", "gravity_magnitude"], None),
        "acc_info": nested_or_default(tasks, ["acc", "result", "fitInfo"], {}),
        "Cg": nested_or_default(tasks, ["gyro", "result", "Cg"], None),
        "Kg": nested_or_default(tasks, ["gyro", "result", "Kg"], None),
        "Mg": nested_or_default(tasks, ["gyro", "result", "Mg"], None),
        "Gg": nested_or_default(tasks, ["gsens", "result", "Gg"], None),
        "gyro_info": nested_or_default(tasks, ["gyro", "result", "fitInfo"], {}),
        "gsens_info": nested_or_default(tasks, ["gsens", "result", "fitInfo"], {}),
        "temp_bg_model": nested_or_default(tasks, ["temperature", "result", "bgModel"], {}),
        "temp_ba_model": nested_or_default(tasks, ["temperature", "result", "baModel"], {}),
        "temperature_model": nested_or_default(tasks, ["temperature", "result", "temperatureModel"], {}),
        "temp_message": nested_or_default(tasks, ["temperature", "message"], "Temperature fit not run."),
        "analysis": {
            "allan": {
                "gyro": nested_or_default(tasks, ["allan", "result", "gyro_allan"], None),
                "acc": nested_or_default(tasks, ["allan", "result", "acc_allan"], None),
            }
        },
        "meta": getattr(data, "meta", {}),
    }

    results = build_calib_results(data=data, components=components, options=options)

    has_static = bool(getattr(data, "has_static", False))
    has_acc_poses = bool(getattr(data, "has_acc_poses", False))
    has_gyro_runs = bool(getattr(data, "has_gyro_runs", False))

    if (
        has_static
        and has_acc_poses
        and has_gyro_runs
        and components["bg"] is not None
        and components["Ca"] is not None
        and components["ba"] is not None
        and components["Cg"] is not None
    ):
        results.validation = validate_calibration(
            data,
            results.compat["flat_calib"],
            options=options,
            analysis=results.analysis,
        )
        message = "Full calibration completed successfully."
        success = True
    else:
        results.validation = build_partial_validation(data, components, results.analysis, results.calib["temp"])
        completed_modules = results.validation["summary"]["completed_modules"]
        success = len(completed_modules) > 0
        message = "Partial calibration completed successfully." if success else "No calibration or analysis module could run with the provided inputs."

    return make_task_result(
        success,
        message,
        {"results": results, "tasks": tasks},
        warnings=warnings,
        meta={"task_name": "run_full_calibration", "input_mode": input_mode},
    )
