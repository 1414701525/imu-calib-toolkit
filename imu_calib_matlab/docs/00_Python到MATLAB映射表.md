# Python -> MATLAB 映射表

下表以 Python 主线为真值来源，记录本次同步涉及的核心模块映射、迁移前状态和当前 MATLAB 落地情况。

| Python 模块 / 入口 | MATLAB 对应文件 | 迁移前状态 | 当前状态 | 说明 |
| --- | --- | --- | --- | --- |
| `imu_calib/calib/fit_acc_multi_pose.py` | `src/calib/fit_acc_multi_pose.m` | 未同步 | 已同步 | 从旧 `a_ref` 线性 LS 切换到静止多姿态 + 重力模长约束；输出 `Ca / ba / Sa / Ma / gravity_magnitude / fitInfo` |
| `imu_calib/calib/extract_static_pose_means.py` | `src/calib/extract_static_pose_means.m` | 缺失 | 已同步 | 从连续 `static` 数据中提取静止段均值，供加计标定和 `ba(T)` 使用 |
| `imu_calib/tasks/run_acc_calibration.py` | `src/tasks/run_acc_calibration.m` | 部分同步 | 已同步 | 支持 `accPoses/acc_poses` 与 `static` 两种输入路径 |
| `imu_calib/calib/fit_temperature_bias_model.py` | `src/analysis/fit_temperature_bias_models.m`、`fit_temperature_bias_model.m`、`fit_gyro_temperature_bias_model.m`、`fit_accel_temperature_bias_model.m` | 未同步 | 已同步 | 同步 `bg(T)`、`ba(T)`、温度 bin、低置信度/失效输出、温区外策略 |
| `imu_calib/runtime/get_bias_from_temperature.py` | `src/runtime/get_bias_from_temperature.m` | 缺失 | 已同步 | MATLAB 新增统一温度 bias 求值逻辑 |
| `imu_calib/runtime/get_gyro_bias_from_temperature.py` | `src/runtime/get_gyro_bias_from_temperature.m` | 部分同步 | 已同步 | 从旧 analysis 位置迁移到 runtime 口径 |
| `imu_calib/runtime/get_accel_bias_from_temperature.py` | `src/runtime/get_accel_bias_from_temperature.m` | 缺失 | 已同步 | MATLAB 新增 |
| `imu_calib/runtime/apply_imu_calibration.py` | `src/runtime/apply_imu_calibration.m` | 未同步 | 已同步 | 加速度补偿切换到 `Ca * (a_raw - ba(T))`，并支持 `baT / bgT / f_term / g_term` |
| `imu_calib/tasks/run_temperature_fit.py` | `src/tasks/run_temperature_fit.m` | 未同步 | 已同步 | 支持 `target=gyro/acc/both`，统一返回 `bgModel / baModel / temperatureModel / metrics` |
| `imu_calib/runtime/build_calib_results.py` | `src/runtime/build_calib_results.m` | 部分同步 | 已同步 | 结构中补齐 `Sa / Ma / gravity_magnitude / bgModel / baModel / temperatureModel` |
| `imu_calib/runtime/save_calibration_results.py` | `src/runtime/save_calibration_results.m` | 部分同步 | 部分同步 | MATLAB 保存为 `.mat + .json + arrays.mat`，无法原生输出 Python 的 `pkl/npz` |
| `imu_calib/io/load_csv_data.py` | `src/io/load_csv_data.m` | 部分同步 | 已同步 | 支持 partial load、列名映射、`acc_poses.csv` 可无 `ref_*`、snake_case alias |
| `imu_calib/io/export_dataset_bundle.py` | `src/io/export_dataset_bundle.m` | 部分同步 | 已同步 | 默认不导出 `ref_x/ref_y/ref_z`，可选兼容输出 |
| `imu_calib/io/load_example_data.py` | `src/io/load_example_data.m` | 未同步 | 已同步 | synthetic 数据口径切换到新 `Ca` 补偿矩阵模型 |
| `imu_calib/tasks/run_full_calibration.py` | `src/tasks/run_full_calibration.m` | 部分同步 | 已同步 | 温度任务、结果装配、partial/full 判定、摘要状态与 Python 对齐 |
| `imu_calib/validate/validate_calibration.py` | `src/validate/validate_calibration.m` | 未同步 | 已同步 | 加计验证切到模长误差口径；温度状态支持 `bg_model/ba_model` 双状态 |
| `imu_calib/validate/plot_validation_results.py` | `src/validate/plot_validation_results.m` | 部分同步 | 已同步 | 新增 `ba(T)` 图、按新 summary 字段展示 |

## 仍保留的兼容项

- `accPoses(i).a_ref`
  - MATLAB 仍可读取 legacy `ref_x/ref_y/ref_z`
  - 只用于可选初始化，不参与新目标函数
- `data.accPoses / data.gyroRuns / data.gsensRuns`
  - 继续保留 camelCase
  - 同时补充 `acc_poses / gyro_runs / gsens_runs` alias
- `fit_temperature_bias_model(...)`
  - 继续保留为 gyro-only 包装器，便于兼容旧调用

## 当前已知差异

- MATLAB 结果保存格式以 `.mat` 为主，未直接复刻 Python 的 `pickle / npz`
- 由于当前工作环境没有可调用的 MATLAB 可执行程序，本次无法在本机自动跑 MATLAB 测试，只能做静态实现对齐与 Python 侧口径比对
