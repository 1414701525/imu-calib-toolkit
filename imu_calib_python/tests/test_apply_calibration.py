import numpy as np

from imu_calib.calib.estimate_gyro_bias import estimate_gyro_bias
from imu_calib.calib.fit_acc_multi_pose import fit_acc_multi_pose
from imu_calib.calib.fit_gyro_C_from_angle_increment import fit_gyro_C_from_angle_increment
from imu_calib.calib.fit_gyro_g_sensitivity import fit_gyro_g_sensitivity
from imu_calib.io.load_example_data import load_example_data
from imu_calib.runtime.apply_imu_calibration import apply_imu_calibration


def test_apply_calibration_improves_static_metrics():
    data, truth, _ = load_example_data()
    bg, _ = estimate_gyro_bias(data.static.gyro, t=data.static.t, temp=data.static.temp)
    Ca, ba, _ = fit_acc_multi_pose(data.acc_poses)
    Cg, _ = fit_gyro_C_from_angle_increment(data.gyro_runs, bg)
    Gg, _ = fit_gyro_g_sensitivity(data.gsens_runs, bg, Cg)

    raw = {"gyro": data.static.gyro, "acc": data.static.acc}
    corrected = apply_imu_calibration(raw, {"bg": bg, "Ca": Ca, "ba": ba, "Cg": Cg, "Gg": Gg})

    raw_gyro_mean_norm = np.linalg.norm(data.static.gyro.mean(axis=0))
    corrected_gyro_mean_norm = np.linalg.norm(corrected["bias_removed_gyro"].mean(axis=0))
    assert corrected_gyro_mean_norm < raw_gyro_mean_norm

    raw_acc_norm_error = abs(np.linalg.norm(data.static.acc, axis=1).mean() - truth["g0"])
    corrected_acc_norm_error = abs(np.linalg.norm(corrected["acc"], axis=1).mean() - truth["g0"])
    assert corrected_acc_norm_error < raw_acc_norm_error
