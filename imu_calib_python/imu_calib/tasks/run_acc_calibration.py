from __future__ import annotations

from dataclasses import is_dataclass

from imu_calib.calib.extract_static_pose_means import extract_static_pose_means
from imu_calib.calib.fit_acc_multi_pose import fit_acc_multi_pose
from imu_calib.runtime.default_calib_options import default_calib_options
from imu_calib.tasks.make_task_result import make_task_result
from imu_calib.utils.exceptions import ImuCalibError


def run_acc_calibration(input_data, *, options: dict | None = None) -> dict:
    """Run accelerometer calibration using the new gravity-constraint workflow.

    Accepted inputs:
    - acc_poses: pre-computed per-pose static means (new preferred path)
    - static: continuous raw IMU data; static segments will be detected and
      converted into pose means automatically

    Legacy reference vectors a_ref are optional and only used for initialization
    compatibility. The optimization objective no longer depends on them.
    """

    options = default_calib_options() if options is None else options
    acc_poses, extraction_info, source = _normalize_acc_input(input_data, options)
    if not acc_poses:
        return make_task_result(
            False,
            "Accelerometer calibration requires acc_poses or raw static data with detectable static segments.",
            None,
            missing_inputs=["acc_poses_or_static_segments"],
            meta={"task_name": "run_acc_calibration", "source": source},
        )

    if extraction_info is not None:
        min_segments = int(options["segmentation"]["min_static_segments"])
        num_segments = int(extraction_info.get("num_segments", 0))
        if num_segments < min_segments:
            return make_task_result(
                False,
                (
                    "Not enough static segments were extracted for accelerometer calibration. "
                    f"Detected {num_segments}, but at least {min_segments} are recommended."
                ),
                None,
                warnings=extraction_info.get("messages", []),
                missing_inputs=["static_segments"],
                meta={"task_name": "run_acc_calibration", "source": source},
            )

    try:
        Ca, ba, fit_info = fit_acc_multi_pose(
            acc_poses,
            gravity_magnitude=options["acc_calibration"]["gravity_magnitude"],
            options=options,
        )
    except ImuCalibError as exc:
        return make_task_result(
            False,
            str(exc),
            None,
            warnings=extraction_info["messages"] if extraction_info is not None else [],
            meta={"task_name": "run_acc_calibration", "source": source},
        )
    if extraction_info is not None:
        fit_info["static_segment_extraction"] = extraction_info

    warnings: list[str] = []
    if extraction_info is not None:
        warnings.extend(extraction_info.get("messages", []))
    warnings.extend(list(fit_info.get("warnings", [])))
    if any(getattr(pose, "a_ref", None) is not None for pose in acc_poses):
        warnings.append(
            "Legacy reference vectors were detected. They are deprecated and were only used for initialization compatibility."
        )

    return make_task_result(
        True,
        "accelerometer calibration completed successfully.",
        {
            "Ca": Ca,
            "ba": ba,
            "Sa": fit_info["Sa"],
            "Ma": fit_info["Ma"],
            "gravity_magnitude": fit_info["gravity_magnitude"],
            "fitInfo": fit_info,
        },
        warnings=warnings,
        meta={"task_name": "run_acc_calibration", "source": source},
    )


def _normalize_acc_input(input_data, options: dict):
    acc_poses = []
    extraction_info = None
    source = "direct_input"

    if is_dataclass(input_data):
        if hasattr(input_data, "acc_poses") and input_data.acc_poses:
            acc_poses = input_data.acc_poses
            source = "dataset.acc_poses"
        elif hasattr(input_data, "static") and input_data.static is not None:
            acc_poses, extraction_info = extract_static_pose_means(input_data.static, options=options)
            source = "dataset.static"
    elif isinstance(input_data, dict):
        if input_data.get("acc_poses"):
            acc_poses = input_data["acc_poses"]
            source = "dict.acc_poses"
        elif input_data.get("static") is not None:
            acc_poses, extraction_info = extract_static_pose_means(input_data["static"], options=options)
            source = "dict.static"
    else:
        acc_poses = input_data

    return acc_poses, extraction_info, source
