from imu_calib.io.load_example_data import load_example_data
from imu_calib.utils.detect_static_segments import detect_static_segments
from imu_calib.utils.detect_steady_segments import detect_steady_segments


def test_detect_static_segments_returns_non_empty_segment_for_example_static_data():
    data, _, _ = load_example_data()
    result = detect_static_segments(data.static.t, data.static.gyro, data.static.acc)
    assert result["quality"]["num_segments"] >= 1


def test_detect_steady_segments_returns_non_empty_segment_for_example_run():
    data, _, _ = load_example_data()
    result = detect_steady_segments(data.gyro_runs[0].t, data.gyro_runs[0].gyro)
    assert result["quality"]["num_segments"] >= 1
    assert result["mask"].sum() >= 2
