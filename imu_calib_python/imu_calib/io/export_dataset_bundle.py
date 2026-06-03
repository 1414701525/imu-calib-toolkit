from __future__ import annotations

import json
from pathlib import Path

import pandas as pd

from imu_calib.models.data_structures import ImuDataset


def export_dataset_bundle(
    data: ImuDataset,
    output_dir: str | Path,
    *,
    include_legacy_reference_columns: bool = False,
) -> dict[str, str]:
    """Export a dataset to the manifest + CSV bundle layout.

    By default the new accelerometer bundle omits per-pose reference vectors.
    Legacy ref_x/ref_y/ref_z columns can still be emitted when explicitly
    requested for migration debugging or historical dataset comparison.
    """
    root = Path(output_dir).expanduser().resolve()
    root.mkdir(parents=True, exist_ok=True)

    static_path = root / "static.csv"
    acc_poses_path = root / "acc_poses.csv"
    gyro_runs_path = root / "gyro_runs.csv"
    gsens_runs_path = root / "gsens_runs.csv"

    static_df = pd.DataFrame(
        {
            "t": data.static.t,
            "gx": data.static.gyro[:, 0],
            "gy": data.static.gyro[:, 1],
            "gz": data.static.gyro[:, 2],
            "ax": data.static.acc[:, 0],
            "ay": data.static.acc[:, 1],
            "az": data.static.acc[:, 2],
        }
    )
    if data.static.temp is not None:
        static_df["temp"] = data.static.temp
    static_df.to_csv(static_path, index=False)

    acc_rows = []
    for pose in data.acc_poses:
        row = {
            "pose_name": pose.pose_name,
            "acc_x": pose.acc_mean[0],
            "acc_y": pose.acc_mean[1],
            "acc_z": pose.acc_mean[2],
        }
        if include_legacy_reference_columns and pose.a_ref is not None:
            row["ref_x"] = pose.a_ref[0]
            row["ref_y"] = pose.a_ref[1]
            row["ref_z"] = pose.a_ref[2]
        acc_rows.append(row)
    pd.DataFrame(acc_rows).to_csv(acc_poses_path, index=False)

    gyro_rows = []
    for run_idx, run in enumerate(data.gyro_runs, start=1):
        for sample_idx in range(run.t.size):
            gyro_rows.append(
                {
                    "run_id": run_idx,
                    "axis": run.axis,
                    "dir": run.dir,
                    "t": run.t[sample_idx],
                    "gx": run.gyro[sample_idx, 0],
                    "gy": run.gyro[sample_idx, 1],
                    "gz": run.gyro[sample_idx, 2],
                    "idx_ss": int(run.idx_ss[sample_idx]),
                    "theta_ref_x": run.theta_ref[0],
                    "theta_ref_y": run.theta_ref[1],
                    "theta_ref_z": run.theta_ref[2],
                }
            )
    pd.DataFrame(gyro_rows).to_csv(gyro_runs_path, index=False)

    if data.gsens_runs:
        gsens_rows = []
        for run_idx, run in enumerate(data.gsens_runs, start=1):
            omega_ref = run.omega_ref
            for sample_idx in range(run.t.size):
                row = {
                    "run_id": run_idx,
                    "t": run.t[sample_idx],
                    "gx": run.gyro[sample_idx, 0],
                    "gy": run.gyro[sample_idx, 1],
                    "gz": run.gyro[sample_idx, 2],
                    "acc_ref_x": run.acc_ref[sample_idx, 0],
                    "acc_ref_y": run.acc_ref[sample_idx, 1],
                    "acc_ref_z": run.acc_ref[sample_idx, 2],
                }
                if omega_ref is not None:
                    row["omega_ref_x"] = omega_ref[sample_idx, 0]
                    row["omega_ref_y"] = omega_ref[sample_idx, 1]
                    row["omega_ref_z"] = omega_ref[sample_idx, 2]
                gsens_rows.append(row)
        pd.DataFrame(gsens_rows).to_csv(gsens_runs_path, index=False)

    manifest = {
        "format": "imu_calib_bundle",
        "version": 1,
        "files": {
            "static": static_path.name,
            "acc_poses": acc_poses_path.name,
            "gyro_runs": gyro_runs_path.name,
        },
    }
    if data.gsens_runs:
        manifest["files"]["gsens_runs"] = gsens_runs_path.name
    manifest_path = root / "dataset_manifest.json"
    manifest_path.write_text(json.dumps(manifest, indent=2), encoding="utf-8")
    return {"root": str(root), "manifest": str(manifest_path)}
