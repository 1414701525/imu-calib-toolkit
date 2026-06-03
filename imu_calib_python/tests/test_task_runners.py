from imu_calib.io.export_dataset_bundle import export_dataset_bundle
from imu_calib.io.load_csv_data import load_csv_data
from imu_calib.io.load_example_data import load_example_data
from imu_calib.tasks.run_acc_calibration import run_acc_calibration
from imu_calib.tasks.run_gyro_bias import run_gyro_bias
from imu_calib.tasks.run_gyro_calibration import run_gyro_calibration


def test_run_acc_calibration_works_with_acc_only_input(tmp_path):
    data, _, _ = load_example_data()
    export_dataset_bundle(data, tmp_path)
    loaded = load_csv_data(tmp_path / "acc_poses.csv")

    task = run_acc_calibration(loaded)

    assert task["success"]
    assert task["result"]["Ca"].shape == (3, 3)
    assert task["result"]["ba"].shape == (3,)


def test_run_gyro_calibration_uses_external_bg_with_gyro_only_input(tmp_path):
    data, _, _ = load_example_data()
    export_dataset_bundle(data, tmp_path)
    gyro_only = load_csv_data(tmp_path / "gyro_runs.csv")
    bg_task = run_gyro_bias(data)

    task = run_gyro_calibration(gyro_only, bg=bg_task["result"]["bg"])

    assert task["success"]
    assert task["result"]["Cg"].shape == (3, 3)
    assert task["result"]["Kg"].shape == (3, 3)
    assert task["result"]["Mg"].shape == (3, 3)
