from imu_calib.io.export_dataset_bundle import export_dataset_bundle
from imu_calib.io.load_csv_data import load_csv_data
from imu_calib.io.load_example_data import load_example_data


def test_load_csv_data_supports_single_static_csv(tmp_path):
    data, _, _ = load_example_data()
    export_dataset_bundle(data, tmp_path)

    loaded = load_csv_data(tmp_path / "static.csv")

    assert loaded.has_static
    assert not loaded.has_acc_poses
    assert not loaded.has_gyro_runs
    assert not loaded.has_gsens_runs
    assert loaded.meta["source"] == "single_static_csv"
    assert loaded.meta["available_blocks"] == ["static"]
    assert "acc_poses.csv" in loaded.meta["missing_files"]
    assert "gyro_runs.csv" in loaded.meta["missing_files"]
    assert "acc_calibration_from_static" in loaded.meta["available_tasks"]


def test_load_csv_data_supports_single_acc_pose_csv(tmp_path):
    data, _, _ = load_example_data()
    export_dataset_bundle(data, tmp_path)

    loaded = load_csv_data(tmp_path / "acc_poses.csv")

    assert not loaded.has_static
    assert loaded.has_acc_poses
    assert loaded.meta["source"] == "single_acc_poses_csv"
    assert loaded.meta["available_blocks"] == ["acc_poses"]
