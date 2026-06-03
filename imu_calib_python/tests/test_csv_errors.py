import pandas as pd
import pytest

from imu_calib.io.load_csv_data import load_csv_data
from imu_calib.utils.exceptions import ImuCalibError


def test_load_csv_data_raises_on_missing_columns(tmp_path):
    pd.DataFrame({"t": [0.0, 0.1], "gx": [0.0, 0.0]}).to_csv(tmp_path / "static.csv", index=False)
    pd.DataFrame(
        {
            "pose_name": ["p1"],
            "acc_x": [0.0],
            "acc_y": [0.0],
            "acc_z": [9.8],
        }
    ).to_csv(tmp_path / "acc_poses.csv", index=False)
    pd.DataFrame(
        {
            "run_id": [1, 1],
            "axis": ["x", "x"],
            "dir": [1, 1],
            "t": [0.0, 0.1],
            "gx": [0.0, 0.0],
            "gy": [0.0, 0.0],
            "gz": [0.0, 0.0],
            "idx_ss": [1, 1],
            "theta_ref_x": [1.0, 1.0],
            "theta_ref_y": [0.0, 0.0],
            "theta_ref_z": [0.0, 0.0],
        }
    ).to_csv(tmp_path / "gyro_runs.csv", index=False)

    with pytest.raises(ImuCalibError):
        load_csv_data(tmp_path)


def test_load_csv_data_raises_on_non_monotonic_time(tmp_path):
    pd.DataFrame(
        {
            "t": [0.0, 0.1, 0.05],
            "gx": [0.0, 0.0, 0.0],
            "gy": [0.0, 0.0, 0.0],
            "gz": [0.0, 0.0, 0.0],
            "ax": [0.0, 0.0, 0.0],
            "ay": [0.0, 0.0, 0.0],
            "az": [9.8, 9.8, 9.8],
        }
    ).to_csv(tmp_path / "static.csv", index=False)
    pd.DataFrame(
        {
            "pose_name": ["p1"],
            "acc_x": [0.0],
            "acc_y": [0.0],
            "acc_z": [9.8],
        }
    ).to_csv(tmp_path / "acc_poses.csv", index=False)
    pd.DataFrame(
        {
            "run_id": [1, 1],
            "axis": ["x", "x"],
            "dir": [1, 1],
            "t": [0.0, 0.1],
            "gx": [0.0, 0.0],
            "gy": [0.0, 0.0],
            "gz": [0.0, 0.0],
            "idx_ss": [1, 1],
            "theta_ref_x": [1.0, 1.0],
            "theta_ref_y": [0.0, 0.0],
            "theta_ref_z": [0.0, 0.0],
        }
    ).to_csv(tmp_path / "gyro_runs.csv", index=False)

    with pytest.raises(ImuCalibError):
        load_csv_data(tmp_path)


def test_load_csv_data_raises_on_partial_legacy_reference_columns(tmp_path):
    pd.DataFrame(
        {
            "pose_name": ["p1"],
            "acc_x": [0.0],
            "acc_y": [0.0],
            "acc_z": [9.8],
            "ref_x": [0.0],
            "ref_y": [0.0],
        }
    ).to_csv(tmp_path / "acc_poses.csv", index=False)

    with pytest.raises(ImuCalibError):
        load_csv_data(tmp_path / "acc_poses.csv")
