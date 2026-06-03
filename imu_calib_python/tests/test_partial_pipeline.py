from imu_calib.io.export_dataset_bundle import export_dataset_bundle
from imu_calib.io.load_example_data import load_example_data
from imu_calib.tasks.run_full_calibration import run_full_calibration


def test_run_full_calibration_returns_partial_success_for_static_only(tmp_path):
    data, _, _ = load_example_data()
    export_dataset_bundle(data, tmp_path)

    task = run_full_calibration(tmp_path / "static.csv")

    assert task["success"]
    results = task["result"]["results"]
    assert results.validation["summary"]["mode"] == "partial"
    assert results.validation["summary"]["available_blocks"] == ["static"]
    assert "gyro_bias" in results.validation["summary"]["completed_modules"]
    assert "allan_analysis" in results.validation["summary"]["completed_modules"]
