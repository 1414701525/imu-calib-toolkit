from __future__ import annotations

import numpy as np

from imu_calib.models.data_structures import AccPose, ImuDataset
from imu_calib.validate.plot_validation_results import _resolve_gravity_reference


def test_plot_gravity_reference_does_not_require_legacy_a_ref():
    data = ImuDataset(
        acc_poses=[
            AccPose(acc_mean=np.array([0.0, 0.0, 9.8]), pose_name="z_up", a_ref=None),
            AccPose(acc_mean=np.array([0.0, 9.8, 0.0]), pose_name="y_up", a_ref=None),
        ]
    )
    validation = {"static": {"gravity_magnitude": 9.80665}}

    assert _resolve_gravity_reference(data, {}, validation) == 9.80665


def test_plot_gravity_reference_keeps_legacy_fallback():
    data = ImuDataset(
        acc_poses=[
            AccPose(acc_mean=np.array([0.0, 0.0, 9.8]), pose_name="z_up", a_ref=np.array([0.0, 0.0, 9.81])),
            AccPose(acc_mean=np.array([0.0, 9.8, 0.0]), pose_name="y_up", a_ref=np.array([0.0, 9.81, 0.0])),
        ]
    )

    assert np.isclose(_resolve_gravity_reference(data, {}, {}), 9.81)
