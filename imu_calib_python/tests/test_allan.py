from imu_calib.calib.analyze_acc_allan import analyze_acc_allan
from imu_calib.calib.analyze_gyro_allan import analyze_gyro_allan
from imu_calib.io.load_example_data import load_example_data


def test_allan_outputs_are_valid_for_example_static_data():
    data, _, _ = load_example_data()
    gyro_allan = analyze_gyro_allan(data.static.t, data.static.gyro)
    acc_allan = analyze_acc_allan(data.static.t, data.static.acc)

    assert gyro_allan["valid"] is True
    assert acc_allan["valid"] is True
    assert gyro_allan["tau"].ndim == 1
    assert gyro_allan["adev"].shape[1] == 3
    assert "estimate" in gyro_allan
