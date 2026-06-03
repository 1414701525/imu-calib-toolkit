import pandas as pd

from imu_calib.io.export_dataset_bundle import export_dataset_bundle
from imu_calib.io.load_csv_data import load_csv_data
from imu_calib.io.load_example_data import load_example_data


def test_bundle_round_trip(tmp_path):
    data, _, _ = load_example_data()
    export_info = export_dataset_bundle(data, tmp_path)
    loaded = load_csv_data(tmp_path)

    assert loaded.static.gyro.shape == data.static.gyro.shape
    assert len(loaded.acc_poses) == len(data.acc_poses)
    assert len(loaded.gyro_runs) == len(data.gyro_runs)
    assert export_info["manifest"].endswith("dataset_manifest.json")
    acc_df = pd.read_csv(tmp_path / "acc_poses.csv")
    assert "ref_x" not in acc_df.columns
    assert "ref_y" not in acc_df.columns
    assert "ref_z" not in acc_df.columns
