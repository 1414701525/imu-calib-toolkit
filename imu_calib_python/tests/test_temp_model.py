import numpy as np

from imu_calib.calib.fit_temperature_bias_model import (
    fit_accel_temperature_bias_model,
    fit_temperature_bias_model,
)
from imu_calib.io.load_example_data import load_example_data
from imu_calib.models.data_structures import StaticData
from imu_calib.runtime.apply_imu_calibration import apply_imu_calibration
from imu_calib.runtime.default_calib_options import default_calib_options
from imu_calib.tasks.run_temperature_fit import run_temperature_fit


def test_temperature_model_degrades_gracefully_for_small_temp_span():
    data, _, _ = load_example_data()
    model = fit_temperature_bias_model(data.static.gyro, data.static.temp)
    assert model["valid"] is False
    assert model["low_confidence"] is True
    assert "Temperature span" in model["message"]


def test_accel_temperature_bias_model_requires_fixed_ca():
    data, _, _ = load_example_data()
    model = fit_accel_temperature_bias_model(static_data=data.static, Ca=None)
    assert model["valid"] is False
    assert "Fixed Ca is required" in model["message"]


def test_run_temperature_fit_supports_joint_bg_and_ba_models():
    static, Ca, ba_ref = _make_temperature_static_dataset()
    options = default_calib_options()
    options["segmentation"]["static_window_sec"] = 0.2
    options["segmentation"]["min_segment_sec"] = 0.6
    options["segmentation"]["gyro_norm_threshold"] = 0.02
    options["segmentation"]["gyro_std_threshold"] = 0.01
    options["segmentation"]["acc_std_threshold"] = 0.08
    task = run_temperature_fit(
        {"static": static},
        target="both",
        Ca=Ca,
        ba=np.zeros(3),
        min_temp_span=4.0,
        min_samples=50,
        bin_width_degC=2.0,
        min_bin_samples=3,
        min_valid_bins=3,
        acc_min_bin_pose_count=3,
        acc_min_pose_rank=2,
        options=options,
    )
    assert task["success"] is True
    bg_model = task["result"]["bgModel"]
    ba_model = task["result"]["baModel"]
    assert bg_model["valid"] is True
    assert ba_model["valid"] is True
    assert bg_model["metrics"]["num_bins"] >= 3
    assert ba_model["metrics"]["num_bins"] >= 3

    calib = {
        "bg": np.zeros(3),
        "ba": np.zeros(3),
        "Ca": Ca,
        "Cg": np.eye(3),
        "Gg": np.zeros((3, 3)),
        "temp": {"bg_model": bg_model, "ba_model": ba_model},
    }
    corrected = apply_imu_calibration(
        {"gyro": static.gyro, "acc": static.acc, "temp": static.temp},
        calib,
    )
    static_mask = np.linalg.norm(static.gyro, axis=1) < 0.02
    corrected_norm_error = np.abs(np.linalg.norm(corrected["acc"], axis=1) - 9.80665)
    assert float(np.mean(corrected_norm_error[static_mask])) < 0.05
    assert np.allclose(np.mean(corrected["bias_removed_gyro"][static_mask], axis=0), 0.0, atol=0.01)
    assert np.allclose(np.mean(corrected["baT"][static_mask], axis=0), ba_ref[static_mask].mean(axis=0), atol=0.15)


def _make_temperature_static_dataset():
    rng = np.random.default_rng(1234)
    g = 9.80665
    temp_bins = np.array([15.0, 20.0, 25.0, 30.0], dtype=float)
    poses = np.array(
        [
            [g, 0.0, 0.0],
            [-g, 0.0, 0.0],
            [0.0, g, 0.0],
            [0.0, -g, 0.0],
            [0.0, 0.0, g],
            [0.0, 0.0, -g],
        ],
        dtype=float,
    )
    Ca = np.array(
        [
            [1.01, 0.015, -0.01],
            [0.0, 0.99, 0.012],
            [0.0, 0.0, 1.005],
        ],
        dtype=float,
    )
    Ca_inv = np.linalg.inv(Ca)
    t = []
    gyro = []
    acc = []
    temp = []
    bias_truth = []
    dt = 0.05
    idx = 0
    for T in temp_bins:
        dT = T - 22.0
        bg = np.array([0.002 + 2e-4 * dT, -0.001 + 1e-4 * dT, 0.0015 - 1.5e-4 * dT], dtype=float)
        ba = np.array([0.05 + 0.01 * dT, -0.02 + 0.005 * dT, 0.03 - 0.008 * dT], dtype=float)
        for pose in poses:
            raw_mean = Ca_inv @ pose + ba
            for _ in range(20):
                t.append(idx * dt)
                gyro.append(bg + rng.normal(scale=3e-4, size=3))
                acc.append(raw_mean + rng.normal(scale=0.01, size=3))
                temp.append(T + rng.normal(scale=0.05))
                bias_truth.append(ba)
                idx += 1
            for _ in range(5):
                t.append(idx * dt)
                gyro.append(bg + rng.normal(scale=0.15, size=3))
                acc.append(rng.normal(scale=0.8, size=3))
                temp.append(T + rng.normal(scale=0.05))
                bias_truth.append(ba)
                idx += 1

    static = StaticData(
        t=np.asarray(t, dtype=float),
        gyro=np.asarray(gyro, dtype=float),
        acc=np.asarray(acc, dtype=float),
        temp=np.asarray(temp, dtype=float),
    )
    return static, Ca, np.asarray(bias_truth, dtype=float)
