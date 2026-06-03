from __future__ import annotations

import numpy as np

from imu_calib.models.data_structures import AccPose, GsensRun, GyroRun, ImuDataset, StaticData


def load_example_data(force_regenerate: bool = False) -> tuple[ImuDataset, dict, dict]:
    """Generate deterministic synthetic data aligned with the MATLAB workflow."""
    del force_regenerate  # Stage-1 Python version always regenerates deterministically.
    return _generate_synthetic_dataset()


def _generate_synthetic_dataset() -> tuple[ImuDataset, dict, dict]:
    rng = np.random.default_rng(42)
    g0 = 9.80665

    Sa_true = np.diag([1.0120, 0.9930, 1.0080])
    Ma_true = np.array(
        [
            [1.0, 0.0120, -0.0080],
            [0.0, 1.0, 0.0110],
            [0.0, 0.0, 1.0],
        ],
        dtype=float,
    )
    Ca_true = Sa_true @ Ma_true
    ba_true = np.array([0.0800, -0.0500, 0.1200], dtype=float)
    Kg_true = np.diag([0.0120, -0.0090, 0.0070])
    Mg_true = np.array(
        [
            [0.0, 0.0040, -0.0030],
            [-0.0020, 0.0, 0.0050],
            [0.0030, -0.0040, 0.0],
        ],
        dtype=float,
    )
    Cg_true = np.eye(3) + Kg_true + Mg_true
    bg_true = np.array([0.0080, -0.0060, 0.0040], dtype=float)
    Gg_true = np.zeros((3, 3), dtype=float)
    noise = {
        "gyro_std": np.array([0.0012, 0.0014, 0.0011], dtype=float),
        "acc_std": np.array([0.0300, 0.0280, 0.0320], dtype=float),
    }

    static = _generate_static_segment(rng, g0, Ca_true, ba_true, bg_true, noise)
    acc_poses = _generate_acc_poses(rng, g0, Ca_true, ba_true)
    gyro_runs = _generate_gyro_runs(rng, Cg_true, bg_true, noise["gyro_std"])
    gsens_runs: list[GsensRun] = []

    data = ImuDataset(
        static=static,
        acc_poses=acc_poses,
        gyro_runs=gyro_runs,
        gsens_runs=gsens_runs,
        meta={
            "source": "synthetic",
            "generated_from": "imu_calib/io/load_example_data.py",
            "rng_seed": 42,
            "description": "Deterministic synthetic IMU calibration dataset.",
            "num_acc_poses": len(acc_poses),
            "num_gyro_runs": len(gyro_runs),
        },
    )

    truth = {
        "g0": g0,
        "Ca_true": Ca_true,
        "Sa_true": Sa_true,
        "Ma_true": Ma_true,
        "ba_true": ba_true,
        "Kg_true": Kg_true,
        "Mg_true": Mg_true,
        "Cg_true": Cg_true,
        "bg_true": bg_true,
        "Gg_true": Gg_true,
        "noise": noise,
    }
    return data, truth, data.meta


def _generate_static_segment(rng, g0, Ca_true, ba_true, bg_true, noise) -> StaticData:
    fs = 100.0
    duration = 60.0
    N = int(fs * duration)
    t = np.arange(N, dtype=float) / fs
    a_ref = np.array([0.0, 0.0, g0], dtype=float)
    gyro_mean = np.tile(bg_true, (N, 1))
    raw_acc_mean = np.linalg.solve(Ca_true, a_ref)
    acc_mean = np.tile(raw_acc_mean + ba_true, (N, 1))
    gyro = gyro_mean + rng.normal(size=(N, 3)) * noise["gyro_std"]
    acc = acc_mean + rng.normal(size=(N, 3)) * noise["acc_std"]
    temp = 25.0 + 0.15 * np.sin(2.0 * np.pi * 0.01 * t)
    return StaticData(t=t, gyro=gyro, acc=acc, temp=temp)


def _generate_acc_poses(rng, g0, Ca_true, ba_true) -> list[AccPose]:
    dirs = np.array(
        [
            [1, 0, 0],
            [-1, 0, 0],
            [0, 1, 0],
            [0, -1, 0],
            [0, 0, 1],
            [0, 0, -1],
            [1, 1, 1],
            [1, -1, 1],
            [-1, 1, 1],
            [-1, -1, 1],
            [1, 1, -1],
            [-1, 1, -1],
        ],
        dtype=float,
    )
    names = [
        "+X",
        "-X",
        "+Y",
        "-Y",
        "+Z",
        "-Z",
        "diag_111",
        "diag_1m11",
        "diag_m111",
        "diag_mm11",
        "diag_11m1",
        "diag_m11m1",
    ]
    poses: list[AccPose] = []
    for direction, name in zip(dirs, names):
        unit_dir = direction / np.linalg.norm(direction)
        a_ref = g0 * unit_dir
        raw_acc_mean = np.linalg.solve(Ca_true, a_ref) + ba_true + 0.008 * rng.normal(size=3)
        poses.append(AccPose(acc_mean=raw_acc_mean, pose_name=name, a_ref=None))
    return poses


def _generate_gyro_runs(rng, Cg_true, bg_true, gyro_std) -> list[GyroRun]:
    fs = 200.0
    ramp_time = 0.5
    configs = [(0.70, 3.0), (1.05, 2.2)]
    axes = "xyz"
    dirs = (1, -1)
    runs: list[GyroRun] = []

    for axis_idx, axis_name in enumerate(axes):
        e = np.zeros(3, dtype=float)
        e[axis_idx] = 1.0
        for dir_sign in dirs:
            for rate, steady_time in configs:
                n_ramp = int(round(ramp_time * fs))
                n_steady = int(round(steady_time * fs))
                omega_scalar = np.concatenate(
                    [
                        np.linspace(0.0, dir_sign * rate, n_ramp),
                        np.full(n_steady, dir_sign * rate),
                        np.linspace(dir_sign * rate, 0.0, n_ramp),
                    ]
                )
                N = omega_scalar.size
                t = np.arange(N, dtype=float) / fs
                omega_ref = np.outer(omega_scalar, e)
                gyro_ideal = (Cg_true @ omega_ref.T).T
                gyro = gyro_ideal + bg_true[None, :] + rng.normal(size=(N, 3)) * gyro_std
                idx_ss = np.zeros(N, dtype=bool)
                idx_ss[n_ramp : n_ramp + n_steady] = True
                theta_ref = e * (dir_sign * rate * steady_time)
                runs.append(
                    GyroRun(
                        axis=axis_name,
                        dir=dir_sign,
                        gyro=gyro,
                        t=t,
                        theta_ref=theta_ref,
                        idx_ss=idx_ss,
                    )
                )
    return runs
