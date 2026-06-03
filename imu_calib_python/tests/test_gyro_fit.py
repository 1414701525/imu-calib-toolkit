from imu_calib.calib.estimate_gyro_bias import estimate_gyro_bias
from imu_calib.calib.fit_gyro_C_from_angle_increment import fit_gyro_C_from_angle_increment
from imu_calib.io.load_example_data import load_example_data


def test_gyro_fit_close_to_truth():
    data, truth, _ = load_example_data()
    bg, _ = estimate_gyro_bias(data.static.gyro, t=data.static.t, temp=data.static.temp)
    Cg, _ = fit_gyro_C_from_angle_increment(data.gyro_runs, bg)
    assert abs(Cg - truth["Cg_true"]).max() < 2e-2
