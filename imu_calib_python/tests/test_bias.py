from imu_calib.calib.estimate_gyro_bias import estimate_gyro_bias
from imu_calib.io.load_example_data import load_example_data


def test_bias_matches_synthetic_truth():
    data, truth, _ = load_example_data()
    bg, _ = estimate_gyro_bias(data.static.gyro, t=data.static.t, temp=data.static.temp)
    assert abs(bg - truth["bg_true"]).max() < 5e-4
