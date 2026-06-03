from imu_calib.calib.fit_acc_multi_pose import fit_acc_multi_pose
from imu_calib.io.load_example_data import load_example_data


def test_acc_fit_close_to_truth():
    data, truth, _ = load_example_data()
    Ca, ba, _ = fit_acc_multi_pose(data.acc_poses)
    assert abs(Ca - truth["Ca_true"]).max() < 3e-2
    assert abs(ba - truth["ba_true"]).max() < 3e-2
