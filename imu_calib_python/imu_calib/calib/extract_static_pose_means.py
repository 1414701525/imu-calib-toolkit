from __future__ import annotations

import numpy as np

from imu_calib.models.data_structures import AccPose, StaticData
from imu_calib.runtime.default_calib_options import default_calib_options
from imu_calib.utils.detect_static_segments import detect_static_segments
from imu_calib.utils.exceptions import ImuCalibError


def extract_static_pose_means(static: StaticData, options: dict | None = None) -> tuple[list[AccPose], dict]:
    """Extract static-pose accelerometer means from continuous raw IMU data.

    The new accelerometer calibration no longer requires per-pose reference
    gravity vectors. When only a continuous static / pose-switching recording
    is available, this helper segments static intervals and converts each valid
    interval into one AccPose sample.
    """

    if static is None:
        raise ImuCalibError("static data is required to extract pose means.")

    options = default_calib_options() if options is None else options
    seg_opts = options["segmentation"]
    detection = detect_static_segments(
        static.t,
        static.gyro,
        static.acc,
        static_window_sec=seg_opts["static_window_sec"],
        gyro_norm_threshold=seg_opts["gyro_norm_threshold"],
        gyro_std_threshold=seg_opts["gyro_std_threshold"],
        acc_std_threshold=seg_opts["acc_std_threshold"],
        min_segment_sec=seg_opts["min_segment_sec"],
    )

    segments = np.asarray(detection["segments"], dtype=int)
    poses: list[AccPose] = []
    segment_rows: list[dict] = []
    for idx, (start, end) in enumerate(segments, start=1):
        sl = slice(int(start), int(end) + 1)
        acc_mean = np.mean(static.acc[sl, :], axis=0)
        gyro_mean = np.mean(static.gyro[sl, :], axis=0)
        duration = float(static.t[end] - static.t[start]) if end > start else 0.0
        pose_name = f"static_seg_{idx:02d}"
        temp_mean = None
        if static.temp is not None:
            temp_mean = float(np.mean(static.temp[sl]))

        poses.append(AccPose(acc_mean=acc_mean, pose_name=pose_name, a_ref=None))
        segment_rows.append(
            {
                "pose_name": pose_name,
                "start_idx": int(start),
                "end_idx": int(end),
                "num_samples": int(end - start + 1),
                "duration_sec": duration,
                "acc_mean": acc_mean,
                "gyro_mean": gyro_mean,
                "temp_mean": temp_mean,
            }
        )

    info = {
        "source": "static_segment_extraction",
        "num_segments": int(len(segment_rows)),
        "segment_rows": segment_rows,
        "quality": detection["quality"],
        "messages": [
            "Static segments were extracted from raw static.acc/static.gyro and converted to pose means."
        ],
    }
    return poses, info
