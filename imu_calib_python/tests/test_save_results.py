from imu_calib.calib.estimate_gyro_bias import estimate_gyro_bias
from imu_calib.calib.estimate_noise_stats import estimate_noise_stats
from imu_calib.calib.fit_acc_multi_pose import fit_acc_multi_pose
from imu_calib.calib.fit_gyro_C_from_angle_increment import fit_gyro_C_from_angle_increment
from imu_calib.calib.fit_gyro_g_sensitivity import fit_gyro_g_sensitivity
from imu_calib.calib.split_km import split_km
from imu_calib.io.load_example_data import load_example_data
from imu_calib.runtime.build_calib_results import build_calib_results
from imu_calib.runtime.default_calib_options import default_calib_options
from imu_calib.runtime.save_calibration_results import save_calibration_results
from imu_calib.validate.validate_calibration import validate_calibration


def test_save_calibration_results_writes_expected_files(tmp_path):
    data, truth, meta = load_example_data()
    bg, bias_info = estimate_gyro_bias(data.static.gyro, t=data.static.t, temp=data.static.temp)
    noise_stats = estimate_noise_stats(data.static.gyro, data.static.acc)
    Ca, ba, acc_info = fit_acc_multi_pose(data.acc_poses)
    Cg, gyro_info = fit_gyro_C_from_angle_increment(data.gyro_runs, bg)
    Kg, Mg = split_km(Cg)
    Gg, gsens_info = fit_gyro_g_sensitivity(data.gsens_runs, bg, Cg)
    results = build_calib_results(
        data,
        {
            "bg": bg,
            "bias_info": bias_info,
            "noise_stats": noise_stats,
            "Ca": Ca,
            "ba": ba,
            "acc_info": acc_info,
            "Cg": Cg,
            "Kg": Kg,
            "Mg": Mg,
            "Gg": Gg,
            "gyro_info": gyro_info,
            "gsens_info": gsens_info,
            "meta": meta,
            "truth": truth,
        },
        options=default_calib_options(),
    )
    results.validation = validate_calibration(data, results.compat["flat_calib"], options=results.options, analysis=results.analysis)
    written = save_calibration_results(results, tmp_path)

    assert "pickle" in written
    assert "json_summary" in written
    assert "npz" in written
